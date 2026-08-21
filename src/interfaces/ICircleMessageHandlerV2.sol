// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Minimal Circle CCTP V2 destination-recipient interface used by MARKOUT.
interface ICircleMessageHandlerV2 {
    function handleReceiveFinalizedMessage(
        uint32 sourceDomain,
        bytes32 sender,
        uint32 finalityThresholdExecuted,
        bytes calldata messageBody
    ) external returns (bool success);

    function handleReceiveUnfinalizedMessage(
        uint32 sourceDomain,
        bytes32 sender,
        uint32 finalityThresholdExecuted,
        bytes calldata messageBody
    ) external returns (bool success);
}
