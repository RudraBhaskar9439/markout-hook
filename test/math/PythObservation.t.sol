// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { PythPrice } from "../../src/interfaces/IPyth.sol";
import { PriceNormalization } from "../../src/libraries/PriceNormalization.sol";
import { PythObservation } from "../../src/libraries/PythObservation.sol";
import { ReferenceObservation } from "../../src/types/MarkoutTypes.sol";
import { PythObservationHarness } from "../harness/PythObservationHarness.sol";

contract PythObservationTest is Test {
    PythObservationHarness private harness;

    function setUp() public {
        harness = new PythObservationHarness();
    }

    function test_negativeExponentNormalizesPriceAndMechanicalConfidence() public view {
        ReferenceObservation memory observation = harness.normalize(_price(2000e8, 1e8, -8, 1234));
        assertEq(observation.priceX18, 2000e18);
        assertEq(observation.observedAt, 1234);
        assertEq(observation.confidenceBps, 9995);
    }

    function test_positiveExponentNormalizesPrice() public view {
        ReferenceObservation memory observation = harness.normalize(_price(20, 0, 2, 1234));
        assertEq(observation.priceX18, 2000e18);
        assertEq(observation.confidenceBps, 10_000);
    }

    function test_uncertaintyAtOrAbovePriceProducesZeroConfidence() public view {
        ReferenceObservation memory equal = harness.normalize(_price(100, 100, 0, 1234));
        ReferenceObservation memory greater = harness.normalize(_price(100, 101, 0, 1234));
        assertEq(equal.confidenceBps, 0);
        assertEq(greater.confidenceBps, 0);
    }

    function test_nonPositivePricesRevert() public {
        vm.expectRevert(abi.encodeWithSelector(PythObservation.NonPositivePrice.selector, int64(0)));
        harness.normalize(_price(0, 0, -8, 1234));

        vm.expectRevert(abi.encodeWithSelector(PythObservation.NonPositivePrice.selector, int64(-1)));
        harness.normalize(_price(-1, 0, -8, 1234));
    }

    function test_unsupportedExponentsRevert() public {
        vm.expectRevert(abi.encodeWithSelector(PythObservation.UnsupportedExponent.selector, int32(-37)));
        harness.normalize(_price(1, 0, -37, 1234));

        vm.expectRevert(abi.encodeWithSelector(PythObservation.UnsupportedExponent.selector, int32(19)));
        harness.normalize(_price(1, 0, 19, 1234));
    }

    function test_publishTimeOverflowReverts() public {
        PythPrice memory pythPrice = _price(1, 0, 0, 0);
        pythPrice.publishTime = uint256(type(uint64).max) + 1;
        vm.expectRevert(abi.encodeWithSelector(PythObservation.PublishTimeOverflow.selector, pythPrice.publishTime));
        harness.normalize(pythPrice);
    }

    function test_precisionLossStillUsesCanonicalPriceValidation() public {
        vm.expectRevert(PriceNormalization.PricePrecisionLoss.selector);
        harness.normalize(_price(1, 0, -36, 1234));
    }

    function _price(int64 price, uint64 conf, int32 expo, uint256 publishTime) private pure returns (PythPrice memory) {
        return PythPrice({ price: price, conf: conf, expo: expo, publishTime: publishTime });
    }
}
