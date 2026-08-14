// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MarkoutSettlementEngine } from "../../src/libraries/MarkoutSettlementEngine.sol";
import {
    MarkoutCurve,
    MarkoutSettlement,
    ObservationRules,
    ReferenceObservation,
    TradeDirection
} from "../../src/types/MarkoutTypes.sol";

contract MarkoutSettlementEngineHarness {
    function evaluate(
        uint128 escrowedSurcharge,
        uint192 executionPriceX18,
        ReferenceObservation memory observation,
        TradeDirection direction,
        MarkoutCurve memory curve,
        ObservationRules memory rules
    ) external pure returns (MarkoutSettlement memory) {
        return MarkoutSettlementEngine.evaluate(
            escrowedSurcharge, executionPriceX18, observation, direction, curve, rules
        );
    }
}
