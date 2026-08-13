// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { BalanceDelta, BalanceDeltaLibrary } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";

import { UnspecifiedSwapDelta } from "../types/SurchargeTypes.sol";

/// @title Swap Delta Accounting
/// @notice Resolves the currency and absolute amount affected by an `afterSwap` hook return delta.
library SwapDeltaAccounting {
    using BalanceDeltaLibrary for BalanceDelta;

    /// @notice Resolves the swap's unspecified currency and its pre-hook magnitude.
    /// @dev In v4, `afterSwap` return deltas always apply to the unspecified side. That side is output
    ///      for exact-input swaps and input for exact-output swaps.
    function unspecified(PoolKey calldata key, SwapParams calldata params, BalanceDelta swapDelta)
        internal
        pure
        returns (UnspecifiedSwapDelta memory resolved)
    {
        bool exactInput = params.amountSpecified < 0;
        bool specifiedCurrencyIs0 = exactInput == params.zeroForOne;
        int128 signedAmount = specifiedCurrencyIs0 ? swapDelta.amount1() : swapDelta.amount0();

        resolved = UnspecifiedSwapDelta({
            currency: specifiedCurrencyIs0 ? key.currency1 : key.currency0,
            amount: absolute(signedAmount),
            isInput: !exactInput
        });
    }

    /// @notice Returns the absolute value of an `int128` without overflowing on `type(int128).min`.
    function absolute(int128 amount) internal pure returns (uint128 magnitude) {
        int256 widened = int256(amount);
        magnitude = uint128(uint256(widened < 0 ? -widened : widened));
    }
}
