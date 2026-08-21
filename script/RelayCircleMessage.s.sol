// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/Script.sol";

import { ICircleMessageReceiverV2 } from "../src/interfaces/ICircleMessageReceiverV2.sol";

/// @notice Relays one Circle-attested message into Unichain Sepolia MessageTransmitterV2.
contract RelayCircleMessage is Script {
    uint256 private constant UNICHAIN_SEPOLIA_CHAIN_ID = 1301;

    error UnexpectedChain(uint256 actual, uint256 expected);
    error CircleReceiveReturnedFalse();

    function run() external returns (bool success) {
        if (block.chainid != UNICHAIN_SEPOLIA_CHAIN_ID) {
            revert UnexpectedChain(block.chainid, UNICHAIN_SEPOLIA_CHAIN_ID);
        }

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        ICircleMessageReceiverV2 transmitter =
            ICircleMessageReceiverV2(vm.envAddress("UNICHAIN_CIRCLE_MESSAGE_TRANSMITTER"));
        bytes memory message = vm.envBytes("CIRCLE_MESSAGE");
        bytes memory attestation = vm.envBytes("CIRCLE_ATTESTATION");

        vm.startBroadcast(privateKey);
        success = transmitter.receiveMessage(message, attestation);
        vm.stopBroadcast();
        if (!success) revert CircleReceiveReturnedFalse();

        console2.log("Circle message relayed successfully");
    }
}
