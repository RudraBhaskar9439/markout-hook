// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Immutable configuration for a three-pool Uniswap v3 median reference sampler.
struct UniswapV3MedianSamplerConfig {
    address callbackSender;
    address reactiveIdentity;
    bytes32 marketId;
    address baseToken;
    uint8 baseDecimals;
    address quoteToken;
    uint8 quoteDecimals;
    address[3] pools;
    uint128 minimumLiquidity;
    uint16 maximumDispersionBps;
}
