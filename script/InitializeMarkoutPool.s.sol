// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/Script.sol";

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { LPFeeLibrary } from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { PoolModifyLiquidityTest } from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { ModifyLiquidityParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";

import { IUniswapV3PoolReference } from "../src/interfaces/IUniswapV3PoolReference.sol";

/// @notice Initializes the testnet MARKOUT pool and supplies a full-range bootstrap position.
/// @dev The official v4 testnet liquidity router settles ERC-20 deltas directly from the broadcaster.
contract InitializeMarkoutPool is Script {
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for IERC20;

    error ZeroAddress(string field);
    error CurrencyOrderInvalid(address currency0, address currency1);
    error NativeCurrencyUnsupported();
    error ValueDoesNotFitUint24(uint256 value);
    error ValueDoesNotFitUint160(uint256 value);
    error ValueDoesNotFitInt256(uint256 value);
    error TickSpacingOutOfRange(int256 tickSpacing);
    error ReferencePoolPairMismatch(address pool, address token0, address token1);

    function run() external returns (PoolId poolId) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        IPoolManager manager = IPoolManager(vm.envAddress("POOL_MANAGER"));
        PoolModifyLiquidityTest router = PoolModifyLiquidityTest(vm.envAddress("POOL_MODIFY_LIQUIDITY_ROUTER"));
        address currency0Address = vm.envAddress("POOL_CURRENCY_0");
        address currency1Address = vm.envAddress("POOL_CURRENCY_1");
        IHooks hook = IHooks(vm.envAddress("MARKOUT_HOOK"));
        _validateAddresses(address(manager), address(router), address(hook));
        if (currency0Address == address(0) || currency1Address == address(0)) revert NativeCurrencyUnsupported();
        if (currency0Address >= currency1Address) revert CurrencyOrderInvalid(currency0Address, currency1Address);

        uint24 fee = _validatedUint24(vm.envUint("POOL_FEE"));
        fee.validate();
        int24 tickSpacing = _validatedTickSpacing(vm.envInt("POOL_TICK_SPACING"));
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(currency0Address),
            currency1: Currency.wrap(currency1Address),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: hook
        });
        uint160 sqrtPriceX96 = _initialSqrtPrice(currency0Address, currency1Address);
        int256 liquidityDelta = _validatedPositiveInt256(vm.envUint("POOL_BOOTSTRAP_LIQUIDITY"));
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TickMath.minUsableTick(tickSpacing),
            tickUpper: TickMath.maxUsableTick(tickSpacing),
            liquidityDelta: liquidityDelta,
            salt: vm.envOr("POOL_POSITION_SALT", bytes32(0))
        });

        vm.startBroadcast(privateKey);
        manager.initialize(key, sqrtPriceX96);
        IERC20(currency0Address).forceApprove(address(router), type(uint256).max);
        IERC20(currency1Address).forceApprove(address(router), type(uint256).max);
        router.modifyLiquidity(key, params, bytes(""));
        vm.stopBroadcast();

        poolId = key.toId();
        console2.log("MARKOUT hook", address(hook));
        console2.log("Initial sqrtPriceX96", sqrtPriceX96);
        console2.logBytes32(PoolId.unwrap(poolId));
    }

    function _initialSqrtPrice(address currency0, address currency1) private view returns (uint160 sqrtPriceX96) {
        uint256 configuredPrice = vm.envOr("POOL_INITIAL_SQRT_PRICE_X96", uint256(0));
        if (configuredPrice != 0) return _validatedUint160(configuredPrice);

        address referencePool = vm.envAddress("POOL_INITIAL_PRICE_REFERENCE");
        IUniswapV3PoolReference source = IUniswapV3PoolReference(referencePool);
        address token0 = source.token0();
        address token1 = source.token1();
        if (token0 != currency0 || token1 != currency1) {
            revert ReferencePoolPairMismatch(referencePool, token0, token1);
        }
        (sqrtPriceX96,,,,,,) = source.slot0();
        TickMath.getTickAtSqrtPrice(sqrtPriceX96);
    }

    function _validateAddresses(address manager, address router, address hook) private pure {
        if (manager == address(0)) revert ZeroAddress("POOL_MANAGER");
        if (router == address(0)) revert ZeroAddress("POOL_MODIFY_LIQUIDITY_ROUTER");
        if (hook == address(0)) revert ZeroAddress("MARKOUT_HOOK");
    }

    function _validatedUint24(uint256 value) private pure returns (uint24) {
        if (value > type(uint24).max) revert ValueDoesNotFitUint24(value);
        // The explicit validation above proves the conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint24(value);
    }

    function _validatedUint160(uint256 value) private pure returns (uint160) {
        if (value > type(uint160).max) revert ValueDoesNotFitUint160(value);
        // The explicit validation above proves the conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint160(value);
    }

    function _validatedPositiveInt256(uint256 value) private pure returns (int256) {
        if (value == 0 || value > uint256(type(int256).max)) revert ValueDoesNotFitInt256(value);
        // The explicit validation above proves the conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return int256(value);
    }

    function _validatedTickSpacing(int256 tickSpacing) private pure returns (int24) {
        if (tickSpacing < 1 || tickSpacing > type(int16).max) revert TickSpacingOutOfRange(tickSpacing);
        // The explicit validation above proves the conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return int24(tickSpacing);
    }
}
