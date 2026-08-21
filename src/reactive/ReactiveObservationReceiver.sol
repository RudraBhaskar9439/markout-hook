// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { AuthenticatedReactiveCallback } from "../base/AuthenticatedReactiveCallback.sol";
import { IMarkoutSettlementTarget } from "../interfaces/IMarkoutSettlementTarget.sol";
import { ReferenceObservation } from "../types/MarkoutTypes.sol";

/// @title MARKOUT Reactive Observation Receiver
/// @notice Authenticates one stateless Reactive callback before forwarding to the shared coordinator.
contract ReactiveObservationReceiver is AuthenticatedReactiveCallback {
    error ZeroMarketId();
    error ZeroSettlementCoordinator();
    error SettlementCoordinatorHasNoCode(address settlementCoordinator);
    error UnexpectedMarket(bytes32 supplied, bytes32 expected);
    error ZeroTradeId();

    event ReactiveObservationReceived(
        bytes32 indexed tradeId, bytes32 indexed marketId, uint192 priceX18, uint64 observedAt, uint16 confidenceBps
    );

    bytes32 public immutable marketId;
    IMarkoutSettlementTarget public immutable settlementCoordinator;

    constructor(
        address callbackSender_,
        address reactiveIdentity_,
        bytes32 marketId_,
        IMarkoutSettlementTarget settlementCoordinator_
    ) AuthenticatedReactiveCallback(callbackSender_, reactiveIdentity_) {
        if (marketId_ == bytes32(0)) revert ZeroMarketId();
        if (address(settlementCoordinator_) == address(0)) revert ZeroSettlementCoordinator();
        if (address(settlementCoordinator_).code.length == 0) {
            revert SettlementCoordinatorHasNoCode(address(settlementCoordinator_));
        }
        marketId = marketId_;
        settlementCoordinator = settlementCoordinator_;
    }

    /// @notice Forwards the publisher's exact normalized observation to the shared coordinator.
    /// @dev Reactive Network's callback proxy overwrites the first argument with the RVM deployer identity.
    function receiveObservation(
        address suppliedReactiveIdentity,
        bytes32 suppliedMarketId,
        bytes32 tradeId,
        ReferenceObservation calldata observation
    ) external onlyAuthenticatedReactiveCallback(suppliedReactiveIdentity) returns (bool accepted) {
        if (suppliedMarketId != marketId) revert UnexpectedMarket(suppliedMarketId, marketId);
        if (tradeId == bytes32(0)) revert ZeroTradeId();

        settlementCoordinator.settleTrade(tradeId, observation);
        emit ReactiveObservationReceived(
            tradeId, suppliedMarketId, observation.priceX18, observation.observedAt, observation.confidenceBps
        );
        return true;
    }
}
