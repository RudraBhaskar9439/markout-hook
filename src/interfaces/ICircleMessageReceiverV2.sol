// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Minimal Circle CCTP V2 destination relay interface used by deployment scripts.
interface ICircleMessageReceiverV2 {
    function receiveMessage(bytes calldata message, bytes calldata attestation) external returns (bool success);
}
