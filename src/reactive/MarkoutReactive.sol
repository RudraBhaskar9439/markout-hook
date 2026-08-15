// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { AbstractPayer } from "reactive-lib/abstract-base/AbstractPayer.sol";
import { IPayable } from "reactive-lib/interfaces/IPayable.sol";
import { IReactive } from "reactive-lib/interfaces/IReactive.sol";
import { ISubscriptionService } from "reactive-lib/interfaces/ISubscriptionService.sol";

import { ReactiveMarkoutSettlementAdapter } from "../adapters/ReactiveMarkoutSettlementAdapter.sol";
import { IMarkoutHook } from "../interfaces/IMarkoutHook.sol";
import { INormalizedReferencePriceFeed } from "../interfaces/INormalizedReferencePriceFeed.sol";
import { IReferencePriceSampler } from "../interfaces/IReferencePriceSampler.sol";
import { MarkoutParameters } from "../libraries/MarkoutParameters.sol";
import {
    MarkoutReactiveConfig,
    MarkoutRequestEventData,
    ReactiveReferenceObservation,
    ReactiveTradeRecord,
    ReactiveTradeStatus
} from "../types/MarkoutReactiveTypes.sol";
import { ReferenceObservation } from "../types/MarkoutTypes.sol";

/// @title MARKOUT Reactive Scheduler
/// @notice Event-driven observation, maturity, retry, acknowledgement, and expiry orchestration.
/// @dev Uses the legacy-compatible Callback event because Reactive Omni explicitly preserves that delivery format.
///      Unlike the legacy base contract, this implementation has no ReactVM-only state or dual-deployment assumption.
contract MarkoutReactive is AbstractPayer, IReactive {
    uint256 public constant REACTIVE_IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;
    uint64 public constant CALLBACK_GAS_LIMIT = 500_000;
    uint64 public constant REFERENCE_SAMPLE_GAS_LIMIT = 300_000;
    uint64 public constant REFERENCE_SAMPLE_RETRY_DELAY = 60;
    uint256 public constant MAX_TRADES_PER_CRON = 8;

    uint256 public constant MARKOUT_REQUESTED_TOPIC = uint256(
        keccak256("MarkoutRequested(bytes32,bytes32,address,address,uint128,uint192,uint64,uint64,uint64,uint8)")
    );
    uint256 public constant MARKOUT_SETTLED_TOPIC = uint256(
        keccak256("MarkoutSettled(bytes32,address,address,int256,uint16,uint128,uint128,uint192,uint64,uint16)")
    );
    uint256 public constant MARKOUT_EXPIRED_TOPIC =
        uint256(keccak256("MarkoutExpired(bytes32,address,address,uint128)"));
    uint256 public constant REFERENCE_PRICE_TOPIC =
        uint256(keccak256("NormalizedReferencePricePublished(bytes32,uint192,uint64,uint16)"));

    error ZeroService();
    error ZeroHook();
    error ZeroSettlementAdapter();
    error ZeroReferenceFeed();
    error ZeroMarketId();
    error ZeroCronTopic();
    error ZeroChainId();
    error DestinationMustMatchOrigin(uint256 originChainId, uint256 destinationChainId);
    error UnauthorizedService(address caller);
    error InvalidRequestTimestamps(uint64 executedAt, uint64 maturityTimestamp, uint64 expiryTimestamp);
    error TimestampOutOfRange(uint256 timestamp);

    event TradeObserved(bytes32 indexed tradeId, uint64 maturityTimestamp, uint64 expiryTimestamp);
    event DuplicateTradeIgnored(bytes32 indexed tradeId, ReactiveTradeStatus status);
    event ReferenceObservationAccepted(uint192 priceX18, uint64 observedAt, uint16 confidenceBps);
    event ReferenceObservationIgnored(uint192 priceX18, uint64 observedAt, uint16 confidenceBps);
    event ReferenceSampleCallbackRequested(address indexed sampler, uint64 requestedAt);
    event SettlementCallbackRequested(bytes32 indexed tradeId, uint192 priceX18, uint64 observedAt);
    event ExpiryCallbackRequested(bytes32 indexed tradeId);
    event TradeFinalized(bytes32 indexed tradeId);

    ISubscriptionService public immutable subscriptionService;
    uint256 public immutable reactiveChainId;
    uint256 public immutable originChainId;
    uint256 public immutable destinationChainId;
    uint256 public immutable referenceChainId;
    address public immutable hook;
    address public immutable settlementAdapter;
    address public immutable referenceFeed;
    address public immutable referenceSampler;
    bytes32 public immutable marketId;
    uint256 public immutable cronTopic;

    ReactiveReferenceObservation public latestReferenceObservation;
    uint256 public scanCursor;
    uint64 public lastReferenceSampleRequestedAt;

    mapping(bytes32 tradeId => ReactiveTradeRecord trade) private _trades;
    bytes32[] private _tradeIds;

    constructor(MarkoutReactiveConfig memory config) {
        if (config.service == address(0)) revert ZeroService();
        if (config.hook == address(0)) revert ZeroHook();
        if (config.settlementAdapter == address(0)) revert ZeroSettlementAdapter();
        if (config.referenceFeed == address(0)) revert ZeroReferenceFeed();
        if (config.marketId == bytes32(0)) revert ZeroMarketId();
        if (config.cronTopic == 0) revert ZeroCronTopic();
        if (
            config.reactiveChainId == 0 || config.originChainId == 0 || config.destinationChainId == 0
                || config.referenceChainId == 0
        ) revert ZeroChainId();
        if (config.destinationChainId != config.originChainId) {
            revert DestinationMustMatchOrigin(config.originChainId, config.destinationChainId);
        }

        subscriptionService = ISubscriptionService(payable(config.service));
        reactiveChainId = config.reactiveChainId;
        originChainId = config.originChainId;
        destinationChainId = config.destinationChainId;
        referenceChainId = config.referenceChainId;
        hook = config.hook;
        settlementAdapter = config.settlementAdapter;
        referenceFeed = config.referenceFeed;
        referenceSampler = config.referenceSampler;
        marketId = config.marketId;
        cronTopic = config.cronTopic;

        vendor = IPayable(payable(config.service));
        addAuthorizedSender(config.service);
        _subscribe(config);
    }

    modifier onlyService() {
        if (msg.sender != address(subscriptionService)) revert UnauthorizedService(msg.sender);
        _;
    }

    /// @inheritdoc IReactive
    function react(LogRecord calldata log) external onlyService {
        if (log.chain_id == originChainId && log._contract == hook) {
            if (log.topic_0 == MARKOUT_REQUESTED_TOPIC) {
                _handleTradeRequest(log);
            } else if (log.topic_0 == MARKOUT_SETTLED_TOPIC || log.topic_0 == MARKOUT_EXPIRED_TOPIC) {
                _handleTerminalAcknowledgement(bytes32(log.topic_1));
            }
            return;
        }

        if (
            log.chain_id == referenceChainId && log._contract == referenceFeed && log.topic_0 == REFERENCE_PRICE_TOPIC
                && bytes32(log.topic_1) == marketId
        ) {
            _handleReferenceObservation(log.data);
            if (referenceSampler != address(0)) _processMatureTrades();
            return;
        }

        if (
            log.chain_id == reactiveChainId && log._contract == address(subscriptionService) && log.topic_0 == cronTopic
        ) {
            _processMatureTrades();
        }
    }

    function getTrade(bytes32 tradeId) external view returns (ReactiveTradeRecord memory) {
        return _trades[tradeId];
    }

    function getLatestReferenceObservation() external view returns (ReactiveReferenceObservation memory) {
        return latestReferenceObservation;
    }

    function tradeCount() external view returns (uint256) {
        return _tradeIds.length;
    }

    function tradeIdAt(uint256 index) external view returns (bytes32) {
        return _tradeIds[index];
    }

    function _subscribe(MarkoutReactiveConfig memory config) private {
        subscriptionService.subscribe(
            config.originChainId,
            config.hook,
            MARKOUT_REQUESTED_TOPIC,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        subscriptionService.subscribe(
            config.originChainId, config.hook, MARKOUT_SETTLED_TOPIC, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
        );
        subscriptionService.subscribe(
            config.originChainId, config.hook, MARKOUT_EXPIRED_TOPIC, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
        );
        subscriptionService.subscribe(
            config.referenceChainId,
            config.referenceFeed,
            REFERENCE_PRICE_TOPIC,
            uint256(config.marketId),
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        subscriptionService.subscribe(
            config.reactiveChainId, config.service, config.cronTopic, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
        );
    }

    function _handleTradeRequest(LogRecord calldata log) private {
        bytes32 tradeId = bytes32(log.topic_1);
        ReactiveTradeStatus currentStatus = _trades[tradeId].status;
        if (currentStatus != ReactiveTradeStatus.None) {
            emit DuplicateTradeIgnored(tradeId, currentStatus);
            return;
        }

        MarkoutRequestEventData memory request = abi.decode(log.data, (MarkoutRequestEventData));
        if (
            tradeId == bytes32(0) || request.executedAt > request.maturityTimestamp
                || request.maturityTimestamp > request.expiryTimestamp
        ) {
            revert InvalidRequestTimestamps(request.executedAt, request.maturityTimestamp, request.expiryTimestamp);
        }

        _trades[tradeId] = ReactiveTradeRecord({
            maturityTimestamp: request.maturityTimestamp,
            expiryTimestamp: request.expiryTimestamp,
            status: ReactiveTradeStatus.Pending
        });
        _tradeIds.push(tradeId);
        emit TradeObserved(tradeId, request.maturityTimestamp, request.expiryTimestamp);
    }

    function _handleReferenceObservation(bytes calldata data) private {
        (uint192 priceX18, uint64 observedAt, uint16 confidenceBps) = abi.decode(data, (uint192, uint64, uint16));
        ReactiveReferenceObservation memory current = latestReferenceObservation;
        bool valid = priceX18 != 0 && observedAt != 0 && observedAt > current.observedAt
            && confidenceBps >= MarkoutParameters.MINIMUM_CONFIDENCE_BPS
            && confidenceBps <= MarkoutParameters.BPS_DENOMINATOR;
        if (!valid) {
            emit ReferenceObservationIgnored(priceX18, observedAt, confidenceBps);
            return;
        }

        latestReferenceObservation =
            ReactiveReferenceObservation({ priceX18: priceX18, observedAt: observedAt, confidenceBps: confidenceBps });
        emit ReferenceObservationAccepted(priceX18, observedAt, confidenceBps);
    }

    function _handleTerminalAcknowledgement(bytes32 tradeId) private {
        ReactiveTradeRecord storage trade = _trades[tradeId];
        if (trade.status == ReactiveTradeStatus.None || trade.status == ReactiveTradeStatus.Finalized) return;
        trade.status = ReactiveTradeStatus.Finalized;
        emit TradeFinalized(tradeId);
    }

    function _processMatureTrades() private {
        uint256 length = _tradeIds.length;
        if (length == 0) return;

        uint256 iterations = length < MAX_TRADES_PER_CRON ? length : MAX_TRADES_PER_CRON;
        uint256 cursor = scanCursor;
        uint64 currentTimestamp = _currentTimestamp();
        bool sampleRequired = false;
        for (uint256 i = 0; i < iterations; ++i) {
            if (_processTrade(_tradeIds[cursor], currentTimestamp)) sampleRequired = true;
            unchecked {
                ++cursor;
            }
            if (cursor == length) cursor = 0;
        }
        scanCursor = cursor;
        if (sampleRequired) _requestReferenceSample(currentTimestamp);
    }

    function _processTrade(bytes32 tradeId, uint64 currentTimestamp) private returns (bool sampleRequired) {
        ReactiveTradeRecord storage trade = _trades[tradeId];
        if (trade.status == ReactiveTradeStatus.None || trade.status == ReactiveTradeStatus.Finalized) return false;

        if (currentTimestamp > trade.expiryTimestamp) {
            trade.status = ReactiveTradeStatus.ExpiryPendingAcknowledgement;
            bytes memory expiryPayload = abi.encodeCall(ReactiveMarkoutSettlementAdapter.expire, (address(0), tradeId));
            emit Callback(destinationChainId, settlementAdapter, CALLBACK_GAS_LIMIT, expiryPayload);
            emit ExpiryCallbackRequested(tradeId);
            return false;
        }

        ReactiveReferenceObservation memory observation = latestReferenceObservation;
        if (!_isEligible(trade, observation, currentTimestamp)) {
            return currentTimestamp >= trade.maturityTimestamp && trade.status == ReactiveTradeStatus.Pending;
        }

        trade.status = ReactiveTradeStatus.SettlementPendingAcknowledgement;
        bytes memory settlementPayload = abi.encodeCall(
            ReactiveMarkoutSettlementAdapter.settle,
            (
                address(0),
                tradeId,
                ReferenceObservation({
                    priceX18: observation.priceX18,
                    observedAt: observation.observedAt,
                    confidenceBps: observation.confidenceBps
                })
            )
        );
        emit Callback(destinationChainId, settlementAdapter, CALLBACK_GAS_LIMIT, settlementPayload);
        emit SettlementCallbackRequested(tradeId, observation.priceX18, observation.observedAt);
    }

    function _requestReferenceSample(uint64 currentTimestamp) private {
        address sampler = referenceSampler;
        if (sampler == address(0)) return;

        uint64 lastRequestedAt = lastReferenceSampleRequestedAt;
        if (
            lastRequestedAt != 0
                && (currentTimestamp <= lastRequestedAt
                    || currentTimestamp - lastRequestedAt < REFERENCE_SAMPLE_RETRY_DELAY)
        ) return;

        lastReferenceSampleRequestedAt = currentTimestamp;
        bytes memory payload = abi.encodeCall(IReferencePriceSampler.sample, (address(0)));
        emit Callback(referenceChainId, sampler, REFERENCE_SAMPLE_GAS_LIMIT, payload);
        emit ReferenceSampleCallbackRequested(sampler, currentTimestamp);
    }

    function _isEligible(
        ReactiveTradeRecord storage trade,
        ReactiveReferenceObservation memory observation,
        uint64 currentTimestamp
    ) private view returns (bool) {
        if (currentTimestamp < trade.maturityTimestamp) return false;
        if (observation.observedAt < trade.maturityTimestamp || observation.observedAt > currentTimestamp) {
            return false;
        }
        return currentTimestamp - observation.observedAt <= MarkoutParameters.MAXIMUM_OBSERVATION_AGE;
    }

    function _currentTimestamp() private view returns (uint64 timestamp) {
        // Reactive cron scheduling deliberately uses consensus block time.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp > type(uint64).max) revert TimestampOutOfRange(block.timestamp);
        // The bound above proves this conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64(block.timestamp);
    }
}
