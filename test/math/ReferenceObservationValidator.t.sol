// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { ReferenceObservationValidator } from "../../src/libraries/ReferenceObservationValidator.sol";
import { ObservationRules, ReferenceObservation } from "../../src/types/MarkoutTypes.sol";
import { ReferenceObservationValidatorHarness } from "../harness/ReferenceObservationValidatorHarness.sol";

contract ReferenceObservationValidatorTest is Test {
    uint64 private constant MATURITY = 1000;
    uint64 private constant EVALUATION = 1200;
    uint64 private constant MAXIMUM_AGE = 200;
    uint16 private constant MINIMUM_CONFIDENCE = 9000;
    uint192 private constant PRICE = 2000e18;

    ReferenceObservationValidatorHarness private harness;

    function setUp() public {
        harness = new ReferenceObservationValidatorHarness();
    }

    function test_validate_exactTimeAndConfidenceBoundaries_succeeds() public view {
        assertEq(harness.validate(_observation(MATURITY, MINIMUM_CONFIDENCE), _rules()), PRICE);
    }

    function test_validate_missingObservation_reverts() public {
        vm.expectRevert(ReferenceObservationValidator.MissingObservation.selector);
        harness.validate(ReferenceObservation({ priceX18: 0, observedAt: 0, confidenceBps: 0 }), _rules());
    }

    function test_validate_zeroPrice_reverts() public {
        vm.expectRevert(ReferenceObservationValidator.ZeroObservationPrice.selector);
        harness.validate(
            ReferenceObservation({ priceX18: 0, observedAt: MATURITY, confidenceBps: MINIMUM_CONFIDENCE }), _rules()
        );
    }

    function test_validate_beforeMaturity_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceObservationValidator.ObservationBeforeMaturity.selector, MATURITY - 1, MATURITY
            )
        );
        harness.validate(_observation(MATURITY - 1, MINIMUM_CONFIDENCE), _rules());
    }

    function test_validate_futureObservation_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceObservationValidator.ObservationFromFuture.selector, EVALUATION + 1, EVALUATION
            )
        );
        harness.validate(_observation(EVALUATION + 1, MINIMUM_CONFIDENCE), _rules());
    }

    function test_validate_staleObservation_reverts() public {
        ObservationRules memory rules = _rules();
        rules.maturityTimestamp = MATURITY - 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceObservationValidator.StaleObservation.selector, MAXIMUM_AGE + 1, MAXIMUM_AGE
            )
        );
        harness.validate(_observation(MATURITY - 1, MINIMUM_CONFIDENCE), rules);
    }

    function test_validate_lowConfidence_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceObservationValidator.ConfidenceBelowMinimum.selector,
                MINIMUM_CONFIDENCE - 1,
                MINIMUM_CONFIDENCE
            )
        );
        harness.validate(_observation(MATURITY, MINIMUM_CONFIDENCE - 1), _rules());
    }

    function test_validate_confidenceAboveOneHundredPercent_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(ReferenceObservationValidator.InvalidConfidence.selector, uint16(10_001))
        );
        harness.validate(_observation(MATURITY, 10_001), _rules());
    }

    function test_validate_invalidMinimumConfidence_reverts() public {
        ObservationRules memory rules = _rules();
        rules.minimumConfidenceBps = 10_001;

        vm.expectRevert(
            abi.encodeWithSelector(ReferenceObservationValidator.InvalidMinimumConfidence.selector, uint16(10_001))
        );
        harness.validate(_observation(MATURITY, MINIMUM_CONFIDENCE), rules);
    }

    function test_validate_evaluationBeforeMaturity_reverts() public {
        ObservationRules memory rules = _rules();
        rules.evaluationTimestamp = MATURITY - 1;

        vm.expectRevert(
            abi.encodeWithSelector(ReferenceObservationValidator.MaturityNotReached.selector, MATURITY, MATURITY - 1)
        );
        harness.validate(_observation(MATURITY, MINIMUM_CONFIDENCE), rules);
    }

    function test_validate_afterSettlementGracePeriod_reverts() public {
        ObservationRules memory rules = _rules();
        rules.evaluationTimestamp = MATURITY + 601;

        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceObservationValidator.SettlementWindowExpired.selector, uint64(601), uint64(600)
            )
        );
        harness.validate(_observation(rules.evaluationTimestamp, MINIMUM_CONFIDENCE), rules);
    }

    function test_isExpired_atDeadline_isFalse() public view {
        assertFalse(harness.isExpired(MATURITY, MATURITY + 600, 600));
    }

    function test_isExpired_afterDeadline_isTrue() public view {
        assertTrue(harness.isExpired(MATURITY, MATURITY + 601, 600));
    }

    function test_isExpired_nearUint64Maximum_doesNotOverflow() public view {
        assertFalse(harness.isExpired(type(uint64).max - 5, type(uint64).max, 10));
    }

    function _observation(uint64 observedAt, uint16 confidenceBps) private pure returns (ReferenceObservation memory) {
        return ReferenceObservation({ priceX18: PRICE, observedAt: observedAt, confidenceBps: confidenceBps });
    }

    function _rules() private pure returns (ObservationRules memory) {
        return ObservationRules({
            maturityTimestamp: MATURITY,
            evaluationTimestamp: EVALUATION,
            maximumAge: MAXIMUM_AGE,
            minimumConfidenceBps: MINIMUM_CONFIDENCE,
            settlementGracePeriod: 600
        });
    }
}
