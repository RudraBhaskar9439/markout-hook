// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { PriceNormalization } from "../../src/libraries/PriceNormalization.sol";
import { PriceOrientation } from "../../src/types/MarkoutTypes.sol";

contract PriceNormalizationHarness {
    function normalize(uint256 rawPrice, uint8 sourceDecimals, PriceOrientation orientation)
        external
        pure
        returns (uint192)
    {
        return PriceNormalization.normalize(rawPrice, sourceDecimals, orientation);
    }

    function fromAmounts(uint256 baseAmount, uint8 baseDecimals, uint256 quoteAmount, uint8 quoteDecimals)
        external
        pure
        returns (uint192)
    {
        return PriceNormalization.fromAmounts(baseAmount, baseDecimals, quoteAmount, quoteDecimals);
    }
}
