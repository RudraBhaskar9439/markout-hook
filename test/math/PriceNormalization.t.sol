// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { PriceNormalization } from "../../src/libraries/PriceNormalization.sol";
import { PriceOrientation } from "../../src/types/MarkoutTypes.sol";
import { PriceNormalizationHarness } from "../harness/PriceNormalizationHarness.sol";

contract PriceNormalizationTest is Test {
    PriceNormalizationHarness private harness;

    function setUp() public {
        harness = new PriceNormalizationHarness();
    }

    function test_normalize_sixDecimalQuotePerBase() public view {
        assertEq(harness.normalize(2000e6, 6, PriceOrientation.QuotePerBase), 2000e18);
    }

    function test_normalize_eightDecimalQuotePerBase() public view {
        assertEq(harness.normalize(2000e8, 8, PriceOrientation.QuotePerBase), 2000e18);
    }

    function test_normalize_eighteenDecimalBasePerQuote_inverts() public view {
        assertEq(harness.normalize(5e14, 18, PriceOrientation.BasePerQuote), 2000e18);
    }

    function test_normalize_moreThanEighteenDecimals_roundsDown() public view {
        assertEq(harness.normalize(2000e24 + 999_999, 24, PriceOrientation.QuotePerBase), 2000e18);
    }

    function test_fromAmounts_ethUsdc() public view {
        assertEq(harness.fromAmounts(1e18, 18, 2000e6, 6), 2000e18);
    }

    function test_fromAmounts_usdcEth() public view {
        assertEq(harness.fromAmounts(2000e6, 6, 1e18, 18), 5e14);
    }

    function test_normalize_zeroPrice_reverts() public {
        vm.expectRevert(PriceNormalization.ZeroPrice.selector);
        harness.normalize(0, 18, PriceOrientation.QuotePerBase);
    }

    function test_normalize_unsupportedDecimals_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(PriceNormalization.UnsupportedDecimals.selector, uint8(37)));
        harness.normalize(1, 37, PriceOrientation.QuotePerBase);
    }

    function test_normalize_precisionLoss_reverts() public {
        vm.expectRevert(PriceNormalization.PricePrecisionLoss.selector);
        harness.normalize(1, 36, PriceOrientation.QuotePerBase);
    }

    function test_normalize_scalingOverflow_reverts() public {
        vm.expectRevert(PriceNormalization.ScalingOverflow.selector);
        harness.normalize(type(uint256).max, 0, PriceOrientation.QuotePerBase);
    }

    function test_normalize_uint192Overflow_reverts() public {
        uint256 overflowingPrice = uint256(type(uint192).max) + 1;
        vm.expectRevert(abi.encodeWithSelector(PriceNormalization.NormalizedPriceOverflow.selector, overflowingPrice));
        harness.normalize(overflowingPrice, 18, PriceOrientation.QuotePerBase);
    }

    function test_fromAmounts_zeroBase_reverts() public {
        vm.expectRevert(PriceNormalization.ZeroBaseAmount.selector);
        harness.fromAmounts(0, 18, 2000e6, 6);
    }

    function test_fromAmounts_zeroQuote_reverts() public {
        vm.expectRevert(PriceNormalization.ZeroQuoteAmount.selector);
        harness.fromAmounts(1e18, 18, 0, 6);
    }

    function testFuzz_normalize_quotePerBaseBelowEighteenDecimals_matchesReference(uint128 rawSeed, uint8 decimalSeed)
        public
        view
    {
        uint8 decimals = uint8(bound(decimalSeed, 0, 18));
        uint256 multiplier = 10 ** uint256(18 - decimals);
        uint256 maximumRaw = uint256(type(uint192).max) / multiplier;
        uint256 rawPrice = bound(rawSeed, 1, maximumRaw);

        assertEq(harness.normalize(rawPrice, decimals, PriceOrientation.QuotePerBase), rawPrice * multiplier);
    }
}
