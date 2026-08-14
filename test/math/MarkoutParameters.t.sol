// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { MarkoutParameters } from "../../src/libraries/MarkoutParameters.sol";
import { MarkoutCurve, ObservationRules } from "../../src/types/MarkoutTypes.sol";
import { MarkoutParametersHarness } from "../harness/MarkoutParametersHarness.sol";

contract MarkoutParametersTest is Test {
    MarkoutParametersHarness private harness;

    function setUp() public {
        harness = new MarkoutParametersHarness();
    }

    function test_defaultCurve_isFrozen() public view {
        MarkoutCurve memory curve = harness.defaultCurve();

        assertEq(curve.favorableCutoffWad, 5e14);
        assertEq(curve.adverseCutoffWad, 25e14);
        assertEq(curve.minimumRetentionBps, 0);
        assertEq(curve.neutralRetentionBps, 2000);
    }

    function test_maturityTimestamp_usesFiveMinuteDelay() public view {
        assertEq(harness.maturityTimestamp(1000), 1300);
    }

    function test_maturityTimestamp_overflow_reverts() public {
        uint64 executedAt = type(uint64).max - 299;
        vm.expectRevert(abi.encodeWithSelector(MarkoutParameters.TimestampOverflow.selector, executedAt, uint64(300)));
        harness.maturityTimestamp(executedAt);
    }

    function test_expiryTimestamp_usesTenMinuteGracePeriod() public view {
        assertEq(harness.expiryTimestamp(1300), 1900);
    }

    function test_expiryTimestamp_overflow_reverts() public {
        uint64 maturity = type(uint64).max - 599;
        vm.expectRevert(abi.encodeWithSelector(MarkoutParameters.TimestampOverflow.selector, maturity, uint64(600)));
        harness.expiryTimestamp(maturity);
    }

    function test_defaultObservationRules_areFrozen() public view {
        ObservationRules memory rules = harness.defaultObservationRules(1300, 1400);

        assertEq(rules.maturityTimestamp, 1300);
        assertEq(rules.evaluationTimestamp, 1400);
        assertEq(rules.maximumAge, 120);
        assertEq(rules.minimumConfidenceBps, 9000);
        assertEq(rules.settlementGracePeriod, 600);
    }

    function test_settlementGracePeriod_isTenMinutes() public view {
        assertEq(harness.settlementGracePeriod(), 600);
    }
}
