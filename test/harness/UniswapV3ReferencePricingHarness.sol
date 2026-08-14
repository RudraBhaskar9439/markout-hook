// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { UniswapV3ReferencePricing } from "../../src/libraries/UniswapV3ReferencePricing.sol";

contract UniswapV3ReferencePricingHarness {
    function quotePerBaseX18(
        uint160 sqrtPriceX96,
        address baseToken,
        uint8 baseDecimals,
        address quoteToken,
        uint8 quoteDecimals
    ) external pure returns (uint192) {
        return UniswapV3ReferencePricing.quotePerBaseX18(
            sqrtPriceX96, baseToken, baseDecimals, quoteToken, quoteDecimals
        );
    }
}
