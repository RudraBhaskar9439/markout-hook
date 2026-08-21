// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ICircleMessageTransmitterV2 } from "../interfaces/ICircleMessageTransmitterV2.sol";
import { IMarkoutSettlementTarget } from "../interfaces/IMarkoutSettlementTarget.sol";
import { IPyth } from "../interfaces/IPyth.sol";

/// @notice Immutable source-chain configuration for Pyth-backed Circle observation publication.
struct CirclePublisherConfig {
    address binder;
    ICircleMessageTransmitterV2 messageTransmitter;
    IPyth pyth;
    bytes32 priceId;
    bytes32 marketId;
    uint32 destinationDomain;
    uint64 maximumPriceAge;
}

/// @notice Immutable destination-chain authentication configuration for Circle observation delivery.
struct CircleReceiverConfig {
    address messageTransmitter;
    uint32 sourceDomain;
    address sourcePublisher;
    bytes32 marketId;
    IMarkoutSettlementTarget settlementCoordinator;
}
