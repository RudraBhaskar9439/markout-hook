// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/Script.sol";

import { MarkoutReactive } from "../src/reactive/MarkoutReactive.sol";
import { MarkoutReactiveConfig } from "../src/types/MarkoutReactiveTypes.sol";

/// @notice Deploys the Reactive scheduler and registers its five narrow event subscriptions.
contract DeployMarkoutReactive is Script {
    function run() external returns (MarkoutReactive reactive) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        MarkoutReactiveConfig memory config = MarkoutReactiveConfig({
            service: vm.envAddress("REACTIVE_SERVICE"),
            reactiveChainId: vm.envUint("REACTIVE_CHAIN_ID"),
            originChainId: vm.envUint("ORIGIN_CHAIN_ID"),
            destinationChainId: vm.envUint("DESTINATION_CHAIN_ID"),
            referenceChainId: vm.envUint("REFERENCE_CHAIN_ID"),
            hook: vm.envAddress("MARKOUT_HOOK"),
            settlementAdapter: vm.envAddress("MARKOUT_SETTLEMENT_ADAPTER"),
            referenceFeed: vm.envAddress("REFERENCE_FEED"),
            marketId: vm.envBytes32("MARKET_ID"),
            cronTopic: vm.envUint("REACTIVE_CRON_TOPIC")
        });

        vm.startBroadcast(privateKey);
        reactive = new MarkoutReactive(config);
        vm.stopBroadcast();

        console2.log("MARKOUT Reactive scheduler", address(reactive));
        console2.log("Origin chain", config.originChainId);
        console2.log("Reference chain", config.referenceChainId);
        console2.log("Destination adapter", config.settlementAdapter);
    }
}
