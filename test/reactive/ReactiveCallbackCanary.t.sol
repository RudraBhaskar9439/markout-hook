// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ReactiveTest } from "reactive-test-lib/base/ReactiveTest.sol";
import { CallbackResult } from "reactive-test-lib/interfaces/IReactiveInterfaces.sol";

import { AuthenticatedReactiveCallback } from "../../src/base/AuthenticatedReactiveCallback.sol";
import { ReactiveCallbackCanary } from "../../src/canary/ReactiveCallbackCanary.sol";
import { ReactiveCallbackCanaryScheduler } from "../../src/canary/ReactiveCallbackCanaryScheduler.sol";

contract ReactiveCallbackCanaryTest is ReactiveTest {
    uint256 private constant SEPOLIA_CHAIN_ID = 11_155_111;

    ReactiveCallbackCanary private canary;
    ReactiveCallbackCanaryScheduler private scheduler;

    function setUp() public override {
        super.setUp();
        canary = new ReactiveCallbackCanary(address(proxy), rvmId);
        scheduler =
            new ReactiveCallbackCanaryScheduler(address(sys), SEPOLIA_CHAIN_ID, SEPOLIA_CHAIN_ID, address(canary));
        registerChain(address(canary), SEPOLIA_CHAIN_ID);
    }

    function test_threeRequestsProduceThreeAuthenticatedCallbacks() public {
        for (uint256 expectedRequestId = 1; expectedRequestId <= 3; ++expectedRequestId) {
            CallbackResult[] memory callbacks = triggerAndReact(
                address(canary), abi.encodeCall(ReactiveCallbackCanary.requestCallback, ()), SEPOLIA_CHAIN_ID
            );

            assertCallbackCount(callbacks, 1);
            assertCallbackSuccess(callbacks, 0);
            assertCallbackEmitted(callbacks, address(canary));
            assertTrue(canary.callbackReceived(expectedRequestId));
            assertGt(canary.callbackOriginBlock(expectedRequestId), 0);
        }

        assertEq(canary.requestCount(), 3);
        assertEq(canary.callbackCount(), 3);
    }

    function test_directCallbackIsRejected() public {
        vm.expectRevert(
            abi.encodeWithSelector(AuthenticatedReactiveCallback.UnauthorizedCallbackSender.selector, address(this))
        );
        canary.receiveCallback(rvmId, 1, block.number);
    }

    function test_unknownAuthenticatedRequestIsRejected() public {
        bytes memory payload = abi.encodeCall(ReactiveCallbackCanary.receiveCallback, (address(0), 1, block.number));
        (bool success, bytes memory returnData) =
            proxy.executeCallback(address(canary), payload, scheduler.CALLBACK_GAS_LIMIT(), rvmId);

        assertFalse(success);
        assertEq(returnData, abi.encodeWithSelector(ReactiveCallbackCanary.UnknownRequest.selector, 1));
        assertEq(canary.callbackCount(), 0);
    }

    function test_duplicateAuthenticatedCallbackIsIdempotent() public {
        CallbackResult[] memory callbacks = triggerAndReact(
            address(canary), abi.encodeCall(ReactiveCallbackCanary.requestCallback, ()), SEPOLIA_CHAIN_ID
        );
        assertCallbackSuccess(callbacks, 0);

        bytes memory payload = abi.encodeCall(ReactiveCallbackCanary.receiveCallback, (address(0), 1, block.number));
        (bool success,) = proxy.executeCallback(address(canary), payload, scheduler.CALLBACK_GAS_LIMIT(), rvmId);

        assertTrue(success);
        assertEq(canary.callbackCount(), 1);
    }
}
