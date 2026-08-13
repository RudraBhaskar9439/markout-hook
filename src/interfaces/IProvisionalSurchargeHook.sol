// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Provisional Surcharge Hook Interface
/// @notice Read interface and canonical events for MARKOUT-compatible surcharge accounting.
interface IProvisionalSurchargeHook {
    /// @notice A quoted provisional surcharge exceeded the swapper's declared maximum.
    /// @param quotedAmount Amount calculated by the hook's pricing policy.
    /// @param maximumAmount Maximum amount accepted in hook data.
    error SurchargeExceedsMaximum(uint128 quotedAmount, uint128 maximumAmount);

    /// @notice A pricing policy returned a value that cannot be represented by a v4 hook delta.
    /// @param amount Invalid unsigned amount.
    error SurchargeAmountOverflow(uint256 amount);

    /// @notice A fixed surcharge rate exceeded the protocol's constructor cap.
    /// @param providedBps Supplied rate in basis points.
    /// @param maximumBps Largest accepted rate in basis points.
    error SurchargeRateTooHigh(uint256 providedBps, uint256 maximumBps);

    /// @notice Emitted after a provisional surcharge is transferred to and accounted by the hook.
    /// @param poolId Uniswap v4 pool identifier.
    /// @param swapSender Account that called `PoolManager.swap` (normally a router).
    /// @param rebateRecipient Account selected to receive any future MARKOUT rebate.
    /// @param currency Currency held by the hook.
    /// @param basisAmount Absolute pre-hook amount on the unspecified side of the swap.
    /// @param surchargeAmount Provisional surcharge transferred to the hook.
    /// @param maximumAmount Maximum surcharge accepted by the swapper.
    event ProvisionalSurchargeAccrued(
        bytes32 indexed poolId,
        address indexed swapSender,
        address indexed rebateRecipient,
        address currency,
        uint128 basisAmount,
        uint128 surchargeAmount,
        uint128 maximumAmount
    );

    /// @notice Returns provisional surcharge accounted to a pool and currency.
    function poolAccruedSurcharge(bytes32 poolId, address currency) external view returns (uint256 amount);

    /// @notice Returns provisional surcharge accounted across all pools for a currency.
    function totalAccruedSurcharge(address currency) external view returns (uint256 amount);
}
