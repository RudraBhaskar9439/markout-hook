// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { FullMath } from "@uniswap/v4-core/src/libraries/FullMath.sol";

import { PriceNormalization } from "./PriceNormalization.sol";

/// @title Uniswap v3 Reference Pricing
/// @notice Converts a v3 pool's current square-root price into quote-per-base X18 form.
library UniswapV3ReferencePricing {
    uint256 private constant Q128 = 1 << 128;
    uint256 private constant Q192 = 1 << 192;

    error ZeroSqrtPrice();
    error IdenticalTokens(address token);

    function quotePerBaseX18(
        uint160 sqrtPriceX96,
        address baseToken,
        uint8 baseDecimals,
        address quoteToken,
        uint8 quoteDecimals
    ) internal pure returns (uint192 priceX18) {
        if (sqrtPriceX96 == 0) revert ZeroSqrtPrice();
        if (baseToken == quoteToken) revert IdenticalTokens(baseToken);

        PriceNormalization.validateDecimals(baseDecimals);
        PriceNormalization.validateDecimals(quoteDecimals);
        uint256 baseUnit = 10 ** uint256(baseDecimals);
        uint256 quoteAmount;

        if (sqrtPriceX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtPriceX96) * sqrtPriceX96;
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX192, baseUnit, Q192)
                : FullMath.mulDiv(Q192, baseUnit, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX128, baseUnit, Q128)
                : FullMath.mulDiv(Q128, baseUnit, ratioX128);
        }

        return PriceNormalization.fromAmounts(baseUnit, baseDecimals, quoteAmount, quoteDecimals);
    }
}
