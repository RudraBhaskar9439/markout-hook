// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ICoordinatedMarkoutTarget } from "../interfaces/ICoordinatedMarkoutTarget.sol";
import { IMarkoutSettlementTarget } from "../interfaces/IMarkoutSettlementTarget.sol";
import { TradeRecord, TradeStatus } from "../types/MarkoutLifecycleTypes.sol";
import { ReferenceObservation } from "../types/MarkoutTypes.sol";

/// @title MARKOUT Settlement Coordinator
/// @notice Immutable, at-least-once boundary shared by the Reactive and Circle observation transports.
/// @dev The deployer binds the complete topology once. No administrative surface remains after binding.
contract SettlementCoordinator is IMarkoutSettlementTarget {
    uint256 public constant MAX_SOURCES = 3;

    error ZeroBinder();
    error UnauthorizedBinder(address caller);
    error TopologyAlreadyBound(address target);
    error TopologyNotBound();
    error ZeroTarget();
    error TargetHasNoCode(address target);
    error TargetAuthorityMismatch(address actual, address expected);
    error EmptySourceSet();
    error TooManySources(uint256 supplied, uint256 maximum);
    error ZeroSource(uint256 index);
    error SourceHasNoCode(address source);
    error DuplicateSource(address source);
    error UnauthorizedSource(address source);
    error UnknownTargetTrade(bytes32 tradeId);

    event TopologyBound(address indexed target, address[] sources);
    event ObservationDeliveryHandled(
        address indexed source, bytes32 indexed tradeId, bool forwarded, TradeStatus previousStatus
    );

    address public immutable binder;
    ICoordinatedMarkoutTarget public target;

    mapping(address source => bool authorized) public isSource;
    address[] private _sources;

    constructor(address binder_) {
        if (binder_ == address(0)) revert ZeroBinder();
        binder = binder_;
    }

    /// @notice Permanently binds the hook and complete transport set in one transaction.
    function bindTopology(ICoordinatedMarkoutTarget target_, address[] calldata sources_) external {
        if (msg.sender != binder) revert UnauthorizedBinder(msg.sender);
        if (address(target) != address(0)) revert TopologyAlreadyBound(address(target));
        if (address(target_) == address(0)) revert ZeroTarget();
        if (address(target_).code.length == 0) revert TargetHasNoCode(address(target_));

        uint256 length = sources_.length;
        if (length == 0) revert EmptySourceSet();
        if (length > MAX_SOURCES) revert TooManySources(length, MAX_SOURCES);

        address actualAuthority = target_.settlementAuthority();
        if (actualAuthority != address(this)) {
            revert TargetAuthorityMismatch(actualAuthority, address(this));
        }

        for (uint256 i = 0; i < length; ++i) {
            address source = sources_[i];
            if (source == address(0)) revert ZeroSource(i);
            if (source.code.length == 0) revert SourceHasNoCode(source);
            if (isSource[source]) revert DuplicateSource(source);
            isSource[source] = true;
            _sources.push(source);
        }

        target = target_;
        emit TopologyBound(address(target_), sources_);
    }

    function sourceCount() external view returns (uint256) {
        return _sources.length;
    }

    function sourceAt(uint256 index) external view returns (address) {
        return _sources[index];
    }

    /// @inheritdoc IMarkoutSettlementTarget
    function settleTrade(bytes32 tradeId, ReferenceObservation calldata observation) external {
        if (!isSource[msg.sender]) revert UnauthorizedSource(msg.sender);

        ICoordinatedMarkoutTarget target_ = target;
        if (address(target_) == address(0)) revert TopologyNotBound();

        TradeRecord memory trade = target_.getTrade(tradeId);
        if (trade.status == TradeStatus.None) revert UnknownTargetTrade(tradeId);
        if (trade.status != TradeStatus.Pending) {
            emit ObservationDeliveryHandled(msg.sender, tradeId, false, trade.status);
            return;
        }

        target_.settleTrade(tradeId, observation);
        emit ObservationDeliveryHandled(msg.sender, tradeId, true, TradeStatus.Pending);
    }
}
