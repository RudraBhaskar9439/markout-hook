// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TradeDirection } from "./MarkoutTypes.sol";

/// @notice Lifecycle state of a MARKOUT trade.
enum TradeStatus {
    None,
    Pending,
    Settled,
    Expired
}

/// @notice Persistent data captured when the provisional surcharge enters custody.
struct TradeRecord {
    bytes32 poolId;
    address rebateRecipient;
    address currency;
    uint192 executionPriceX18;
    uint128 escrowedSurcharge;
    uint64 executedAt;
    uint64 maturityTimestamp;
    uint64 expiryTimestamp;
    TradeDirection direction;
    TradeStatus status;
}

/// @notice Persistent terminal allocation data for a settled or expired trade.
struct TradeSettlementRecord {
    int256 markoutWad;
    uint192 referencePriceX18;
    uint128 retainedSurcharge;
    uint128 rebate;
    uint64 observedAt;
    uint16 confidenceBps;
    uint16 retentionBps;
}
