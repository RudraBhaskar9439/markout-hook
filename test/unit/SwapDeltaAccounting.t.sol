// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { BalanceDelta, toBalanceDelta } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";

import { SwapDeltaAccountingHarness } from "../harness/SwapDeltaAccountingHarness.sol";

contract SwapDeltaAccountingTest is Test {
    Currency private constant CURRENCY_0 = Currency.wrap(address(0x1000));
    Currency private constant CURRENCY_1 = Currency.wrap(address(0x2000));

    SwapDeltaAccountingHarness private harness;
    PoolKey private key;

    function setUp() public {
        harness = new SwapDeltaAccountingHarness();
        key = PoolKey({
            currency0: CURRENCY_0, currency1: CURRENCY_1, fee: 3000, tickSpacing: 60, hooks: IHooks(address(0))
        });
    }

    function test_exactInput_zeroForOne_resolvesOutputCurrency1() public view {
        _assertResolution(true, -1000, toBalanceDelta(-1000, 900), CURRENCY_1, 900, false);
    }

    function test_exactInput_oneForZero_resolvesOutputCurrency0() public view {
        _assertResolution(false, -1000, toBalanceDelta(900, -1000), CURRENCY_0, 900, false);
    }

    function test_exactOutput_zeroForOne_resolvesInputCurrency0() public view {
        _assertResolution(true, 1000, toBalanceDelta(-1100, 1000), CURRENCY_0, 1100, true);
    }

    function test_exactOutput_oneForZero_resolvesInputCurrency1() public view {
        _assertResolution(false, 1000, toBalanceDelta(1000, -1100), CURRENCY_1, 1100, true);
    }

    function test_absolute_minimumInt128_doesNotOverflow() public view {
        assertEq(harness.absolute(type(int128).min), uint128(1) << 127);
    }

    function testFuzz_absolute_matchesReference(int128 amount) public view {
        int256 widened = int256(amount);
        uint128 expected = uint128(uint256(widened < 0 ? -widened : widened));
        assertEq(harness.absolute(amount), expected);
    }

    function _assertResolution(
        bool zeroForOne,
        int256 amountSpecified,
        BalanceDelta swapDelta,
        Currency expectedCurrency,
        uint128 expectedAmount,
        bool expectedIsInput
    ) private view {
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne, amountSpecified: amountSpecified, sqrtPriceLimitX96: 1
        });

        (Currency currency, uint128 amount, bool isInput) = harness.unspecified(key, params, swapDelta);

        assertEq(Currency.unwrap(currency), Currency.unwrap(expectedCurrency));
        assertEq(amount, expectedAmount);
        assertEq(isInput, expectedIsInput);
    }
}
