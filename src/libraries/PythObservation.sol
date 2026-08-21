// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { FullMath } from "@uniswap/v4-core/src/libraries/FullMath.sol";

import { PythPrice } from "../interfaces/IPyth.sol";
import { PriceOrientation } from "../types/MarkoutTypes.sol";
import { ReferenceObservation } from "../types/MarkoutTypes.sol";
import { MarkoutParameters } from "./MarkoutParameters.sol";
import { PriceNormalization } from "./PriceNormalization.sol";

/// @title Pyth Observation Normalization
/// @notice Converts a positive quote-per-base Pyth price into MARKOUT's normalized observation format.
library PythObservation {
    int32 internal constant MINIMUM_EXPONENT = -36;
    int32 internal constant MAXIMUM_EXPONENT = 18;

    error NonPositivePrice(int64 price);
    error UnsupportedExponent(int32 exponent);
    error PublishTimeOverflow(uint256 publishTime);

    function normalize(PythPrice memory pythPrice) internal pure returns (ReferenceObservation memory observation) {
        if (pythPrice.price <= 0) revert NonPositivePrice(pythPrice.price);
        if (pythPrice.expo < MINIMUM_EXPONENT || pythPrice.expo > MAXIMUM_EXPONENT) {
            revert UnsupportedExponent(pythPrice.expo);
        }
        if (pythPrice.publishTime > type(uint64).max) revert PublishTimeOverflow(pythPrice.publishTime);

        uint256 unsignedPrice = uint64(pythPrice.price);
        uint192 priceX18;
        if (pythPrice.expo <= 0) {
            // The exponent is bounded to [-36, 0], so negation and narrowing are lossless.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint8 sourceDecimals = uint8(uint32(-pythPrice.expo));
            priceX18 = PriceNormalization.normalize(unsignedPrice, sourceDecimals, PriceOrientation.QuotePerBase);
        } else {
            // The exponent is bounded to 18 and the raw price is uint64-sized.
            uint256 scaledPrice = unsignedPrice * (10 ** uint32(pythPrice.expo));
            priceX18 = PriceNormalization.normalize(scaledPrice, 0, PriceOrientation.QuotePerBase);
        }

        uint256 relativeUncertaintyBps =
            FullMath.mulDiv(uint256(pythPrice.conf), MarkoutParameters.BPS_DENOMINATOR, unsignedPrice);
        if (relativeUncertaintyBps > MarkoutParameters.BPS_DENOMINATOR) {
            relativeUncertaintyBps = MarkoutParameters.BPS_DENOMINATOR;
        }
        // The subtraction is bounded to [0, 10_000].
        // forge-lint: disable-next-line(unsafe-typecast)
        uint16 confidenceBps = uint16(MarkoutParameters.BPS_DENOMINATOR - relativeUncertaintyBps);

        observation = ReferenceObservation({
            priceX18: priceX18,
            // The overflow check above proves this conversion is lossless.
            // forge-lint: disable-next-line(unsafe-typecast)
            observedAt: uint64(pythPrice.publishTime),
            confidenceBps: confidenceBps
        });
    }
}
