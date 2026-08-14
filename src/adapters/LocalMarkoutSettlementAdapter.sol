// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IMarkoutSettlementTarget } from "../interfaces/IMarkoutSettlementTarget.sol";
import { ReferenceObservation } from "../types/MarkoutTypes.sol";

/// @title Local MARKOUT Settlement Adapter
/// @notice One-time-bound adapter used to test the authenticated settlement boundary before Reactive integration.
/// @dev This contract is deliberately replaced by the Reactive callback path in Phase 4.
contract LocalMarkoutSettlementAdapter {
    error ZeroOperator();
    error ZeroTarget();
    error UnauthorizedOperator(address caller);
    error TargetAlreadyBound(address target);
    error TargetNotBound();

    event TargetBound(address indexed target);

    address public immutable operator;
    IMarkoutSettlementTarget public target;

    constructor(address operator_) {
        if (operator_ == address(0)) revert ZeroOperator();
        operator = operator_;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert UnauthorizedOperator(msg.sender);
        _;
    }

    /// @notice Permanently binds the adapter to one destination hook.
    function bindTarget(IMarkoutSettlementTarget target_) external onlyOperator {
        if (address(target_) == address(0)) revert ZeroTarget();
        if (address(target) != address(0)) revert TargetAlreadyBound(address(target));
        target = target_;
        emit TargetBound(address(target_));
    }

    /// @notice Forwards one reference observation through the authenticated adapter boundary.
    function settle(bytes32 tradeId, ReferenceObservation calldata observation) external onlyOperator {
        IMarkoutSettlementTarget target_ = target;
        if (address(target_) == address(0)) revert TargetNotBound();
        target_.settleTrade(tradeId, observation);
    }
}
