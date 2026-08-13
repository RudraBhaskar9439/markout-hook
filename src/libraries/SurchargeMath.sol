// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { FullMath } from "@uniswap/v4-core/src/libraries/FullMath.sol";

import { IProvisionalSurchargeHook } from "../interfaces/IProvisionalSurchargeHook.sol";

/// @title Surcharge Math
/// @notice Reusable bounded arithmetic for provisional hook surcharges.
library SurchargeMath {
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    /// @notice A rate cannot exceed 100% when expressed in basis points.
    error InvalidBasisPointRate(uint256 rateBps);

    /// @notice Calculates `basisAmount * rateBps / 10_000`, rounded down.
    /// @dev Rounding down guarantees the hook never collects more than the quoted fraction.
    function quoteBps(uint128 basisAmount, uint16 rateBps) internal pure returns (uint128 amount) {
        if (rateBps > BPS_DENOMINATOR) revert InvalidBasisPointRate(rateBps);
        amount = uint128(FullMath.mulDiv(basisAmount, rateBps, BPS_DENOMINATOR));
    }

    /// @notice Converts a surcharge amount to the signed type required by `afterSwap`.
    function toHookDelta(uint128 amount) internal pure returns (int128 delta) {
        if (amount > uint128(type(int128).max)) {
            revert IProvisionalSurchargeHook.SurchargeAmountOverflow(amount);
        }
        // The guard above proves the narrowing conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        delta = int128(amount);
    }
}
