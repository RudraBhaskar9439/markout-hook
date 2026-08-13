// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { IProvisionalSurchargeHook } from "../../src/interfaces/IProvisionalSurchargeHook.sol";
import { SurchargeMath } from "../../src/libraries/SurchargeMath.sol";
import { SurchargeMathHarness } from "../harness/SurchargeMathHarness.sol";

contract SurchargeMathTest is Test {
    SurchargeMathHarness private harness;

    function setUp() public {
        harness = new SurchargeMathHarness();
    }

    function test_quoteBps_zeroBasis_returnsZero() public pure {
        assertEq(SurchargeMath.quoteBps(0, 500), 0);
    }

    function test_quoteBps_zeroRate_returnsZero() public pure {
        assertEq(SurchargeMath.quoteBps(1 ether, 0), 0);
    }

    function test_quoteBps_roundsDown() public pure {
        assertEq(SurchargeMath.quoteBps(199, 50), 0);
        assertEq(SurchargeMath.quoteBps(200, 50), 1);
    }

    function test_quoteBps_fullRate_returnsBasis() public pure {
        assertEq(SurchargeMath.quoteBps(type(uint128).max, 10_000), type(uint128).max);
    }

    function testFuzz_quoteBps_matchesReference(uint128 basisAmount, uint16 rawRate) public pure {
        uint16 rateBps = uint16(bound(rawRate, 0, 10_000));
        uint128 expected = uint128(uint256(basisAmount) * rateBps / 10_000);

        assertEq(SurchargeMath.quoteBps(basisAmount, rateBps), expected);
    }

    function test_quoteBps_rateAboveOneHundredPercent_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(SurchargeMath.InvalidBasisPointRate.selector, 10_001));
        harness.quoteBps(1 ether, 10_001);
    }

    function test_toHookDelta_maximumSignedAmount_succeeds() public pure {
        uint128 amount = uint128(type(int128).max);
        assertEq(SurchargeMath.toHookDelta(amount), type(int128).max);
    }

    function test_toHookDelta_overflow_reverts() public {
        uint128 amount = uint128(type(int128).max) + 1;

        vm.expectRevert(abi.encodeWithSelector(IProvisionalSurchargeHook.SurchargeAmountOverflow.selector, amount));
        harness.toHookDelta(amount);
    }
}
