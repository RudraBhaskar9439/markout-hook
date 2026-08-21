// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/Script.sol";

import { CirclePythObservationPublisher } from "../src/circle/CirclePythObservationPublisher.sol";
import { ReferenceObservation } from "../src/types/MarkoutTypes.sol";

/// @notice Publishes one matured trade observation using a signed Pyth update on Ethereum Sepolia.
contract PublishCircleObservation is Script {
    uint256 private constant ETHEREUM_SEPOLIA_CHAIN_ID = 11_155_111;

    error UnexpectedChain(uint256 actual, uint256 expected);

    function run() external returns (ReferenceObservation memory observation) {
        if (block.chainid != ETHEREUM_SEPOLIA_CHAIN_ID) {
            revert UnexpectedChain(block.chainid, ETHEREUM_SEPOLIA_CHAIN_ID);
        }

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        CirclePythObservationPublisher publisher = CirclePythObservationPublisher(vm.envAddress("CIRCLE_PUBLISHER"));
        bytes32 tradeId = vm.envBytes32("TRADE_ID");
        bytes[] memory updateData = new bytes[](1);
        updateData[0] = vm.envBytes("PYTH_UPDATE_DATA");
        uint256 updateFee = publisher.pyth().getUpdateFee(updateData);

        vm.startBroadcast(privateKey);
        observation = publisher.publish{ value: updateFee }(tradeId, updateData);
        vm.stopBroadcast();

        console2.logBytes32(tradeId);
        console2.log("Observation price X18", observation.priceX18);
        console2.log("Observation timestamp", observation.observedAt);
        console2.log("Observation confidence bps", observation.confidenceBps);
        console2.log("Pyth update fee", updateFee);
    }
}
