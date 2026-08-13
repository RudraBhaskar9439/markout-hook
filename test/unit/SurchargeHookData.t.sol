// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { SurchargeHookData } from "../../src/libraries/SurchargeHookData.sol";
import { SurchargeAuthorization } from "../../src/types/SurchargeTypes.sol";
import { SurchargeHookDataHarness } from "../harness/SurchargeHookDataHarness.sol";

contract SurchargeHookDataTest is Test {
    SurchargeHookDataHarness private harness;

    function setUp() public {
        harness = new SurchargeHookDataHarness();
    }

    function test_roundTrip_succeeds() public view {
        address recipient = address(0xBEEF);
        uint128 maximumAmount = 123_456_789;

        bytes memory encoded = SurchargeHookData.encode(
            SurchargeAuthorization({ rebateRecipient: recipient, maximumAmount: maximumAmount })
        );
        (address decodedRecipient, uint128 decodedMaximum) = harness.decode(encoded);

        assertEq(encoded.length, 64);
        assertEq(decodedRecipient, recipient);
        assertEq(decodedMaximum, maximumAmount);
    }

    function testFuzz_roundTrip_succeeds(address recipient, uint128 maximumAmount) public view {
        vm.assume(recipient != address(0));

        bytes memory encoded = SurchargeHookData.encode(
            SurchargeAuthorization({ rebateRecipient: recipient, maximumAmount: maximumAmount })
        );
        (address decodedRecipient, uint128 decodedMaximum) = harness.decode(encoded);

        assertEq(decodedRecipient, recipient);
        assertEq(decodedMaximum, maximumAmount);
    }

    function test_decode_shortData_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(SurchargeHookData.InvalidHookDataLength.selector, 63));
        harness.decode(new bytes(63));
    }

    function test_decode_longData_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(SurchargeHookData.InvalidHookDataLength.selector, 65));
        harness.decode(new bytes(65));
    }

    function test_decode_nonCanonicalRecipient_reverts() public {
        bytes memory malformed = abi.encode(type(uint256).max, uint128(1));

        vm.expectRevert(SurchargeHookData.InvalidRecipientEncoding.selector);
        harness.decode(malformed);
    }

    function test_decode_nonCanonicalMaximum_reverts() public {
        bytes memory malformed = abi.encode(address(0xBEEF), type(uint256).max);

        vm.expectRevert(SurchargeHookData.InvalidMaximumAmountEncoding.selector);
        harness.decode(malformed);
    }

    function test_decode_zeroRecipient_reverts() public {
        bytes memory malformed = abi.encode(address(0), uint128(1));

        vm.expectRevert(SurchargeHookData.ZeroRebateRecipient.selector);
        harness.decode(malformed);
    }
}
