// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ICircleMessageHandlerV2 } from "../../src/interfaces/ICircleMessageHandlerV2.sol";
import { ICircleMessageTransmitterV2 } from "../../src/interfaces/ICircleMessageTransmitterV2.sol";

contract MockCircleMessageTransmitterV2 is ICircleMessageTransmitterV2 {
    uint256 public sendCalls;
    address public lastSender;
    uint32 public lastDestinationDomain;
    bytes32 public lastRecipient;
    bytes32 public lastDestinationCaller;
    uint32 public lastMinimumFinalityThreshold;
    bytes public lastMessageBody;

    function sendMessage(
        uint32 destinationDomain,
        bytes32 recipient,
        bytes32 destinationCaller,
        uint32 minFinalityThreshold,
        bytes calldata messageBody
    ) external {
        ++sendCalls;
        lastSender = msg.sender;
        lastDestinationDomain = destinationDomain;
        lastRecipient = recipient;
        lastDestinationCaller = destinationCaller;
        lastMinimumFinalityThreshold = minFinalityThreshold;
        lastMessageBody = messageBody;
    }

    function relayFinalized(ICircleMessageHandlerV2 receiver, uint32 sourceDomain, uint32 finalityThreshold)
        external
        returns (bool success)
    {
        return receiver.handleReceiveFinalizedMessage(
            sourceDomain, bytes32(uint256(uint160(lastSender))), finalityThreshold, lastMessageBody
        );
    }

    function relayUnfinalized(ICircleMessageHandlerV2 receiver, uint32 sourceDomain, uint32 finalityThreshold)
        external
        returns (bool success)
    {
        return receiver.handleReceiveUnfinalizedMessage(
            sourceDomain, bytes32(uint256(uint160(lastSender))), finalityThreshold, lastMessageBody
        );
    }
}
