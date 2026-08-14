// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { FullMath } from "@uniswap/v4-core/src/libraries/FullMath.sol";

import { PriceOrientation } from "../types/MarkoutTypes.sol";
import { MarkoutParameters } from "./MarkoutParameters.sol";

/// @title Price Normalization
/// @notice Converts source prices and executed token amounts to quote-per-base X18 prices.
library PriceNormalization {
    uint8 internal constant MAX_SUPPORTED_DECIMALS = 36;

    error ZeroPrice();
    error ZeroBaseAmount();
    error ZeroQuoteAmount();
    error UnsupportedDecimals(uint8 decimals);
    error PricePrecisionLoss();
    error NormalizedPriceOverflow(uint256 normalizedPrice);
    error ScalingOverflow();

    /// @notice Normalizes a source price to quote-token units per base token, scaled by 1e18.
    /// @dev Division and inversion round down. Values that would normalize to zero fail explicitly.
    function normalize(uint256 rawPrice, uint8 sourceDecimals, PriceOrientation orientation)
        internal
        pure
        returns (uint192 priceX18)
    {
        if (rawPrice == 0) revert ZeroPrice();
        _validateDecimals(sourceDecimals);

        uint256 directPriceX18;
        if (sourceDecimals < 18) {
            uint256 multiplier = _pow10(18 - sourceDecimals);
            if (rawPrice > type(uint256).max / multiplier) revert ScalingOverflow();
            directPriceX18 = rawPrice * multiplier;
        } else {
            directPriceX18 = rawPrice / _pow10(sourceDecimals - 18);
        }

        if (directPriceX18 == 0) revert PricePrecisionLoss();

        uint256 normalizedPrice = directPriceX18;
        if (orientation == PriceOrientation.BasePerQuote) {
            normalizedPrice = FullMath.mulDiv(MarkoutParameters.WAD, MarkoutParameters.WAD, directPriceX18);
            if (normalizedPrice == 0) revert PricePrecisionLoss();
        }

        if (normalizedPrice > type(uint192).max) revert NormalizedPriceOverflow(normalizedPrice);
        // The bounds check above proves the narrowing conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        priceX18 = uint192(normalizedPrice);
    }

    /// @notice Computes quote-per-base X18 from raw base and quote amounts and their token decimals.
    /// @dev The result rounds down, assigning any indivisible precision remainder no economic value.
    function fromAmounts(uint256 baseAmount, uint8 baseDecimals, uint256 quoteAmount, uint8 quoteDecimals)
        internal
        pure
        returns (uint192 priceX18)
    {
        if (baseAmount == 0) revert ZeroBaseAmount();
        if (quoteAmount == 0) revert ZeroQuoteAmount();
        _validateDecimals(baseDecimals);
        _validateDecimals(quoteDecimals);

        uint256 normalizedPrice;
        if (baseDecimals >= quoteDecimals) {
            uint256 decimalScale = _pow10(baseDecimals - quoteDecimals);
            uint256 numeratorScale = MarkoutParameters.WAD * decimalScale;
            normalizedPrice = FullMath.mulDiv(quoteAmount, numeratorScale, baseAmount);
        } else {
            uint256 decimalScale = _pow10(quoteDecimals - baseDecimals);
            uint256 rawRatioX18 = FullMath.mulDiv(quoteAmount, MarkoutParameters.WAD, baseAmount);
            normalizedPrice = rawRatioX18 / decimalScale;
        }

        if (normalizedPrice == 0) revert PricePrecisionLoss();
        if (normalizedPrice > type(uint192).max) revert NormalizedPriceOverflow(normalizedPrice);
        // The bounds check above proves the narrowing conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        priceX18 = uint192(normalizedPrice);
    }

    function _validateDecimals(uint8 decimals) private pure {
        if (decimals > MAX_SUPPORTED_DECIMALS) revert UnsupportedDecimals(decimals);
    }

    function _pow10(uint8 exponent) private pure returns (uint256 value) {
        value = 10 ** uint256(exponent);
    }
}
