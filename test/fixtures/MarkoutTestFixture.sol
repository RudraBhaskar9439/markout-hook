// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";

import { LocalMarkoutSettlementAdapter } from "../../src/adapters/LocalMarkoutSettlementAdapter.sol";
import { MarkoutHook } from "../../src/hooks/MarkoutHook.sol";
import { SurchargeHookData } from "../../src/libraries/SurchargeHookData.sol";
import { TradeRecord } from "../../src/types/MarkoutLifecycleTypes.sol";
import { ReferenceObservation, TradeDirection } from "../../src/types/MarkoutTypes.sol";
import { SurchargeAuthorization } from "../../src/types/SurchargeTypes.sol";

abstract contract MarkoutTestFixture is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    uint16 internal constant SURCHARGE_BPS = 50;
    uint16 internal constant OBSERVATION_CONFIDENCE_BPS = 9500;
    address internal constant SETTLEMENT_OPERATOR = address(0xA11CE);
    address internal constant REBATE_RECIPIENT = address(0xBEEF);
    address internal constant CLAIM_RECIPIENT = address(0xCAFE);

    MarkoutHook internal hook;
    LocalMarkoutSettlementAdapter internal adapter;
    PoolKey internal markoutPoolKey;
    PoolId internal markoutPoolId;

    function _setUpMarkout() internal {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        adapter = new LocalMarkoutSettlementAdapter(SETTLEMENT_OPERATOR);
        address hookAddress = _hookAddress(0x4D50);
        deployCodeTo(
            "src/hooks/MarkoutHook.sol:MarkoutHook",
            abi.encode(
                manager,
                SURCHARGE_BPS,
                address(adapter),
                Currency.unwrap(currency0),
                uint8(18),
                Currency.unwrap(currency1),
                uint8(18)
            ),
            hookAddress
        );
        hook = MarkoutHook(payable(hookAddress));

        vm.prank(SETTLEMENT_OPERATOR);
        adapter.bindTarget(hook);

        (markoutPoolKey, markoutPoolId) =
            initPoolAndAddLiquidity(currency0, currency1, IHooks(hookAddress), 3000, SQRT_PRICE_1_1);

        vm.label(hookAddress, "MarkoutHook");
        vm.label(address(adapter), "LocalSettlementAdapter");
        vm.label(SETTLEMENT_OPERATOR, "SettlementOperator");
        vm.label(REBATE_RECIPIENT, "RebateRecipient");
    }

    function _executeSwap(bool zeroForOne, bool exactInput, uint128 amount)
        internal
        returns (bytes32 tradeId, TradeRecord memory trade)
    {
        return _executeSwapFor(REBATE_RECIPIENT, zeroForOne, exactInput, amount);
    }

    function _executeSwapFor(address beneficiary, bool zeroForOne, bool exactInput, uint128 amount)
        internal
        returns (bytes32 tradeId, TradeRecord memory trade)
    {
        uint256 nonceBefore = hook.nextTradeNonce();
        swapRouter.swap(
            markoutPoolKey,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: exactInput ? -int256(uint256(amount)) : int256(uint256(amount)),
                sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            _hookData(beneficiary)
        );

        assertEq(hook.nextTradeNonce(), nonceBefore + 1, "one trade must be created");
        tradeId = hook.latestTradeId();
        trade = hook.getTrade(tradeId);
    }

    function _settleNeutral(bytes32 tradeId) internal returns (TradeRecord memory trade) {
        trade = hook.getTrade(tradeId);
        vm.warp(trade.maturityTimestamp);
        vm.prank(SETTLEMENT_OPERATOR);
        adapter.settle(
            tradeId,
            ReferenceObservation({
                priceX18: trade.executionPriceX18,
                observedAt: trade.maturityTimestamp,
                confidenceBps: OBSERVATION_CONFIDENCE_BPS
            })
        );
    }

    function _settleToxic(bytes32 tradeId) internal returns (uint192 referencePriceX18) {
        TradeRecord memory trade = hook.getTrade(tradeId);
        referencePriceX18 = _toxicReferencePrice(trade.executionPriceX18, trade.direction);
        vm.warp(trade.maturityTimestamp);
        vm.prank(SETTLEMENT_OPERATOR);
        adapter.settle(
            tradeId,
            ReferenceObservation({
                priceX18: referencePriceX18,
                observedAt: trade.maturityTimestamp,
                confidenceBps: OBSERVATION_CONFIDENCE_BPS
            })
        );
    }

    function _toxicReferencePrice(uint192 executionPriceX18, TradeDirection direction) internal pure returns (uint192) {
        uint256 referencePrice = direction == TradeDirection.BuyBase
            ? uint256(executionPriceX18) * 10_030 / 10_000
            : uint256(executionPriceX18) * 9970 / 10_000;
        // The calculation changes a uint192 input by at most 30 bps in these tests.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint192(referencePrice);
    }

    function _hookData(address beneficiary) internal pure returns (bytes memory) {
        return SurchargeHookData.encode(
            SurchargeAuthorization({ rebateRecipient: beneficiary, maximumAmount: type(uint128).max })
        );
    }

    function _hookAddress(uint16 namespace) internal pure returns (address) {
        uint160 flags = Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
        return address(flags | (uint160(namespace) << 144));
    }
}
