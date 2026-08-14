// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/Script.sol";

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { LPFeeLibrary } from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";

import { IMarkoutHook } from "../src/interfaces/IMarkoutHook.sol";
import { SurchargeHookData } from "../src/libraries/SurchargeHookData.sol";
import { SurchargeAuthorization } from "../src/types/SurchargeTypes.sol";

/// @notice Executes one constrained testnet swap and prints the resulting MARKOUT trade identifier.
contract ExecuteMarkoutSwap is Script {
    using LPFeeLibrary for uint24;
    using SafeERC20 for IERC20;

    error CurrencyOrderInvalid(address currency0, address currency1);
    error NativeCurrencyUnsupported();
    error ValueDoesNotFitUint24(uint256 value);
    error ValueDoesNotFitUint128(uint256 value);
    error ValueDoesNotFitInt256(uint256 value);
    error TickSpacingOutOfRange(int256 tickSpacing);
    error ZeroAddress(string field);

    struct SwapConfig {
        uint256 privateKey;
        PoolSwapTest router;
        IMarkoutHook hook;
        address currency0;
        address currency1;
        PoolKey key;
        bool zeroForOne;
        bool exactInput;
        int256 amountSpecified;
        address rebateRecipient;
        uint128 maximumSurcharge;
    }

    function run() external returns (bytes32 tradeId) {
        SwapConfig memory config = _loadConfig();
        bytes memory hookData = SurchargeHookData.encode(
            SurchargeAuthorization({ rebateRecipient: config.rebateRecipient, maximumAmount: config.maximumSurcharge })
        );
        address inputCurrency = config.zeroForOne ? config.currency0 : config.currency1;

        vm.startBroadcast(config.privateKey);
        IERC20(inputCurrency).forceApprove(address(config.router), type(uint256).max);
        config.router
            .swap(
                config.key,
                SwapParams({
                    zeroForOne: config.zeroForOne,
                    amountSpecified: config.amountSpecified,
                    sqrtPriceLimitX96: config.zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
                }),
                PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
                hookData
            );
        vm.stopBroadcast();

        tradeId = config.hook.latestTradeId();
        console2.log("Rebate recipient", config.rebateRecipient);
        console2.log("Exact input", config.exactInput);
        console2.log("Zero for one", config.zeroForOne);
        console2.logBytes32(tradeId);
    }

    function _loadConfig() private view returns (SwapConfig memory config) {
        config.privateKey = vm.envUint("PRIVATE_KEY");
        config.router = PoolSwapTest(vm.envAddress("POOL_SWAP_ROUTER"));
        config.hook = IMarkoutHook(vm.envAddress("MARKOUT_HOOK"));
        if (address(config.router) == address(0)) revert ZeroAddress("POOL_SWAP_ROUTER");
        if (address(config.hook) == address(0)) revert ZeroAddress("MARKOUT_HOOK");

        config.currency0 = vm.envAddress("POOL_CURRENCY_0");
        config.currency1 = vm.envAddress("POOL_CURRENCY_1");
        if (config.currency0 == address(0) || config.currency1 == address(0)) revert NativeCurrencyUnsupported();
        if (config.currency0 >= config.currency1) revert CurrencyOrderInvalid(config.currency0, config.currency1);

        config.zeroForOne = vm.envBool("SWAP_ZERO_FOR_ONE");
        config.exactInput = vm.envOr("SWAP_EXACT_INPUT", true);
        int256 magnitude = _validatedPositiveInt256(vm.envUint("SWAP_AMOUNT"));
        config.amountSpecified = config.exactInput ? -magnitude : magnitude;
        config.rebateRecipient = vm.envOr("REBATE_RECIPIENT", vm.addr(config.privateKey));
        config.maximumSurcharge = _validatedUint128(vm.envOr("MAXIMUM_SURCHARGE", type(uint128).max));
        uint24 fee = _validatedUint24(vm.envUint("POOL_FEE"));
        fee.validate();
        config.key = PoolKey({
            currency0: Currency.wrap(config.currency0),
            currency1: Currency.wrap(config.currency1),
            fee: fee,
            tickSpacing: _validatedTickSpacing(vm.envInt("POOL_TICK_SPACING")),
            hooks: IHooks(address(config.hook))
        });
    }

    function _validatedUint24(uint256 value) private pure returns (uint24) {
        if (value > type(uint24).max) revert ValueDoesNotFitUint24(value);
        // The explicit validation above proves the conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint24(value);
    }

    function _validatedUint128(uint256 value) private pure returns (uint128) {
        if (value > type(uint128).max) revert ValueDoesNotFitUint128(value);
        // The explicit validation above proves the conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint128(value);
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
