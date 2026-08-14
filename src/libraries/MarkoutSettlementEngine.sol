// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {
    MarkoutCurve,
    MarkoutSettlement,
    ObservationRules,
    ReferenceObservation,
    TradeDirection
} from "../types/MarkoutTypes.sol";
import { MarkoutMath } from "./MarkoutMath.sol";
import { ReferenceObservationValidator } from "./ReferenceObservationValidator.sol";

/// @title MARKOUT Settlement Engine
/// @notice Pure orchestration boundary combining reference validation with economic settlement.
library MarkoutSettlementEngine {
    /// @notice Validates the supplied observation and deterministically allocates one escrowed surcharge.
    function evaluate(
        uint128 escrowedSurcharge,
        uint192 executionPriceX18,
        ReferenceObservation memory observation,
        TradeDirection direction,
        MarkoutCurve memory curve,
        ObservationRules memory rules
    ) internal pure returns (MarkoutSettlement memory settlement) {
        uint192 referencePriceX18 = ReferenceObservationValidator.validate(observation, rules);
        return MarkoutMath.settle(escrowedSurcharge, executionPriceX18, referencePriceX18, direction, curve);
    }
}
