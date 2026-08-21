// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Immutable configuration for the stateless MARKOUT Reactive pulse.
struct ReactivePulseConfig {
    uint256 originChainId;
    uint256 destinationChainId;
    address sourcePublisher;
    address destinationReceiver;
    bytes32 marketId;
}
