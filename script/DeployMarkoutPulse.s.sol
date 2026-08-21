// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/Script.sol";

import { MarkoutPulseReactive } from "../src/reactive/MarkoutPulseReactive.sol";
import { ReactivePulseConfig } from "../src/types/ReactivePulseTypes.sol";

/// @notice Deploys the optional stateless pulse on legacy Reactive Lasna.
contract DeployMarkoutPulse is Script {
    uint256 private constant LASNA_CHAIN_ID = 5_318_007;

    error UnexpectedChain(uint256 actual, uint256 expected);
    error ZeroDeploymentValue();

    function run() external returns (MarkoutPulseReactive pulse) {
        if (block.chainid != LASNA_CHAIN_ID) revert UnexpectedChain(block.chainid, LASNA_CHAIN_ID);

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        uint256 deploymentValue = vm.envOr("REACTIVE_DEPLOYMENT_VALUE", uint256(0));
        if (deploymentValue == 0) revert ZeroDeploymentValue();
        ReactivePulseConfig memory config = ReactivePulseConfig({
            originChainId: vm.envUint("PULSE_ORIGIN_CHAIN_ID"),
            destinationChainId: vm.envUint("PULSE_DESTINATION_CHAIN_ID"),
            sourcePublisher: vm.envAddress("CIRCLE_PUBLISHER"),
            destinationReceiver: vm.envAddress("REACTIVE_RECEIVER"),
            marketId: vm.envBytes32("MARKET_ID")
        });

        vm.startBroadcast(privateKey);
        pulse = new MarkoutPulseReactive{ value: deploymentValue }(config);
        vm.stopBroadcast();

        console2.log("MARKOUT stateless Reactive pulse", address(pulse));
        console2.log("Publisher", config.sourcePublisher);
        console2.log("Unichain receiver", config.destinationReceiver);
        console2.log("Initial lREACT funding", deploymentValue);
    }
}
