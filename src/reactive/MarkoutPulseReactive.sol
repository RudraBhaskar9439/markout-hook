// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { AbstractReactive } from "reactive-lib/abstract-base/AbstractReactive.sol";
import { IReactive } from "reactive-lib/interfaces/IReactive.sol";

import { ReferenceObservation } from "../types/MarkoutTypes.sol";
import { ReactivePulseConfig } from "../types/ReactivePulseTypes.sol";
import { ReactiveObservationReceiver } from "./ReactiveObservationReceiver.sol";

/// @title MARKOUT Reactive Observation Pulse
/// @notice Statelessly delivers one Pyth-verified publisher event to the authenticated Unichain receiver.
/// @dev The pulse is MARKOUT's live Legacy transport adapter and holds no custody or pricing authority.
contract MarkoutPulseReactive is AbstractReactive {
    uint64 public constant CALLBACK_GAS_LIMIT = 300_000;
    uint256 public constant OBSERVATION_PUBLISHED_TOPIC =
        uint256(keccak256("ObservationPublished(bytes32,bytes32,uint192,uint64,uint16)"));

    error ZeroChainId();
    error ZeroSourcePublisher();
    error ZeroDestinationReceiver();
    error ZeroMarketId();

    event ObservationPulseRequested(
        bytes32 indexed tradeId, bytes32 indexed marketId, uint192 priceX18, uint64 observedAt, uint16 confidenceBps
    );

    uint256 public immutable originChainId;
    uint256 public immutable destinationChainId;
    address public immutable sourcePublisher;
    address public immutable destinationReceiver;
    bytes32 public immutable marketId;

    constructor(ReactivePulseConfig memory config) payable {
        if (config.originChainId == 0 || config.destinationChainId == 0) revert ZeroChainId();
        if (config.sourcePublisher == address(0)) revert ZeroSourcePublisher();
        if (config.destinationReceiver == address(0)) revert ZeroDestinationReceiver();
        if (config.marketId == bytes32(0)) revert ZeroMarketId();

        originChainId = config.originChainId;
        destinationChainId = config.destinationChainId;
        sourcePublisher = config.sourcePublisher;
        destinationReceiver = config.destinationReceiver;
        marketId = config.marketId;

        if (!vm) {
            service.subscribe(
                config.originChainId,
                config.sourcePublisher,
                OBSERVATION_PUBLISHED_TOPIC,
                REACTIVE_IGNORE,
                uint256(config.marketId),
                REACTIVE_IGNORE
            );
        }
    }

    /// @inheritdoc IReactive
    function react(IReactive.LogRecord calldata log) external vmOnly {
        if (
            log.chain_id != originChainId || log._contract != sourcePublisher
                || log.topic_0 != OBSERVATION_PUBLISHED_TOPIC || bytes32(log.topic_2) != marketId
        ) return;

        bytes32 tradeId = bytes32(log.topic_1);
        if (tradeId == bytes32(0)) return;

        (uint192 priceX18, uint64 observedAt, uint16 confidenceBps) = abi.decode(log.data, (uint192, uint64, uint16));
        ReferenceObservation memory observation =
            ReferenceObservation({ priceX18: priceX18, observedAt: observedAt, confidenceBps: confidenceBps });
        bytes memory payload = abi.encodeCall(
            ReactiveObservationReceiver.receiveObservation, (address(0), marketId, tradeId, observation)
        );

        emit Callback(destinationChainId, destinationReceiver, CALLBACK_GAS_LIMIT, payload);
        emit ObservationPulseRequested(tradeId, marketId, priceX18, observedAt, confidenceBps);
    }
}
