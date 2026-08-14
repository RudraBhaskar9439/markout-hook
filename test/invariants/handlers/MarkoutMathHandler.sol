// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MarkoutMath } from "../../../src/libraries/MarkoutMath.sol";
import { MarkoutParameters } from "../../../src/libraries/MarkoutParameters.sol";
import { MarkoutSettlement, TradeDirection } from "../../../src/types/MarkoutTypes.sol";

contract MarkoutMathHandler {
    uint192 private constant MIN_PRICE = 1e18;
    uint192 private constant PRICE_RANGE = 1e24 - MIN_PRICE;

    bool public boundsViolated;
    bool public conservationViolated;
    bool public retentionViolated;
    uint256 public calls;

    function settle(uint128 escrowedSurcharge, uint192 priceSeed, uint16 movementSeed, bool sellBase, bool moveUp)
        external
    {
        uint192 executionPrice = MIN_PRICE + (priceSeed % PRICE_RANGE);
        uint16 movementBps = movementSeed % 101;
        uint192 priceMovement = uint192((uint256(executionPrice) * movementBps) / 10_000);
        uint192 referencePrice = moveUp ? executionPrice + priceMovement : executionPrice - priceMovement;
        TradeDirection direction = sellBase ? TradeDirection.SellBase : TradeDirection.BuyBase;

        MarkoutSettlement memory result = MarkoutMath.settle(
            escrowedSurcharge, executionPrice, referencePrice, direction, MarkoutParameters.defaultCurve()
        );

        if (result.retainedSurcharge > escrowedSurcharge || result.rebate > escrowedSurcharge) {
            boundsViolated = true;
        }
        if (uint256(result.retainedSurcharge) + result.rebate != escrowedSurcharge) {
            conservationViolated = true;
        }
        if (result.retentionBps > MarkoutParameters.BPS_DENOMINATOR) {
            retentionViolated = true;
        }
        ++calls;
    }
}
