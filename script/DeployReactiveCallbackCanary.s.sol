// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/Script.sol";

import { ReactiveCallbackCanary } from "../src/canary/ReactiveCallbackCanary.sol";

/// @notice Deploys the authenticated canary receiver on its origin/destination chain.
contract DeployReactiveCallbackCanary is Script {
    function run() external returns (ReactiveCallbackCanary canary) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address callbackProxy = vm.envAddress("REACTIVE_CALLBACK_PROXY");
        address reactiveIdentity = vm.envAddress("REACTIVE_IDENTITY");

        vm.startBroadcast(privateKey);
        canary = new ReactiveCallbackCanary(callbackProxy, reactiveIdentity);
        vm.stopBroadcast();

        console2.log("Reactive callback canary", address(canary));
        console2.log("Authenticated callback proxy", callbackProxy);
        console2.log("Authenticated Reactive identity", reactiveIdentity);
    }
}
