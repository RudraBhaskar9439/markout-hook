// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/Script.sol";

import { ReactiveCallbackCanaryScheduler } from "../src/canary/ReactiveCallbackCanaryScheduler.sol";

/// @notice Deploys the canary event subscriber and callback scheduler on Reactive Lasna.
contract DeployReactiveCallbackCanaryScheduler is Script {
    address private constant LASNA_OMNI_SYSTEM_SERVICE = 0x8888888888888888888888888888888888888888;
    uint256 private constant LASNA_OMNI_CHAIN_ID = 5_318_007;

    error InvalidLasnaOmniService(address configured, address expected);

    function run() external returns (ReactiveCallbackCanaryScheduler scheduler) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address service = vm.envAddress("REACTIVE_SERVICE");
        uint256 originChainId = vm.envUint("ORIGIN_CHAIN_ID");
        uint256 destinationChainId = vm.envUint("DESTINATION_CHAIN_ID");
        address canary = vm.envAddress("REACTIVE_CANARY");

        if (block.chainid == LASNA_OMNI_CHAIN_ID && service != LASNA_OMNI_SYSTEM_SERVICE) {
            revert InvalidLasnaOmniService(service, LASNA_OMNI_SYSTEM_SERVICE);
        }

        vm.startBroadcast(privateKey);
        scheduler = new ReactiveCallbackCanaryScheduler(service, originChainId, destinationChainId, canary);
        vm.stopBroadcast();

        console2.log("Reactive callback canary scheduler", address(scheduler));
        console2.log("Origin chain", originChainId);
        console2.log("Destination chain", destinationChainId);
        console2.log("Canary", canary);
    }
}
