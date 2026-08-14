// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ReferenceObservation } from "../types/MarkoutTypes.sol";

/// @notice Minimal destination interface used by settlement adapters.
interface IMarkoutSettlementTarget {
    function settleTrade(bytes32 tradeId, ReferenceObservation calldata observation) external;
}
