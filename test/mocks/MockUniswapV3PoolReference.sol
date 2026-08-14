// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract MockUniswapV3PoolReference {
    address public immutable token0;
    address public immutable token1;

    uint160 public sqrtPriceX96;
    uint128 public liquidity;

    constructor(address token0_, address token1_, uint160 sqrtPriceX96_, uint128 liquidity_) {
        token0 = token0_;
        token1 = token1_;
        sqrtPriceX96 = sqrtPriceX96_;
        liquidity = liquidity_;
    }

    function setSqrtPriceX96(uint160 sqrtPriceX96_) external {
        sqrtPriceX96 = sqrtPriceX96_;
    }

    function setLiquidity(uint128 liquidity_) external {
        liquidity = liquidity_;
    }

    function slot0() external view returns (uint160, int24, uint16, uint16, uint16, uint8, bool) {
        return (sqrtPriceX96, 0, 0, 1, 1, 0, true);
    }
}
