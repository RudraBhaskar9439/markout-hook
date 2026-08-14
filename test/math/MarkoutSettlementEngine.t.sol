// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { MarkoutParameters } from "../../src/libraries/MarkoutParameters.sol";
import { ReferenceObservationValidator } from "../../src/libraries/ReferenceObservationValidator.sol";
import {
    MarkoutSettlement,
    ObservationRules,
    ReferenceObservation,
    TradeDirection
} from "../../src/types/MarkoutTypes.sol";
import { MarkoutSettlementEngineHarness } from "../harness/MarkoutSettlementEngineHarness.sol";

contract MarkoutSettlementEngineTest is Test {
    MarkoutSettlementEngineHarness private harness;

    function setUp() public {
        harness = new MarkoutSettlementEngineHarness();
    }

    function test_evaluate_validObservation_returnsDeterministicSettlement() public view {
        MarkoutSettlement memory result = harness.evaluate(
            1000,
            2000e18,
            ReferenceObservation({ priceX18: 2002e18, observedAt: 1300, confidenceBps: 9500 }),
            TradeDirection.BuyBase,
            MarkoutParameters.defaultCurve(),
            MarkoutParameters.defaultObservationRules(1300, 1400)
        );

        assertEq(result.markoutWad, 1e15);
        assertEq(result.retentionBps, 5200);
        assertEq(result.retainedSurcharge, 520);
        assertEq(result.rebate, 480);
    }

    function test_evaluate_invalidObservation_revertsBeforeSettlement() public {
        ObservationRules memory rules = MarkoutParameters.defaultObservationRules(1300, 1500);
        ReferenceObservation memory stale =
            ReferenceObservation({ priceX18: 2002e18, observedAt: 1300, confidenceBps: 9500 });

        vm.expectRevert(
            abi.encodeWithSelector(ReferenceObservationValidator.StaleObservation.selector, uint64(200), uint64(120))
        );
        harness.evaluate(1000, 2000e18, stale, TradeDirection.BuyBase, MarkoutParameters.defaultCurve(), rules);
    }
}
