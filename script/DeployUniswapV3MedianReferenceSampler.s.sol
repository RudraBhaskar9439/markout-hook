// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/Script.sol";

import { UniswapV3MedianReferenceSampler } from "../src/reference/UniswapV3MedianReferenceSampler.sol";
import { UniswapV3MedianSamplerConfig } from "../src/types/ReferenceSamplerTypes.sol";

/// @notice Deploys MARKOUT's authenticated three-pool reference sampler on the destination chain.
contract DeployUniswapV3MedianReferenceSampler is Script {
    uint256 private constant MAX_SUPPORTED_DECIMALS = 36;
    uint256 private constant MAX_BPS = 10_000;

    error InvalidDecimals(uint256 decimals);
    error ValueDoesNotFitUint128(uint256 value);
    error InvalidBasisPoints(uint256 value);

    function run() external returns (UniswapV3MedianReferenceSampler sampler) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address[3] memory pools =
            [vm.envAddress("REFERENCE_POOL_0"), vm.envAddress("REFERENCE_POOL_1"), vm.envAddress("REFERENCE_POOL_2")];
        UniswapV3MedianSamplerConfig memory config = UniswapV3MedianSamplerConfig({
            callbackSender: vm.envAddress("REACTIVE_CALLBACK_PROXY"),
            reactiveIdentity: vm.envAddress("REACTIVE_IDENTITY"),
            marketId: vm.envBytes32("MARKET_ID"),
            baseToken: vm.envAddress("BASE_CURRENCY"),
            baseDecimals: _validatedDecimals(vm.envUint("BASE_DECIMALS")),
            quoteToken: vm.envAddress("QUOTE_CURRENCY"),
            quoteDecimals: _validatedDecimals(vm.envUint("QUOTE_DECIMALS")),
            pools: pools,
            minimumLiquidity: _validatedUint128(vm.envUint("REFERENCE_MINIMUM_LIQUIDITY")),
            maximumDispersionBps: _validatedBps(vm.envUint("REFERENCE_MAXIMUM_DISPERSION_BPS"))
        });

        vm.startBroadcast(privateKey);
        sampler = new UniswapV3MedianReferenceSampler(config);
        vm.stopBroadcast();

        console2.log("Reference sampler", address(sampler));
        console2.log("Authenticated callback proxy", config.callbackSender);
        console2.log("Authenticated Reactive identity", config.reactiveIdentity);
        console2.logBytes32(config.marketId);
    }

    function _validatedDecimals(uint256 decimals) private pure returns (uint8) {
        if (decimals > MAX_SUPPORTED_DECIMALS) revert InvalidDecimals(decimals);
        // The explicit validation above proves the conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint8(decimals);
    }

    function _validatedUint128(uint256 value) private pure returns (uint128) {
        if (value > type(uint128).max) revert ValueDoesNotFitUint128(value);
        // The explicit validation above proves the conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint128(value);
    }

    function _validatedBps(uint256 value) private pure returns (uint16) {
        if (value > MAX_BPS) revert InvalidBasisPoints(value);
        // The explicit validation above proves the conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint16(value);
    }
}
