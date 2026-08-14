// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { INormalizedReferencePriceFeed } from "../../src/interfaces/INormalizedReferencePriceFeed.sol";

contract MockNormalizedReferencePriceFeed is INormalizedReferencePriceFeed {
    function publish(bytes32 marketId, uint192 priceX18, uint64 observedAt, uint16 confidenceBps) external {
        emit NormalizedReferencePricePublished(marketId, priceX18, observedAt, confidenceBps);
    }
}
