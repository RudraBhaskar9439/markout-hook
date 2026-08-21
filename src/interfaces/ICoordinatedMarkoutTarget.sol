// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TradeRecord } from "../types/MarkoutLifecycleTypes.sol";
import { IMarkoutSettlementTarget } from "./IMarkoutSettlementTarget.sol";

/// @notice Narrow hook surface required by the immutable settlement coordinator.
interface ICoordinatedMarkoutTarget is IMarkoutSettlementTarget {
    function settlementAuthority() external view returns (address);

    function getTrade(bytes32 tradeId) external view returns (TradeRecord memory);
}
