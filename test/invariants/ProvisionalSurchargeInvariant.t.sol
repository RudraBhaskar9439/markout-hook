// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { StdInvariant } from "forge-std/StdInvariant.sol";

import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { IERC20Minimal } from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { TransientStateLibrary } from "@uniswap/v4-core/src/libraries/TransientStateLibrary.sol";
import { Currency, CurrencyLibrary } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";

import { FixedBpsProvisionalSurchargeHook } from "../../src/hooks/FixedBpsProvisionalSurchargeHook.sol";
import { SurchargeAccountingHandler } from "./handlers/SurchargeAccountingHandler.sol";

contract ProvisionalSurchargeInvariantTest is StdInvariant, Deployers {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using TransientStateLibrary for IPoolManager;

    FixedBpsProvisionalSurchargeHook private hook;
    SurchargeAccountingHandler private handler;
    PoolKey private surchargePoolKey;
    PoolId private surchargePoolId;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        uint160 flags = Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
        address hookAddress = address(flags | (uint160(0x4D49) << 144));
        deployCodeTo(
            "src/hooks/FixedBpsProvisionalSurchargeHook.sol:FixedBpsProvisionalSurchargeHook",
            abi.encode(manager, uint16(50)),
            hookAddress
        );
        hook = FixedBpsProvisionalSurchargeHook(payable(hookAddress));

        (surchargePoolKey, surchargePoolId) =
            initPoolAndAddLiquidity(currency0, currency1, IHooks(hookAddress), 3000, SQRT_PRICE_1_1);

        handler = new SurchargeAccountingHandler(swapRouter, surchargePoolKey);
        assertTrue(IERC20Minimal(Currency.unwrap(currency0)).transfer(address(handler), 1e24));
        assertTrue(IERC20Minimal(Currency.unwrap(currency1)).transfer(address(handler), 1e24));
        targetContract(address(handler));
    }

    function invariant_currency0AccountedSurchargeIsFullyBacked() public view {
        uint256 total = hook.totalAccruedSurcharge(Currency.unwrap(currency0));
        assertEq(total, currency0.balanceOf(address(hook)));
        assertEq(total, hook.poolAccruedSurcharge(PoolId.unwrap(surchargePoolId), Currency.unwrap(currency0)));
    }

    function invariant_currency1AccountedSurchargeIsFullyBacked() public view {
        uint256 total = hook.totalAccruedSurcharge(Currency.unwrap(currency1));
        assertEq(total, currency1.balanceOf(address(hook)));
        assertEq(total, hook.poolAccruedSurcharge(PoolId.unwrap(surchargePoolId), Currency.unwrap(currency1)));
    }

    function invariant_poolManagerHasNoOutstandingTransientDelta() public view {
        assertEq(manager.getNonzeroDeltaCount(), 0);
        assertEq(manager.currencyDelta(address(hook), currency0), 0);
        assertEq(manager.currencyDelta(address(hook), currency1), 0);
        assertEq(manager.currencyDelta(address(swapRouter), currency0), 0);
        assertEq(manager.currencyDelta(address(swapRouter), currency1), 0);
    }
}
