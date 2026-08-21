// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Minimal Circle CCTP V2 generic-message sender interface used by MARKOUT.
interface ICircleMessageTransmitterV2 {
    function sendMessage(
        uint32 destinationDomain,
        bytes32 recipient,
        bytes32 destinationCaller,
        uint32 minFinalityThreshold,
        bytes calldata messageBody
    ) external;
}
