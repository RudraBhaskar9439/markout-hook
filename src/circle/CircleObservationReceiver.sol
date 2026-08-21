// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ICircleMessageHandlerV2 } from "../interfaces/ICircleMessageHandlerV2.sol";
import { IMarkoutSettlementTarget } from "../interfaces/IMarkoutSettlementTarget.sol";
import { ObservationMessageCodec } from "../libraries/ObservationMessageCodec.sol";
import { CircleReceiverConfig } from "../types/CircleTypes.sol";
import { ReferenceObservation } from "../types/MarkoutTypes.sol";

/// @title Circle MARKOUT Observation Receiver
/// @notice Authenticates CCTP V2 messages and forwards observations to the shared settlement coordinator.
contract CircleObservationReceiver is ICircleMessageHandlerV2 {
    uint32 public constant FAST_FINALITY_THRESHOLD = 1000;
    uint32 public constant FINALIZED_THRESHOLD = 2000;
    uint8 public constant MESSAGE_VERSION = 1;

    error ZeroMessageTransmitter();
    error MessageTransmitterHasNoCode(address messageTransmitter);
    error ZeroSourcePublisher();
    error ZeroMarketId();
    error ZeroSettlementCoordinator();
    error SettlementCoordinatorHasNoCode(address settlementCoordinator);
    error UnauthorizedMessageTransmitter(address caller);
    error UnexpectedSourceDomain(uint32 supplied, uint32 expected);
    error UnexpectedSourcePublisher(bytes32 supplied, bytes32 expected);
    error InsufficientFinality(uint32 supplied, uint32 required);
    error UnsupportedMessageVersion(uint8 supplied, uint8 expected);
    error UnexpectedMarket(bytes32 supplied, bytes32 expected);
    error ZeroTradeId();
    error FinalizedMessageInUnfinalizedHandler(uint32 supplied);

    event CircleObservationReceived(
        bytes32 indexed tradeId,
        bytes32 indexed marketId,
        uint192 priceX18,
        uint64 observedAt,
        uint16 confidenceBps,
        uint32 finalityThresholdExecuted
    );

    address public immutable messageTransmitter;
    uint32 public immutable sourceDomain;
    bytes32 public immutable sourcePublisher;
    bytes32 public immutable marketId;
    IMarkoutSettlementTarget public immutable settlementCoordinator;

    constructor(CircleReceiverConfig memory config) {
        if (config.messageTransmitter == address(0)) revert ZeroMessageTransmitter();
        if (config.messageTransmitter.code.length == 0) {
            revert MessageTransmitterHasNoCode(config.messageTransmitter);
        }
        if (config.sourcePublisher == address(0)) revert ZeroSourcePublisher();
        if (config.marketId == bytes32(0)) revert ZeroMarketId();
        if (address(config.settlementCoordinator) == address(0)) revert ZeroSettlementCoordinator();
        if (address(config.settlementCoordinator).code.length == 0) {
            revert SettlementCoordinatorHasNoCode(address(config.settlementCoordinator));
        }

        messageTransmitter = config.messageTransmitter;
        sourceDomain = config.sourceDomain;
        sourcePublisher = bytes32(uint256(uint160(config.sourcePublisher)));
        marketId = config.marketId;
        settlementCoordinator = config.settlementCoordinator;
    }

    /// @inheritdoc ICircleMessageHandlerV2
    function handleReceiveFinalizedMessage(
        uint32 sourceDomain_,
        bytes32 sender,
        uint32 finalityThresholdExecuted,
        bytes calldata messageBody
    ) external returns (bool success) {
        _authenticateEnvelope(sourceDomain_, sender);
        if (finalityThresholdExecuted < FINALIZED_THRESHOLD) {
            revert InsufficientFinality(finalityThresholdExecuted, FINALIZED_THRESHOLD);
        }
        return _handleMessage(messageBody, finalityThresholdExecuted);
    }

    /// @inheritdoc ICircleMessageHandlerV2
    function handleReceiveUnfinalizedMessage(
        uint32 sourceDomain_,
        bytes32 sender,
        uint32 finalityThresholdExecuted,
        bytes calldata messageBody
    ) external returns (bool success) {
        _authenticateEnvelope(sourceDomain_, sender);
        if (finalityThresholdExecuted < FAST_FINALITY_THRESHOLD) {
            revert InsufficientFinality(finalityThresholdExecuted, FAST_FINALITY_THRESHOLD);
        }
        if (finalityThresholdExecuted >= FINALIZED_THRESHOLD) {
            revert FinalizedMessageInUnfinalizedHandler(finalityThresholdExecuted);
        }
        return _handleMessage(messageBody, finalityThresholdExecuted);
    }

    function _authenticateEnvelope(uint32 sourceDomain_, bytes32 sender) private view {
        if (msg.sender != messageTransmitter) revert UnauthorizedMessageTransmitter(msg.sender);
        if (sourceDomain_ != sourceDomain) revert UnexpectedSourceDomain(sourceDomain_, sourceDomain);
        if (sender != sourcePublisher) revert UnexpectedSourcePublisher(sender, sourcePublisher);
    }

    function _handleMessage(bytes calldata messageBody, uint32 finalityThresholdExecuted)
        private
        returns (bool success)
    {
        (uint8 version, bytes32 suppliedMarketId, bytes32 tradeId, ReferenceObservation memory observation) =
            ObservationMessageCodec.decode(messageBody);
        if (version != MESSAGE_VERSION) revert UnsupportedMessageVersion(version, MESSAGE_VERSION);
        if (suppliedMarketId != marketId) revert UnexpectedMarket(suppliedMarketId, marketId);
        if (tradeId == bytes32(0)) revert ZeroTradeId();

        settlementCoordinator.settleTrade(tradeId, observation);
        emit CircleObservationReceived(
            tradeId,
            suppliedMarketId,
            observation.priceX18,
            observation.observedAt,
            observation.confidenceBps,
            finalityThresholdExecuted
        );
        return true;
    }
}
