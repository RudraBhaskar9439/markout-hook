// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IMarkoutHook } from "../interfaces/IMarkoutHook.sol";
import { IMarkoutSettlementTarget } from "../interfaces/IMarkoutSettlementTarget.sol";
import { TradeRecord, TradeStatus } from "../types/MarkoutLifecycleTypes.sol";
import { ReferenceObservation } from "../types/MarkoutTypes.sol";

/// @title Reactive MARKOUT Settlement Adapter
/// @notice Authenticates Reactive callback-proxy delivery and makes terminal callback replay idempotent.
contract ReactiveMarkoutSettlementAdapter {
    error ZeroBinder();
    error ZeroCallbackSender();
    error ZeroReactiveIdentity();
    error ZeroTarget();
    error UnauthorizedBinder(address caller);
    error UnauthorizedCallbackSender(address caller);
    error UnauthorizedReactiveIdentity(address supplied, address expected);
    error TargetAlreadyBound(address target);
    error TargetNotBound();
    error UnknownTargetTrade(bytes32 tradeId);

    event TargetBound(address indexed target);
    event SettlementCallbackHandled(bytes32 indexed tradeId, bool forwarded, TradeStatus status);
    event ExpiryCallbackHandled(bytes32 indexed tradeId, bool forwarded, TradeStatus status);

    address public immutable binder;
    address public immutable callbackSender;
    address public immutable reactiveIdentity;
    IMarkoutHook public target;

    constructor(address binder_, address callbackSender_, address reactiveIdentity_) {
        if (binder_ == address(0)) revert ZeroBinder();
        if (callbackSender_ == address(0)) revert ZeroCallbackSender();
        if (reactiveIdentity_ == address(0)) revert ZeroReactiveIdentity();
        binder = binder_;
        callbackSender = callbackSender_;
        reactiveIdentity = reactiveIdentity_;
    }

    /// @notice Permanently binds the adapter to its destination hook.
    function bindTarget(IMarkoutHook target_) external {
        if (msg.sender != binder) revert UnauthorizedBinder(msg.sender);
        if (address(target_) == address(0)) revert ZeroTarget();
        if (address(target) != address(0)) revert TargetAlreadyBound(address(target));
        target = target_;
        emit TargetBound(address(target_));
    }

    /// @notice Forwards an authenticated observation unless the destination trade is already terminal.
    /// @dev The first argument is overwritten by Reactive Network's callback proxy.
    function settle(address suppliedReactiveIdentity, bytes32 tradeId, ReferenceObservation calldata observation)
        external
        returns (bool forwarded)
    {
        _authorize(suppliedReactiveIdentity);
        IMarkoutHook target_ = _requireTarget();
        TradeRecord memory trade = target_.getTrade(tradeId);
        if (trade.status == TradeStatus.None) revert UnknownTargetTrade(tradeId);
        if (trade.status == TradeStatus.Pending) {
            IMarkoutSettlementTarget(address(target_)).settleTrade(tradeId, observation);
            emit SettlementCallbackHandled(tradeId, true, TradeStatus.Settled);
            return true;
        }

        emit SettlementCallbackHandled(tradeId, false, trade.status);
    }

    /// @notice Executes the authenticated liveness fallback unless the destination trade is already terminal.
    /// @dev The first argument is overwritten by Reactive Network's callback proxy.
    function expire(address suppliedReactiveIdentity, bytes32 tradeId) external returns (bool forwarded) {
        _authorize(suppliedReactiveIdentity);
        IMarkoutHook target_ = _requireTarget();
        TradeRecord memory trade = target_.getTrade(tradeId);
        if (trade.status == TradeStatus.None) revert UnknownTargetTrade(tradeId);
        if (trade.status == TradeStatus.Pending) {
            target_.expireTrade(tradeId);
            emit ExpiryCallbackHandled(tradeId, true, TradeStatus.Expired);
            return true;
        }

        emit ExpiryCallbackHandled(tradeId, false, trade.status);
    }

    function _authorize(address suppliedReactiveIdentity) private view {
        if (msg.sender != callbackSender) revert UnauthorizedCallbackSender(msg.sender);
        if (suppliedReactiveIdentity != reactiveIdentity) {
            revert UnauthorizedReactiveIdentity(suppliedReactiveIdentity, reactiveIdentity);
        }
    }

    function _requireTarget() private view returns (IMarkoutHook target_) {
        target_ = target;
        if (address(target_) == address(0)) revert TargetNotBound();
    }
}
