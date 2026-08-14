// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { MarkoutMath } from "../../src/libraries/MarkoutMath.sol";
import { MarkoutCurve, MarkoutSettlement, TradeDirection } from "../../src/types/MarkoutTypes.sol";
import { MarkoutMathHarness } from "../harness/MarkoutMathHarness.sol";

contract MarkoutMathTest is Test {
    uint192 private constant EXECUTION_PRICE = 2000e18;
    uint128 private constant ESCROW = 1000;

    MarkoutMathHarness private harness;
    MarkoutCurve private curve;

    function setUp() public {
        harness = new MarkoutMathHarness();
        curve = harness.defaultCurve();
    }

    function test_calculateMarkout_buyBaseAdverse_isPositive() public view {
        assertEq(harness.calculateMarkoutWad(EXECUTION_PRICE, 2002e18, TradeDirection.BuyBase), 1e15);
    }

    function test_calculateMarkout_buyBaseInventoryImproving_isNegative() public view {
        assertEq(harness.calculateMarkoutWad(EXECUTION_PRICE, 1998e18, TradeDirection.BuyBase), -1e15);
    }

    function test_calculateMarkout_sellBaseAdverse_isPositive() public view {
        assertEq(harness.calculateMarkoutWad(EXECUTION_PRICE, 1998e18, TradeDirection.SellBase), 1e15);
    }

    function test_calculateMarkout_sellBaseInventoryImproving_isNegative() public view {
        assertEq(harness.calculateMarkoutWad(EXECUTION_PRICE, 2002e18, TradeDirection.SellBase), -1e15);
    }

    function test_calculateMarkout_neutral_isZero() public view {
        assertEq(harness.calculateMarkoutWad(EXECUTION_PRICE, EXECUTION_PRICE, TradeDirection.BuyBase), 0);
        assertEq(harness.calculateMarkoutWad(EXECUTION_PRICE, EXECUTION_PRICE, TradeDirection.SellBase), 0);
    }

    function test_retention_defaultCurve_anchorPointsAndInterpolation() public view {
        assertEq(harness.defaultRetentionBps(-6e14), 0);
        assertEq(harness.defaultRetentionBps(-5e14), 0);
        assertEq(harness.defaultRetentionBps(-25e13), 1000);
        assertEq(harness.defaultRetentionBps(0), 2000);
        assertEq(harness.defaultRetentionBps(125e13), 6000);
        assertEq(harness.defaultRetentionBps(25e14), 10_000);
        assertEq(harness.defaultRetentionBps(30e14), 10_000);
    }

    function test_settle_mildAdverseBuy_splitsEscrow() public view {
        MarkoutSettlement memory result =
            harness.settleDefault(ESCROW, EXECUTION_PRICE, 2002e18, TradeDirection.BuyBase);

        assertEq(result.markoutWad, 1e15);
        assertEq(result.retentionBps, 5200);
        assertEq(result.retainedSurcharge, 520);
        assertEq(result.rebate, 480);
    }

    function test_settle_neutralTrade_rebatesEightyPercent() public view {
        MarkoutSettlement memory result =
            harness.settleDefault(ESCROW, EXECUTION_PRICE, EXECUTION_PRICE, TradeDirection.BuyBase);

        assertEq(result.retentionBps, 2000);
        assertEq(result.retainedSurcharge, 200);
        assertEq(result.rebate, 800);
    }

    function test_settle_inventoryImprovingTrade_fullRebate() public view {
        MarkoutSettlement memory result =
            harness.settleDefault(ESCROW, EXECUTION_PRICE, 1998e18, TradeDirection.BuyBase);

        assertEq(result.retentionBps, 0);
        assertEq(result.retainedSurcharge, 0);
        assertEq(result.rebate, ESCROW);
    }

    function test_settle_toxicTrade_fullRetention() public view {
        MarkoutSettlement memory result =
            harness.settleDefault(ESCROW, EXECUTION_PRICE, 2006e18, TradeDirection.BuyBase);

        assertEq(result.retentionBps, 10_000);
        assertEq(result.retainedSurcharge, ESCROW);
        assertEq(result.rebate, 0);
    }

    function test_settle_roundingRemainderGoesToTraderRebate() public view {
        MarkoutSettlement memory result =
            harness.settleDefault(3, EXECUTION_PRICE, EXECUTION_PRICE, TradeDirection.BuyBase);

        assertEq(result.retentionBps, 2000);
        assertEq(result.retainedSurcharge, 0);
        assertEq(result.rebate, 3);
    }

    function test_settle_zeroEscrow_remainsConserved() public view {
        MarkoutSettlement memory result = harness.settleDefault(0, EXECUTION_PRICE, 2006e18, TradeDirection.BuyBase);

        assertEq(result.retainedSurcharge, 0);
        assertEq(result.rebate, 0);
    }

    function test_calculateMarkout_zeroExecutionPrice_reverts() public {
        vm.expectRevert(MarkoutMath.ZeroExecutionPrice.selector);
        harness.calculateMarkoutWad(0, EXECUTION_PRICE, TradeDirection.BuyBase);
    }

    function test_calculateMarkout_zeroReferencePrice_reverts() public {
        vm.expectRevert(MarkoutMath.ZeroReferencePrice.selector);
        harness.calculateMarkoutWad(EXECUTION_PRICE, 0, TradeDirection.BuyBase);
    }

    function test_retention_zeroFavorableCutoff_reverts() public {
        curve.favorableCutoffWad = 0;
        vm.expectRevert(MarkoutMath.ZeroFavorableCutoff.selector);
        harness.retentionBps(0, curve);
    }

    function test_retention_zeroAdverseCutoff_reverts() public {
        curve.adverseCutoffWad = 0;
        vm.expectRevert(MarkoutMath.ZeroAdverseCutoff.selector);
        harness.retentionBps(0, curve);
    }

    function test_retention_minimumAboveOneHundredPercent_reverts() public {
        curve.minimumRetentionBps = 10_001;
        vm.expectRevert(abi.encodeWithSelector(MarkoutMath.InvalidMinimumRetention.selector, uint16(10_001)));
        harness.retentionBps(0, curve);
    }

    function test_retention_neutralBelowMinimum_reverts() public {
        curve.minimumRetentionBps = 5000;
        curve.neutralRetentionBps = 4999;
        vm.expectRevert(
            abi.encodeWithSelector(MarkoutMath.InvalidNeutralRetention.selector, uint16(5000), uint16(4999))
        );
        harness.retentionBps(0, curve);
    }

    function testFuzz_settlement_isBoundedAndConserved(
        uint128 escrowedSurcharge,
        uint192 executionSeed,
        uint192 referenceSeed,
        bool sellBase
    ) public view {
        uint192 executionPrice = uint192(bound(executionSeed, 1, type(uint192).max));
        uint192 referencePrice = uint192(bound(referenceSeed, 1, type(uint192).max));
        TradeDirection direction = sellBase ? TradeDirection.SellBase : TradeDirection.BuyBase;

        MarkoutSettlement memory result =
            harness.settleDefault(escrowedSurcharge, executionPrice, referencePrice, direction);

        assertLe(result.retentionBps, 10_000);
        assertLe(result.retainedSurcharge, escrowedSurcharge);
        assertLe(result.rebate, escrowedSurcharge);
        assertEq(uint256(result.retainedSurcharge) + result.rebate, escrowedSurcharge);
    }

    function testFuzz_positiveMarkoutRetention_isMonotonic(uint64 firstSeed, uint64 secondSeed) public view {
        int256 first = int256(uint256(bound(firstSeed, 0, 5e15)));
        int256 second = int256(uint256(bound(secondSeed, 0, 5e15)));
        if (first > second) (first, second) = (second, first);

        assertLe(harness.defaultRetentionBps(first), harness.defaultRetentionBps(second));
    }

    function testFuzz_entireCurve_isMonotonic(int128 firstSeed, int128 secondSeed) public view {
        int256 first = bound(firstSeed, -1e16, 1e16);
        int256 second = bound(secondSeed, -1e16, 1e16);
        if (first > second) (first, second) = (second, first);

        assertLe(harness.defaultRetentionBps(first), harness.defaultRetentionBps(second));
    }

    function testFuzz_directionSymmetry_forEquivalentFavorableMoves(uint192 executionSeed, uint192 differenceSeed)
        public
        view
    {
        uint192 executionPrice = uint192(bound(executionSeed, 2, type(uint192).max / 2));
        uint192 difference = uint192(bound(differenceSeed, 0, executionPrice - 1));

        int256 buyMarkout =
            harness.calculateMarkoutWad(executionPrice, executionPrice + difference, TradeDirection.BuyBase);
        int256 sellMarkout =
            harness.calculateMarkoutWad(executionPrice, executionPrice - difference, TradeDirection.SellBase);

        assertEq(buyMarkout, sellMarkout);
    }

    function testFuzz_directionSymmetry_forEquivalentUnfavorableMoves(uint192 executionSeed, uint192 differenceSeed)
        public
        view
    {
        uint192 executionPrice = uint192(bound(executionSeed, 2, type(uint192).max / 2));
        uint192 difference = uint192(bound(differenceSeed, 0, executionPrice - 1));

        int256 buyMarkout =
            harness.calculateMarkoutWad(executionPrice, executionPrice - difference, TradeDirection.BuyBase);
        int256 sellMarkout =
            harness.calculateMarkoutWad(executionPrice, executionPrice + difference, TradeDirection.SellBase);

        assertEq(buyMarkout, sellMarkout);
    }
}
