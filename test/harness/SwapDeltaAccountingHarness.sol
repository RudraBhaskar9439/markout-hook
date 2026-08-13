// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { BalanceDelta } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";

import { SwapDeltaAccounting } from "../../src/libraries/SwapDeltaAccounting.sol";
import { UnspecifiedSwapDelta } from "../../src/types/SurchargeTypes.sol";

contract SwapDeltaAccountingHarness {
    function unspecified(PoolKey calldata key, SwapParams calldata params, BalanceDelta swapDelta)
        external
        pure
        returns (Currency currency, uint128 amount, bool isInput)
    {
        UnspecifiedSwapDelta memory resolved = SwapDeltaAccounting.unspecified(key, params, swapDelta);
        return (resolved.currency, resolved.amount, resolved.isInput);
    }

    function absolute(int128 amount) external pure returns (uint128 magnitude) {
        return SwapDeltaAccounting.absolute(amount);
    }
}
