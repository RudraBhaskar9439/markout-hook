// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TradeRecord, TradeSettlementRecord, TradeStatus } from "../types/MarkoutLifecycleTypes.sol";
import { ReferenceObservation, TradeDirection } from "../types/MarkoutTypes.sol";
import { IMarkoutSettlementTarget } from "./IMarkoutSettlementTarget.sol";

/// @title MARKOUT Hook Interface
/// @notice Persistent lifecycle, accounting, and claim surface for the local MARKOUT MVP.
interface IMarkoutHook is IMarkoutSettlementTarget {
    error ZeroSettlementAuthority();
    error IdenticalBaseAndQuoteCurrency(address currency);
    error UnsupportedPool(address currency0, address currency1);
    error UnauthorizedSettlement(address caller);
    error UnknownTrade(bytes32 tradeId);
    error InvalidTradeStatus(bytes32 tradeId, TradeStatus actual, TradeStatus expected);
    error TradeNotExpired(bytes32 tradeId, uint64 expiryTimestamp, uint64 currentTimestamp);
    error TimestampOutOfRange(uint256 timestamp);
    error ZeroClaimRecipient();
    error NoClaimableRebate(address beneficiary, address currency);
    error NativeTransferFailed(address recipient, uint256 amount);
    error InvalidTerminalAllocation(uint128 escrowedSurcharge, uint128 retainedSurcharge, uint128 rebate);
    error InsolventCurrency(address currency, uint256 actualBalance, uint256 accountedBalance);

    event MarkoutRequested(
        bytes32 indexed tradeId,
        bytes32 indexed poolId,
        address indexed rebateRecipient,
        address currency,
        uint128 escrowedSurcharge,
        uint192 executionPriceX18,
        uint64 executedAt,
        uint64 maturityTimestamp,
        uint64 expiryTimestamp,
        TradeDirection direction
    );

    event MarkoutSettled(
        bytes32 indexed tradeId,
        address indexed rebateRecipient,
        address indexed currency,
        int256 markoutWad,
        uint16 retentionBps,
        uint128 retainedSurcharge,
        uint128 rebate,
        uint192 referencePriceX18,
        uint64 observedAt,
        uint16 confidenceBps
    );

    event MarkoutExpired(
        bytes32 indexed tradeId, address indexed rebateRecipient, address indexed currency, uint128 rebate
    );

    event RebateClaimed(
        address indexed beneficiary, address indexed currency, address indexed recipient, uint256 amount
    );

    function settlementAuthority() external view returns (address);

    function latestTradeId() external view returns (bytes32);

    function nextTradeNonce() external view returns (uint256);

    function getTrade(bytes32 tradeId) external view returns (TradeRecord memory);

    function getTradeSettlement(bytes32 tradeId) external view returns (TradeSettlementRecord memory);

    function expireTrade(bytes32 tradeId) external;

    function claimRebate(address currency, address payable recipient) external returns (uint256 amount);

    /// @notice Lets any sponsor pay claim gas while forcing delivery to the rebate beneficiary.
    function claimRebateFor(address beneficiary, address currency) external returns (uint256 amount);

    function claimableRebate(address beneficiary, address currency) external view returns (uint256);

    function totalClaimableRebate(address currency) external view returns (uint256);

    function poolPendingSurcharge(bytes32 poolId, address currency) external view returns (uint256);

    function totalPendingSurcharge(address currency) external view returns (uint256);

    function lpProtectionReserve(bytes32 poolId, address currency) external view returns (uint256);

    function totalLpProtectionReserve(address currency) external view returns (uint256);

    function accountedBalance(address currency) external view returns (uint256);

    function actualBalance(address currency) external view returns (uint256);
}
