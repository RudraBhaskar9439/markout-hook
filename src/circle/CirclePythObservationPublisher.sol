// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ICircleMessageTransmitterV2 } from "../interfaces/ICircleMessageTransmitterV2.sol";
import { IPyth, PythPrice } from "../interfaces/IPyth.sol";
import { MarkoutParameters } from "../libraries/MarkoutParameters.sol";
import { ObservationMessageCodec } from "../libraries/ObservationMessageCodec.sol";
import { PythObservation } from "../libraries/PythObservation.sol";
import { CirclePublisherConfig } from "../types/CircleTypes.sol";
import { ReferenceObservation } from "../types/MarkoutTypes.sol";

/// @title Circle Pyth Observation Publisher
/// @notice Permissionless source contract that verifies Pyth and requests a fast-confirmed Circle message to Unichain.
contract CirclePythObservationPublisher {
    uint32 public constant FAST_FINALITY_THRESHOLD = 1000;

    error ZeroBinder();
    error ZeroMessageTransmitter();
    error MessageTransmitterHasNoCode(address messageTransmitter);
    error ZeroPyth();
    error PythHasNoCode(address pyth);
    error ZeroPriceId();
    error ZeroMarketId();
    error ZeroDestinationDomain();
    error InvalidMaximumPriceAge(uint64 maximumPriceAge);
    error UnauthorizedBinder(address caller);
    error ZeroDestinationReceiver();
    error DestinationAlreadyBound(address destinationReceiver);
    error DestinationNotBound();
    error ZeroTradeId();
    error EmptyUpdateData();
    error IncorrectUpdateFee(uint256 supplied, uint256 required);

    event DestinationBound(address indexed destinationReceiver);
    event ObservationPublished(
        bytes32 indexed tradeId, bytes32 indexed marketId, uint192 priceX18, uint64 observedAt, uint16 confidenceBps
    );

    address public immutable binder;
    ICircleMessageTransmitterV2 public immutable messageTransmitter;
    IPyth public immutable pyth;
    bytes32 public immutable priceId;
    bytes32 public immutable marketId;
    uint32 public immutable destinationDomain;
    uint64 public immutable maximumPriceAge;

    address public destinationReceiver;

    constructor(CirclePublisherConfig memory config) {
        if (config.binder == address(0)) revert ZeroBinder();
        if (address(config.messageTransmitter) == address(0)) revert ZeroMessageTransmitter();
        if (address(config.messageTransmitter).code.length == 0) {
            revert MessageTransmitterHasNoCode(address(config.messageTransmitter));
        }
        if (address(config.pyth) == address(0)) revert ZeroPyth();
        if (address(config.pyth).code.length == 0) revert PythHasNoCode(address(config.pyth));
        if (config.priceId == bytes32(0)) revert ZeroPriceId();
        if (config.marketId == bytes32(0)) revert ZeroMarketId();
        if (config.destinationDomain == 0) revert ZeroDestinationDomain();
        if (config.maximumPriceAge == 0 || config.maximumPriceAge > MarkoutParameters.MAXIMUM_OBSERVATION_AGE) {
            revert InvalidMaximumPriceAge(config.maximumPriceAge);
        }

        binder = config.binder;
        messageTransmitter = config.messageTransmitter;
        pyth = config.pyth;
        priceId = config.priceId;
        marketId = config.marketId;
        destinationDomain = config.destinationDomain;
        maximumPriceAge = config.maximumPriceAge;
    }

    /// @notice Permanently binds the EVM destination receiver after both sides have been deployed.
    function bindDestination(address destinationReceiver_) external {
        if (msg.sender != binder) revert UnauthorizedBinder(msg.sender);
        if (destinationReceiver != address(0)) revert DestinationAlreadyBound(destinationReceiver);
        if (destinationReceiver_ == address(0)) revert ZeroDestinationReceiver();
        destinationReceiver = destinationReceiver_;
        emit DestinationBound(destinationReceiver_);
    }

    /// @notice Publishes a fresh, Pyth-verified observation for a known Unichain MARKOUT trade.
    /// @dev The caller is permissionless and must pay exactly Pyth's quoted update fee.
    function publish(bytes32 tradeId, bytes[] calldata updateData)
        external
        payable
        returns (ReferenceObservation memory observation)
    {
        address destinationReceiver_ = destinationReceiver;
        if (destinationReceiver_ == address(0)) revert DestinationNotBound();
        if (tradeId == bytes32(0)) revert ZeroTradeId();
        if (updateData.length == 0) revert EmptyUpdateData();

        uint256 updateFee = pyth.getUpdateFee(updateData);
        if (msg.value != updateFee) revert IncorrectUpdateFee(msg.value, updateFee);
        pyth.updatePriceFeeds{ value: updateFee }(updateData);

        PythPrice memory pythPrice = pyth.getPriceNoOlderThan(priceId, maximumPriceAge);
        observation = PythObservation.normalize(pythPrice);
        bytes memory messageBody = ObservationMessageCodec.encode(marketId, tradeId, observation);

        messageTransmitter.sendMessage(
            destinationDomain,
            bytes32(uint256(uint160(destinationReceiver_))),
            bytes32(0),
            FAST_FINALITY_THRESHOLD,
            messageBody
        );
        emit ObservationPublished(
            tradeId, marketId, observation.priceX18, observation.observedAt, observation.confidenceBps
        );
    }
}
