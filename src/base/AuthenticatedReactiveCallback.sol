// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { AbstractPayer } from "reactive-lib/abstract-base/AbstractPayer.sol";
import { IPayable } from "reactive-lib/interfaces/IPayable.sol";

/// @title Authenticated Reactive Callback
/// @notice Shared callback-proxy authentication, RVM identity validation, and destination gas payment support.
abstract contract AuthenticatedReactiveCallback is AbstractPayer {
    error ZeroCallbackSender();
    error ZeroReactiveIdentity();
    error UnauthorizedCallbackSender(address caller);
    error UnauthorizedReactiveIdentity(address supplied, address expected);

    address public immutable callbackSender;
    address public immutable reactiveIdentity;

    constructor(address callbackSender_, address reactiveIdentity_) {
        if (callbackSender_ == address(0)) revert ZeroCallbackSender();
        if (reactiveIdentity_ == address(0)) revert ZeroReactiveIdentity();
        callbackSender = callbackSender_;
        reactiveIdentity = reactiveIdentity_;

        vendor = IPayable(payable(callbackSender_));
        addAuthorizedSender(callbackSender_);
    }

    modifier onlyAuthenticatedReactiveCallback(address suppliedReactiveIdentity) {
        if (msg.sender != callbackSender) revert UnauthorizedCallbackSender(msg.sender);
        if (suppliedReactiveIdentity != reactiveIdentity) {
            revert UnauthorizedReactiveIdentity(suppliedReactiveIdentity, reactiveIdentity);
        }
        _;
    }
}
