// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { AbstractPayer } from "reactive-lib/abstract-base/AbstractPayer.sol";
import { IPayable } from "reactive-lib/interfaces/IPayable.sol";
import { IReactive } from "reactive-lib/interfaces/IReactive.sol";
import { ISubscriptionService } from "reactive-lib/interfaces/ISubscriptionService.sol";

import { ReactiveCallbackCanary } from "./ReactiveCallbackCanary.sol";

/// @title Reactive Callback Canary Scheduler
/// @notice Converts exact canary request events into callbacks on a configured destination chain.
contract ReactiveCallbackCanaryScheduler is AbstractPayer, IReactive {
    uint256 public constant REACTIVE_IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;
    uint64 public constant CALLBACK_GAS_LIMIT = 200_000;
    uint256 public constant CANARY_REQUESTED_TOPIC = uint256(keccak256("CanaryRequested(uint256,address,uint64)"));

    error ZeroService();
    error ZeroCanary();
    error ZeroChainId();
    error UnauthorizedService(address caller);

    event CanaryCallbackRequested(uint256 indexed requestId, uint256 indexed originBlockNumber);

    ISubscriptionService public immutable subscriptionService;
    uint256 public immutable originChainId;
    uint256 public immutable destinationChainId;
    address public immutable canary;

    constructor(address service, uint256 originChainId_, uint256 destinationChainId_, address canary_) {
        if (service == address(0)) revert ZeroService();
        if (canary_ == address(0)) revert ZeroCanary();
        if (originChainId_ == 0 || destinationChainId_ == 0) revert ZeroChainId();

        subscriptionService = ISubscriptionService(payable(service));
        originChainId = originChainId_;
        destinationChainId = destinationChainId_;
        canary = canary_;

        vendor = IPayable(payable(service));
        addAuthorizedSender(service);
        subscriptionService.subscribe(
            originChainId_, canary_, CANARY_REQUESTED_TOPIC, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
        );
    }

    modifier onlyService() {
        if (msg.sender != address(subscriptionService)) revert UnauthorizedService(msg.sender);
        _;
    }

    /// @inheritdoc IReactive
    function react(LogRecord calldata log) external onlyService {
        if (
            log.chain_id != originChainId || log._contract != canary || log.topic_0 != CANARY_REQUESTED_TOPIC
                || log.topic_1 == 0
        ) return;

        bytes memory payload =
            abi.encodeCall(ReactiveCallbackCanary.receiveCallback, (address(0), log.topic_1, log.block_number));
        emit Callback(destinationChainId, canary, CALLBACK_GAS_LIMIT, payload);
        emit CanaryCallbackRequested(log.topic_1, log.block_number);
    }
}
