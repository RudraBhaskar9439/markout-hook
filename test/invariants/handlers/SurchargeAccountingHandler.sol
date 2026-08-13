// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20Minimal } from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";

import { SurchargeHookData } from "../../../src/libraries/SurchargeHookData.sol";
import { SurchargeAuthorization } from "../../../src/types/SurchargeTypes.sol";

contract SurchargeAccountingHandler {
    uint128 private constant MIN_AMOUNT = 1e6;
    uint128 private constant MAX_AMOUNT = 1e10;

    PoolSwapTest public immutable swapRouter;
    PoolKey private _poolKey;
    uint256 public calls;

    constructor(PoolSwapTest swapRouter_, PoolKey memory poolKey_) {
        swapRouter = swapRouter_;
        _poolKey = poolKey_;

        IERC20Minimal(Currency.unwrap(poolKey_.currency0)).approve(address(swapRouter_), type(uint256).max);
        IERC20Minimal(Currency.unwrap(poolKey_.currency1)).approve(address(swapRouter_), type(uint256).max);
    }

    function swap(uint96 seed, uint8 quadrantSeed) external {
        uint128 amount = MIN_AMOUNT + uint128(seed % (MAX_AMOUNT - MIN_AMOUNT + 1));
        uint8 quadrant = quadrantSeed % 4;
        bool zeroForOne = quadrant < 2;
        bool exactInput = quadrant % 2 == 0;

        swapRouter.swap(
            _poolKey,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: exactInput ? -int256(uint256(amount)) : int256(uint256(amount)),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            SurchargeHookData.encode(
                SurchargeAuthorization({ rebateRecipient: address(this), maximumAmount: type(uint128).max })
            )
        );

        ++calls;
    }
}
