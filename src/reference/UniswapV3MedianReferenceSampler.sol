// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { FullMath } from "@uniswap/v4-core/src/libraries/FullMath.sol";

import { AuthenticatedReactiveCallback } from "../base/AuthenticatedReactiveCallback.sol";
import { INormalizedReferencePriceFeed } from "../interfaces/INormalizedReferencePriceFeed.sol";
import { IReferencePriceSampler } from "../interfaces/IReferencePriceSampler.sol";
import { IUniswapV3PoolReference } from "../interfaces/IUniswapV3PoolReference.sol";
import { MarkoutParameters } from "../libraries/MarkoutParameters.sol";
import { PriceNormalization } from "../libraries/PriceNormalization.sol";
import { UniswapV3ReferencePricing } from "../libraries/UniswapV3ReferencePricing.sol";
import { UniswapV3MedianSamplerConfig } from "../types/ReferenceSamplerTypes.sol";

/// @title Uniswap v3 Median Reference Sampler
/// @notice Authenticated Reactive callback that samples three fee-tier pools and emits their median spot price.
/// @dev Cross-pool medianing limits one-pool manipulation but is not a substitute for a production TWAP or oracle.
contract UniswapV3MedianReferenceSampler is
    AuthenticatedReactiveCallback,
    INormalizedReferencePriceFeed,
    IReferencePriceSampler
{
    error ZeroMarketId();
    error ZeroToken();
    error IdenticalTokens(address token);
    error ZeroPool(uint256 index);
    error DuplicatePool(address pool);
    error UnexpectedPoolPair(address pool, address token0, address token1);
    error ZeroMinimumLiquidity();
    error InvalidMaximumDispersion(uint16 maximumDispersionBps);
    error InsufficientPoolLiquidity(address pool, uint128 actual, uint128 minimum);
    error ExcessivePoolDispersion(uint256 dispersionBps, uint16 maximumDispersionBps);
    error TimestampOutOfRange(uint256 timestamp);

    event ReferenceConstituentsSampled(
        bytes32 indexed marketId,
        uint192 lowPriceX18,
        uint192 medianPriceX18,
        uint192 highPriceX18,
        uint16 dispersionBps,
        uint64 observedAt
    );

    bytes32 public immutable marketId;
    address public immutable baseToken;
    uint8 public immutable baseDecimals;
    address public immutable quoteToken;
    uint8 public immutable quoteDecimals;
    uint128 public immutable minimumLiquidity;
    uint16 public immutable maximumDispersionBps;

    address[3] private _pools;

    constructor(UniswapV3MedianSamplerConfig memory config)
        AuthenticatedReactiveCallback(config.callbackSender, config.reactiveIdentity)
    {
        if (config.marketId == bytes32(0)) revert ZeroMarketId();
        if (config.baseToken == address(0) || config.quoteToken == address(0)) revert ZeroToken();
        if (config.baseToken == config.quoteToken) revert IdenticalTokens(config.baseToken);
        if (config.minimumLiquidity == 0) revert ZeroMinimumLiquidity();
        if (
            config.maximumDispersionBps == 0
                || config.maximumDispersionBps
                    > MarkoutParameters.BPS_DENOMINATOR - MarkoutParameters.MINIMUM_CONFIDENCE_BPS
        ) {
            revert InvalidMaximumDispersion(config.maximumDispersionBps);
        }
        PriceNormalization.validateDecimals(config.baseDecimals);
        PriceNormalization.validateDecimals(config.quoteDecimals);

        marketId = config.marketId;
        baseToken = config.baseToken;
        baseDecimals = config.baseDecimals;
        quoteToken = config.quoteToken;
        quoteDecimals = config.quoteDecimals;
        minimumLiquidity = config.minimumLiquidity;
        maximumDispersionBps = config.maximumDispersionBps;

        for (uint256 i = 0; i < config.pools.length; ++i) {
            address pool = config.pools[i];
            if (pool == address(0)) revert ZeroPool(i);
            for (uint256 j = 0; j < i; ++j) {
                if (config.pools[j] == pool) revert DuplicatePool(pool);
            }
            _validatePoolPair(pool, config.baseToken, config.quoteToken);
            _pools[i] = pool;
        }
    }

    function poolAt(uint256 index) external view returns (address) {
        return _pools[index];
    }

    /// @inheritdoc IReferencePriceSampler
    function sample(address suppliedReactiveIdentity)
        external
        onlyAuthenticatedReactiveCallback(suppliedReactiveIdentity)
    {
        uint192[3] memory prices;
        for (uint256 i = 0; i < prices.length; ++i) {
            prices[i] = _readPrice(_pools[i]);
        }
        _sort(prices);

        uint256 lowDeviation = uint256(prices[1]) - prices[0];
        uint256 highDeviation = uint256(prices[2]) - prices[1];
        uint256 maximumDeviation = lowDeviation > highDeviation ? lowDeviation : highDeviation;
        uint256 dispersionBps = FullMath.mulDiv(maximumDeviation, MarkoutParameters.BPS_DENOMINATOR, uint256(prices[1]));
        if (dispersionBps > maximumDispersionBps) {
            revert ExcessivePoolDispersion(dispersionBps, maximumDispersionBps);
        }

        uint64 observedAt = _currentTimestamp();
        // The maximum-dispersion validation proves this conversion and subtraction are bounded.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint16 confidenceBps = uint16(MarkoutParameters.BPS_DENOMINATOR - dispersionBps);
        emit NormalizedReferencePricePublished(marketId, prices[1], observedAt, confidenceBps);
        // `dispersionBps <= maximumDispersionBps <= 1_000` proves the conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        emit ReferenceConstituentsSampled(marketId, prices[0], prices[1], prices[2], uint16(dispersionBps), observedAt);
    }

    function _readPrice(address pool) private view returns (uint192) {
        IUniswapV3PoolReference pool_ = IUniswapV3PoolReference(pool);
        uint128 liquidity = pool_.liquidity();
        if (liquidity < minimumLiquidity) {
            revert InsufficientPoolLiquidity(pool, liquidity, minimumLiquidity);
        }
        (uint160 sqrtPriceX96,,,,,,) = pool_.slot0();
        return
            UniswapV3ReferencePricing.quotePerBaseX18(sqrtPriceX96, baseToken, baseDecimals, quoteToken, quoteDecimals);
    }

    function _validatePoolPair(address pool, address base, address quote) private view {
        IUniswapV3PoolReference pool_ = IUniswapV3PoolReference(pool);
        address token0 = pool_.token0();
        address token1 = pool_.token1();
        bool valid = (token0 == base && token1 == quote) || (token0 == quote && token1 == base);
        if (!valid) revert UnexpectedPoolPair(pool, token0, token1);
    }

    function _sort(uint192[3] memory prices) private pure {
        if (prices[0] > prices[1]) (prices[0], prices[1]) = (prices[1], prices[0]);
        if (prices[1] > prices[2]) (prices[1], prices[2]) = (prices[2], prices[1]);
        if (prices[0] > prices[1]) (prices[0], prices[1]) = (prices[1], prices[0]);
    }

    function _currentTimestamp() private view returns (uint64 timestamp) {
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp > type(uint64).max) revert TimestampOutOfRange(block.timestamp);
        // The bound above proves this conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64(block.timestamp);
    }
}
