// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MarkoutMath } from "../../src/libraries/MarkoutMath.sol";
import { MarkoutParameters } from "../../src/libraries/MarkoutParameters.sol";
import { MarkoutCurve, MarkoutSettlement, TradeDirection } from "../../src/types/MarkoutTypes.sol";

contract MarkoutMathHarness {
    function calculateMarkoutWad(uint192 executionPriceX18, uint192 referencePriceX18, TradeDirection direction)
        external
        pure
        returns (int256)
    {
        return MarkoutMath.calculateMarkoutWad(executionPriceX18, referencePriceX18, direction);
    }

    function retentionBps(int256 markoutWad, MarkoutCurve memory curve) external pure returns (uint16) {
        return MarkoutMath.retentionBps(markoutWad, curve);
    }

    function defaultRetentionBps(int256 markoutWad) external pure returns (uint16) {
        return MarkoutMath.retentionBps(markoutWad, MarkoutParameters.defaultCurve());
    }

    function settle(
        uint128 escrowedSurcharge,
        uint192 executionPriceX18,
        uint192 referencePriceX18,
        TradeDirection direction,
        MarkoutCurve memory curve
    ) external pure returns (MarkoutSettlement memory) {
        return MarkoutMath.settle(escrowedSurcharge, executionPriceX18, referencePriceX18, direction, curve);
    }

    function settleDefault(
        uint128 escrowedSurcharge,
        uint192 executionPriceX18,
        uint192 referencePriceX18,
        TradeDirection direction
    ) external pure returns (MarkoutSettlement memory) {
        return MarkoutMath.settle(
            escrowedSurcharge, executionPriceX18, referencePriceX18, direction, MarkoutParameters.defaultCurve()
        );
    }

    function defaultCurve() external pure returns (MarkoutCurve memory) {
        return MarkoutParameters.defaultCurve();
    }
}
