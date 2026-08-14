// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Minimal read-only Uniswap v3 pool surface required by MARKOUT's reference sampler.
interface IUniswapV3PoolReference {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function liquidity() external view returns (uint128);

    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}
