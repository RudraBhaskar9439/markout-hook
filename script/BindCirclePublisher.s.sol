// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/Script.sol";

import { CirclePythObservationPublisher } from "../src/circle/CirclePythObservationPublisher.sol";

/// @notice Permanently binds the Sepolia publisher to its Unichain Circle receiver.
contract BindCirclePublisher is Script {
    uint256 private constant ETHEREUM_SEPOLIA_CHAIN_ID = 11_155_111;

    error UnexpectedChain(uint256 actual, uint256 expected);
    error BinderMismatch(address configured, address signer);

    function run() external {
        if (block.chainid != ETHEREUM_SEPOLIA_CHAIN_ID) {
            revert UnexpectedChain(block.chainid, ETHEREUM_SEPOLIA_CHAIN_ID);
        }

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        CirclePythObservationPublisher publisher = CirclePythObservationPublisher(vm.envAddress("CIRCLE_PUBLISHER"));
        address receiver = vm.envAddress("CIRCLE_RECEIVER");
        address signer = vm.addr(privateKey);
        if (publisher.binder() != signer) revert BinderMismatch(publisher.binder(), signer);

        vm.startBroadcast(privateKey);
        publisher.bindDestination(receiver);
        vm.stopBroadcast();

        console2.log("Bound Circle publisher", address(publisher));
        console2.log("Unichain Circle receiver", receiver);
    }
}
