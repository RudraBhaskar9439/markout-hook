// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { FullMath } from "@uniswap/v4-core/src/libraries/FullMath.sol";

import { MarkoutCurve, MarkoutSettlement, TradeDirection } from "../types/MarkoutTypes.sol";
import { MarkoutParameters } from "./MarkoutParameters.sol";

/// @title MARKOUT Math
/// @notice Pure directional markout and provisional-surcharge settlement mathematics.
library MarkoutMath {
    error ZeroExecutionPrice();
    error ZeroReferencePrice();
    error MarkoutOverflow(uint256 magnitude);
    error ZeroFavorableCutoff();
    error ZeroAdverseCutoff();
    error InvalidMinimumRetention(uint16 minimumRetentionBps);
    error InvalidNeutralRetention(uint16 minimumRetentionBps, uint16 neutralRetentionBps);

    /// @notice Computes signed directional markout in WAD precision.
    /// @dev Positive values indicate that the market moved in the trader's direction.
    function calculateMarkoutWad(uint192 executionPriceX18, uint192 referencePriceX18, TradeDirection direction)
        internal
        pure
        returns (int256 markoutWad)
    {
        if (executionPriceX18 == 0) revert ZeroExecutionPrice();
        if (referencePriceX18 == 0) revert ZeroReferencePrice();

        bool traderFavored;
        uint256 difference;

        if (direction == TradeDirection.BuyBase) {
            traderFavored = referencePriceX18 >= executionPriceX18;
            difference = traderFavored
                ? uint256(referencePriceX18) - executionPriceX18
                : uint256(executionPriceX18) - referencePriceX18;
        } else {
            traderFavored = referencePriceX18 <= executionPriceX18;
            difference = traderFavored
                ? uint256(executionPriceX18) - referencePriceX18
                : uint256(referencePriceX18) - executionPriceX18;
        }

        if (difference == 0) return 0;
        uint256 magnitude = FullMath.mulDiv(difference, MarkoutParameters.WAD, executionPriceX18);
        if (magnitude > uint256(type(int256).max)) revert MarkoutOverflow(magnitude);

        // The explicit bound above proves this conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 signedMagnitude = int256(magnitude);
        markoutWad = traderFavored ? signedMagnitude : -signedMagnitude;
    }

    /// @notice Converts signed markout into the retained share of provisional surcharge.
    /// @dev Both interpolation segments round down. This assigns indivisible settlement dust to the trader rebate.
    function retentionBps(int256 markoutWad, MarkoutCurve memory curve) internal pure returns (uint16 retainedBps) {
        validateCurve(curve);

        int256 favorableBoundary = -int256(uint256(curve.favorableCutoffWad));
        int256 adverseBoundary = int256(uint256(curve.adverseCutoffWad));

        if (markoutWad <= favorableBoundary) return curve.minimumRetentionBps;
        if (markoutWad >= adverseBoundary) return MarkoutParameters.BPS_DENOMINATOR;

        if (markoutWad < 0) {
            // This branch and the favorable-boundary check prove the expression is positive.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint256 progress = uint256(markoutWad - favorableBoundary);
            uint256 retentionRange = curve.neutralRetentionBps - curve.minimumRetentionBps;
            uint256 interpolated = FullMath.mulDiv(retentionRange, progress, curve.favorableCutoffWad);
            // Validated endpoints and bounded interpolation prove the result is at most 10,000.
            // forge-lint: disable-next-line(unsafe-typecast)
            return uint16(uint256(curve.minimumRetentionBps) + interpolated);
        }

        // This branch proves markout is non-negative and the adverse-boundary check bounds it.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 adverseProgress = uint256(markoutWad);
        uint256 adverseRetentionRange = MarkoutParameters.BPS_DENOMINATOR - curve.neutralRetentionBps;
        uint256 adverseInterpolated = FullMath.mulDiv(adverseRetentionRange, adverseProgress, curve.adverseCutoffWad);
        // Validated endpoints and bounded interpolation prove the result is at most 10,000.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint16(uint256(curve.neutralRetentionBps) + adverseInterpolated);
    }

    /// @notice Settles an escrowed surcharge using execution and validated reference prices.
    function settle(
        uint128 escrowedSurcharge,
        uint192 executionPriceX18,
        uint192 referencePriceX18,
        TradeDirection direction,
        MarkoutCurve memory curve
    ) internal pure returns (MarkoutSettlement memory settlement) {
        int256 markoutWad = calculateMarkoutWad(executionPriceX18, referencePriceX18, direction);
        uint16 retainedBps = retentionBps(markoutWad, curve);
        uint128 retained = uint128(FullMath.mulDiv(escrowedSurcharge, retainedBps, MarkoutParameters.BPS_DENOMINATOR));

        settlement = MarkoutSettlement({
            markoutWad: markoutWad,
            retentionBps: retainedBps,
            retainedSurcharge: retained,
            rebate: escrowedSurcharge - retained
        });
    }

    /// @notice Validates curve ordering and basis-point bounds.
    function validateCurve(MarkoutCurve memory curve) internal pure {
        if (curve.favorableCutoffWad == 0) revert ZeroFavorableCutoff();
        if (curve.adverseCutoffWad == 0) revert ZeroAdverseCutoff();
        if (curve.minimumRetentionBps > MarkoutParameters.BPS_DENOMINATOR) {
            revert InvalidMinimumRetention(curve.minimumRetentionBps);
        }
        if (
            curve.neutralRetentionBps < curve.minimumRetentionBps
                || curve.neutralRetentionBps > MarkoutParameters.BPS_DENOMINATOR
        ) {
            revert InvalidNeutralRetention(curve.minimumRetentionBps, curve.neutralRetentionBps);
        }
    }
}
