// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { UniswapV3ReferencePricing } from "../../src/libraries/UniswapV3ReferencePricing.sol";
import { UniswapV3ReferencePricingHarness } from "../harness/UniswapV3ReferencePricingHarness.sol";

contract UniswapV3ReferencePricingTest is Test {
    uint160 private constant Q96 = 1 << 96;

    UniswapV3ReferencePricingHarness private harness;

    function setUp() public {
        harness = new UniswapV3ReferencePricingHarness();
    }

    function test_baseIsToken0_returnsDirectToken1PerToken0Price() public view {
        uint192 priceX18 = harness.quotePerBaseX18(2 * Q96, address(1), 18, address(2), 18);
        assertEq(priceX18, 4e18);
    }

    function test_baseIsToken1_returnsInverseToken0PerToken1Price() public view {
        uint192 priceX18 = harness.quotePerBaseX18(2 * Q96, address(2), 18, address(1), 18);
        assertEq(priceX18, 0.25e18);
    }

    function test_mixedDecimals_normalizesQuotePerBaseToX18() public view {
        // token1/token0 raw ratio = 4e12, so one six-decimal base token quotes as four quote tokens.
        uint192 priceX18 = harness.quotePerBaseX18(2_000_000 * Q96, address(1), 6, address(2), 18);
        assertEq(priceX18, 4e18);
    }

    function test_largeSqrtRatio_usesOverflowSafeQ128Branch() public view {
        uint160 sqrtPriceX96 = uint160(1) << 129;
        uint192 priceX18 = harness.quotePerBaseX18(sqrtPriceX96, address(1), 18, address(2), 18);
        assertEq(priceX18, uint192((uint256(1) << 66) * 1e18));
    }

    function test_zeroSqrtPrice_reverts() public {
        vm.expectRevert(UniswapV3ReferencePricing.ZeroSqrtPrice.selector);
        harness.quotePerBaseX18(0, address(1), 18, address(2), 18);
    }

    function test_identicalTokens_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(UniswapV3ReferencePricing.IdenticalTokens.selector, address(1)));
        harness.quotePerBaseX18(Q96, address(1), 18, address(1), 18);
    }
}
