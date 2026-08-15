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

import { MarkoutHook } from "../../src/hooks/MarkoutHook.sol";
import { MarkoutLifecycleHandler } from "./handlers/MarkoutLifecycleHandler.sol";

contract MarkoutLifecycleInvariantTest is StdInvariant, Deployers {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using TransientStateLibrary for IPoolManager;

    address private constant SETTLEMENT_AUTHORITY = address(0xA11CE);

    MarkoutHook private hook;
    MarkoutLifecycleHandler private handler;
    PoolKey private markoutPoolKey;
    PoolId private markoutPoolId;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        uint160 flags = Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
        address hookAddress = address(flags | (uint160(0x4D59) << 144));
        deployCodeTo(
            "src/hooks/MarkoutHook.sol:MarkoutHook",
            abi.encode(
                manager,
                uint16(50),
                SETTLEMENT_AUTHORITY,
                Currency.unwrap(currency0),
                uint8(18),
                Currency.unwrap(currency1),
                uint8(18)
            ),
            hookAddress
        );
        hook = MarkoutHook(payable(hookAddress));
        (markoutPoolKey, markoutPoolId) =
            initPoolAndAddLiquidity(currency0, currency1, IHooks(hookAddress), 3000, SQRT_PRICE_1_1);

        handler = new MarkoutLifecycleHandler(hook, swapRouter, markoutPoolKey, SETTLEMENT_AUTHORITY);
        assertTrue(IERC20Minimal(Currency.unwrap(currency0)).transfer(address(handler), 1e24));
        assertTrue(IERC20Minimal(Currency.unwrap(currency1)).transfer(address(handler), 1e24));
        targetContract(address(handler));
    }

    function invariant_currency0LiveAccountingIsFullyBacked() public view {
        _assertCurrencyAccounting(Currency.unwrap(currency0));
    }

    function invariant_currency1LiveAccountingIsFullyBacked() public view {
        _assertCurrencyAccounting(Currency.unwrap(currency1));
    }

    function invariant_lifetimeAccrualEqualsLiveAccountingPlusClaims() public view {
        address currency0Address = Currency.unwrap(currency0);
        address currency1Address = Currency.unwrap(currency1);
        assertEq(
            hook.totalAccruedSurcharge(currency0Address),
            hook.accountedBalance(currency0Address) + handler.claimed(currency0Address)
        );
        assertEq(
            hook.totalAccruedSurcharge(currency1Address),
            hook.accountedBalance(currency1Address) + handler.claimed(currency1Address)
        );
    }

    function invariant_terminalAllocationsConserveEveryCheckedEscrow() public view {
        assertEq(handler.conservationViolations(), 0);
    }

    function invariant_adversarialCallsCannotMutateLifecycleAccounting() public view {
        assertEq(handler.adversarialMutationViolations(), 0);
    }

    function invariant_poolManagerHasNoOutstandingTransientDelta() public view {
        assertEq(manager.getNonzeroDeltaCount(), 0);
        assertEq(manager.currencyDelta(address(hook), currency0), 0);
        assertEq(manager.currencyDelta(address(hook), currency1), 0);
        assertEq(manager.currencyDelta(address(swapRouter), currency0), 0);
        assertEq(manager.currencyDelta(address(swapRouter), currency1), 0);
    }

    function _assertCurrencyAccounting(address currency) private view {
        uint256 pending = hook.totalPendingSurcharge(currency);
        uint256 claimable = hook.totalClaimableRebate(currency);
        uint256 reserve = hook.totalLpProtectionReserve(currency);
        uint256 accounted = pending + claimable + reserve;

        assertEq(hook.accountedBalance(currency), accounted);
        assertEq(hook.actualBalance(currency), accounted);
        assertEq(hook.poolPendingSurcharge(PoolId.unwrap(markoutPoolId), currency), pending);
        assertEq(hook.lpProtectionReserve(PoolId.unwrap(markoutPoolId), currency), reserve);
        assertEq(hook.claimableRebate(address(handler), currency), claimable);
    }
}
