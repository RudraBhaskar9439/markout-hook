// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ReferenceObservation } from "../types/MarkoutTypes.sol";

/// @title MARKOUT Observation Message Codec
/// @notice Versioned wire format shared by Circle and Reactive observation transports.
library ObservationMessageCodec {
    uint8 internal constant VERSION = 1;

    function encode(bytes32 marketId, bytes32 tradeId, ReferenceObservation memory observation)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(VERSION, marketId, tradeId, observation);
    }

    function decode(bytes calldata messageBody)
        internal
        pure
        returns (uint8 version, bytes32 marketId, bytes32 tradeId, ReferenceObservation memory observation)
    {
        return abi.decode(messageBody, (uint8, bytes32, bytes32, ReferenceObservation));
    }
}
