// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TradeDirection } from "./MarkoutTypes.sol";

/// @notice Delivery state maintained on Reactive Network for one destination trade.
enum ReactiveTradeStatus {
    None,
    Pending,
    SettlementPendingAcknowledgement,
    ExpiryPendingAcknowledgement,
    Finalized
}

/// @notice Minimal trade timing state required by the Reactive scheduler.
struct ReactiveTradeRecord {
    uint64 maturityTimestamp;
    uint64 expiryTimestamp;
    ReactiveTradeStatus status;
}

/// @notice Latest accepted normalized reference observation.
struct ReactiveReferenceObservation {
    uint192 priceX18;
    uint64 observedAt;
    uint16 confidenceBps;
}

/// @notice Non-indexed payload emitted by `IMarkoutHook.MarkoutRequested`.
struct MarkoutRequestEventData {
    address currency;
    uint128 escrowedSurcharge;
    uint192 executionPriceX18;
    uint64 executedAt;
    uint64 maturityTimestamp;
    uint64 expiryTimestamp;
    TradeDirection direction;
}

/// @notice Immutable deployment configuration for one MARKOUT Reactive scheduler.
struct MarkoutReactiveConfig {
    address service;
    uint256 reactiveChainId;
    uint256 originChainId;
    uint256 destinationChainId;
    uint256 referenceChainId;
    address hook;
    address settlementAdapter;
    address referenceFeed;
    bytes32 marketId;
    uint256 cronTopic;
}
