// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId } from "@uniswap/v4-core/src/types/PoolId.sol";

/// @notice User-provided constraints carried in the swap's hook data.
/// @param rebateRecipient Account that will receive any future MARKOUT rebate.
/// @param maximumAmount Maximum provisional surcharge accepted by the swapper.
struct SurchargeAuthorization {
    address rebateRecipient;
    uint128 maximumAmount;
}

/// @notice The currency and magnitude on the unspecified side of a v4 swap.
/// @param currency Currency affected by an `afterSwap` return delta.
/// @param amount Absolute pre-hook magnitude of the unspecified swap delta.
/// @param isInput True for exact-output swaps, false for exact-input swaps.
struct UnspecifiedSwapDelta {
    Currency currency;
    uint128 amount;
    bool isInput;
}

/// @notice Complete context supplied to a provisional-surcharge pricing policy.
/// @param poolId Pool whose swap is being priced.
/// @param swapSender Account that called `PoolManager.swap` (normally a router).
/// @param rebateRecipient Account selected to receive any future rebate.
/// @param currency Currency in which the provisional surcharge is escrowed.
/// @param basisAmount Absolute pre-hook amount used as the surcharge basis.
/// @param maximumAmount Maximum provisional surcharge accepted by the swapper.
/// @param exactInput True when `amountSpecified` is negative.
/// @param zeroForOne Direction supplied to the v4 swap.
struct SurchargeQuote {
    PoolId poolId;
    address swapSender;
    address rebateRecipient;
    Currency currency;
    uint128 basisAmount;
    uint128 maximumAmount;
    bool exactInput;
    bool zeroForOne;
}
