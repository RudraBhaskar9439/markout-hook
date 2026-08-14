// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Event boundary consumed by MARKOUT's Reactive contract after source-specific normalization.
interface INormalizedReferencePriceFeed {
    event NormalizedReferencePricePublished(
        bytes32 indexed marketId, uint192 priceX18, uint64 observedAt, uint16 confidenceBps
    );
}
