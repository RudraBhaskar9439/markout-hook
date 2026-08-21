// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { BalanceDelta, toBalanceDelta } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { Currency, CurrencyLibrary } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";

import { LocalMarkoutSettlementAdapter } from "../../src/adapters/LocalMarkoutSettlementAdapter.sol";
import { MarkoutHook } from "../../src/hooks/MarkoutHook.sol";
import { IMarkoutHook } from "../../src/interfaces/IMarkoutHook.sol";
import { MarkoutParameters } from "../../src/libraries/MarkoutParameters.sol";
import { PriceNormalization } from "../../src/libraries/PriceNormalization.sol";
import { ReferenceObservationValidator } from "../../src/libraries/ReferenceObservationValidator.sol";
import { TradeRecord, TradeSettlementRecord, TradeStatus } from "../../src/types/MarkoutLifecycleTypes.sol";
import { ReferenceObservation, TradeDirection } from "../../src/types/MarkoutTypes.sol";
import { MarkoutTestFixture } from "../fixtures/MarkoutTestFixture.sol";

contract RejectingNativeBeneficiary {
    function claim(MarkoutHook hook, address currency, address payable recipient) external {
        hook.claimRebate(currency, recipient);
    }

    receive() external payable {
        revert("native rejected");
    }
}

contract MarkoutHookLifecycleTest is MarkoutTestFixture {
    using CurrencyLibrary for Currency;

    function setUp() public {
        _setUpMarkout();
    }

    function test_allSwapQuadrants_createAndSettleConservedTrades() public {
        for (uint8 quadrant = 0; quadrant < 4; ++quadrant) {
            bool zeroForOne = quadrant < 2;
            bool exactInput = quadrant % 2 == 0;
            address expectedCurrency = Currency.unwrap(
                exactInput ? (zeroForOne ? currency1 : currency0) : (zeroForOne ? currency0 : currency1)
            );
            TradeDirection expectedDirection = zeroForOne ? TradeDirection.SellBase : TradeDirection.BuyBase;

            (bytes32 tradeId, TradeRecord memory pending) = _executeSwap(zeroForOne, exactInput, 1e15);
            assertEq(uint8(pending.status), uint8(TradeStatus.Pending));
            assertEq(pending.poolId, PoolId.unwrap(markoutPoolId));
            assertEq(pending.rebateRecipient, REBATE_RECIPIENT);
            assertEq(pending.currency, expectedCurrency);
            assertEq(uint8(pending.direction), uint8(expectedDirection));
            assertGt(pending.executionPriceX18, 0);
            assertGt(pending.escrowedSurcharge, 0);
            assertEq(pending.maturityTimestamp, pending.executedAt + MarkoutParameters.MATURITY_DELAY);
            assertEq(pending.expiryTimestamp, pending.maturityTimestamp + MarkoutParameters.SETTLEMENT_GRACE_PERIOD);
            assertGe(hook.actualBalance(expectedCurrency), hook.accountedBalance(expectedCurrency));

            _settleNeutral(tradeId);

            TradeRecord memory settled = hook.getTrade(tradeId);
            TradeSettlementRecord memory allocation = hook.getTradeSettlement(tradeId);
            assertEq(uint8(settled.status), uint8(TradeStatus.Settled));
            assertEq(allocation.markoutWad, 0);
            assertEq(allocation.retentionBps, MarkoutParameters.NEUTRAL_RETENTION_BPS);
            assertEq(uint256(allocation.retainedSurcharge) + allocation.rebate, pending.escrowedSurcharge);
            assertGe(hook.actualBalance(expectedCurrency), hook.accountedBalance(expectedCurrency));
        }

        assertEq(hook.poolPendingSurcharge(PoolId.unwrap(markoutPoolId), Currency.unwrap(currency0)), 0);
        assertEq(hook.poolPendingSurcharge(PoolId.unwrap(markoutPoolId), Currency.unwrap(currency1)), 0);
    }

    function test_unauthorizedAddressesCannotSettle() public {
        (bytes32 tradeId, TradeRecord memory trade) = _executeSwap(true, true, 1e15);
        vm.warp(trade.maturityTimestamp);
        ReferenceObservation memory observation = _neutralObservation(trade);

        vm.expectRevert(abi.encodeWithSelector(IMarkoutHook.UnauthorizedSettlement.selector, address(this)));
        hook.settleTrade(tradeId, observation);

        vm.prank(address(0xBAD));
        vm.expectRevert(
            abi.encodeWithSelector(LocalMarkoutSettlementAdapter.UnauthorizedOperator.selector, address(0xBAD))
        );
        adapter.settle(tradeId, observation);

        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Pending));
    }

    function test_tradeCannotBeSettledTwice() public {
        (bytes32 tradeId,) = _executeSwap(false, false, 1e15);
        TradeRecord memory trade = _settleNeutral(tradeId);

        vm.prank(SETTLEMENT_OPERATOR);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMarkoutHook.InvalidTradeStatus.selector, tradeId, TradeStatus.Settled, TradeStatus.Pending
            )
        );
        adapter.settle(tradeId, _neutralObservation(trade));
    }

    function test_settlementBeforeMaturityFailsWithoutChangingAccounting() public {
        (bytes32 tradeId, TradeRecord memory trade) = _executeSwap(true, false, 1e15);
        uint256 pendingBefore = hook.totalPendingSurcharge(trade.currency);

        vm.prank(SETTLEMENT_OPERATOR);
        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceObservationValidator.MaturityNotReached.selector, trade.maturityTimestamp, trade.executedAt
            )
        );
        adapter.settle(
            tradeId,
            ReferenceObservation({
                priceX18: trade.executionPriceX18,
                observedAt: trade.maturityTimestamp,
                confidenceBps: OBSERVATION_CONFIDENCE_BPS
            })
        );

        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Pending));
        assertEq(hook.totalPendingSurcharge(trade.currency), pendingBefore);
    }

    function test_permissionlessExpiryReturnsFullEscrowAndBlocksSettlement() public {
        (bytes32 tradeId, TradeRecord memory trade) = _executeSwap(false, true, 1e15);

        vm.expectRevert(
            abi.encodeWithSelector(
                IMarkoutHook.TradeNotExpired.selector, tradeId, trade.expiryTimestamp, trade.executedAt
            )
        );
        hook.expireTrade(tradeId);

        vm.warp(uint256(trade.expiryTimestamp) + 1);
        vm.prank(address(0xFEE));
        hook.expireTrade(tradeId);

        TradeRecord memory expired = hook.getTrade(tradeId);
        TradeSettlementRecord memory allocation = hook.getTradeSettlement(tradeId);
        assertEq(uint8(expired.status), uint8(TradeStatus.Expired));
        assertEq(allocation.retainedSurcharge, 0);
        assertEq(allocation.rebate, trade.escrowedSurcharge);
        assertEq(hook.claimableRebate(REBATE_RECIPIENT, trade.currency), trade.escrowedSurcharge);

        vm.prank(SETTLEMENT_OPERATOR);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMarkoutHook.InvalidTradeStatus.selector, tradeId, TradeStatus.Expired, TradeStatus.Pending
            )
        );
        adapter.settle(tradeId, _neutralObservation(trade));
    }

    function test_exactExpiryBoundaryStillAllowsSettlement() public {
        (bytes32 tradeId, TradeRecord memory trade) = _executeSwap(true, true, 1e15);
        vm.warp(trade.expiryTimestamp);

        vm.expectRevert(
            abi.encodeWithSelector(
                IMarkoutHook.TradeNotExpired.selector, tradeId, trade.expiryTimestamp, trade.expiryTimestamp
            )
        );
        hook.expireTrade(tradeId);

        vm.prank(SETTLEMENT_OPERATOR);
        adapter.settle(
            tradeId,
            ReferenceObservation({
                priceX18: trade.executionPriceX18,
                observedAt: trade.expiryTimestamp,
                confidenceBps: OBSERVATION_CONFIDENCE_BPS
            })
        );
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Settled));
    }

    function test_claimRebate_usesPullPaymentAndCannotBeReplayed() public {
        (bytes32 tradeId, TradeRecord memory trade) = _executeSwap(true, true, 1e15);
        _settleNeutral(tradeId);
        uint256 claimable = hook.claimableRebate(REBATE_RECIPIENT, trade.currency);
        uint256 recipientBalanceBefore = IERC20(trade.currency).balanceOf(CLAIM_RECIPIENT);

        vm.prank(REBATE_RECIPIENT);
        assertEq(hook.claimRebate(trade.currency, payable(CLAIM_RECIPIENT)), claimable);

        assertEq(IERC20(trade.currency).balanceOf(CLAIM_RECIPIENT) - recipientBalanceBefore, claimable);
        assertEq(hook.claimableRebate(REBATE_RECIPIENT, trade.currency), 0);
        assertEq(hook.totalClaimableRebate(trade.currency), 0);
        assertEq(hook.actualBalance(trade.currency), hook.totalLpProtectionReserve(trade.currency));

        vm.prank(REBATE_RECIPIENT);
        vm.expectRevert(
            abi.encodeWithSelector(IMarkoutHook.NoClaimableRebate.selector, REBATE_RECIPIENT, trade.currency)
        );
        hook.claimRebate(trade.currency, payable(CLAIM_RECIPIENT));
    }

    function test_claimToZeroAddressRevertsWithoutLosingCredit() public {
        (bytes32 tradeId, TradeRecord memory trade) = _executeSwap(true, true, 1e15);
        _settleNeutral(tradeId);
        uint256 claimable = hook.claimableRebate(REBATE_RECIPIENT, trade.currency);

        vm.prank(REBATE_RECIPIENT);
        vm.expectRevert(IMarkoutHook.ZeroClaimRecipient.selector);
        hook.claimRebate(trade.currency, payable(address(0)));

        assertEq(hook.claimableRebate(REBATE_RECIPIENT, trade.currency), claimable);
    }

    function test_claimRebateFor_allowsSponsoredGasButCannotRedirectPayment() public {
        (bytes32 tradeId, TradeRecord memory trade) = _executeSwap(true, true, 1e15);
        _settleNeutral(tradeId);
        uint256 claimable = hook.claimableRebate(REBATE_RECIPIENT, trade.currency);
        uint256 beneficiaryBalanceBefore = IERC20(trade.currency).balanceOf(REBATE_RECIPIENT);

        vm.prank(address(0x5F0A50));
        assertEq(hook.claimRebateFor(REBATE_RECIPIENT, trade.currency), claimable);

        assertEq(IERC20(trade.currency).balanceOf(REBATE_RECIPIENT) - beneficiaryBalanceBefore, claimable);
        assertEq(hook.claimableRebate(REBATE_RECIPIENT, trade.currency), 0);
        assertEq(hook.totalClaimableRebate(trade.currency), 0);

        vm.expectRevert(
            abi.encodeWithSelector(IMarkoutHook.NoClaimableRebate.selector, REBATE_RECIPIENT, trade.currency)
        );
        hook.claimRebateFor(REBATE_RECIPIENT, trade.currency);
    }

    function test_neutralTradeReceivesLargerRebateThanToxicTrade() public {
        (bytes32 neutralId, TradeRecord memory neutralTrade) = _executeSwap(false, true, 1e15);
        (bytes32 toxicId, TradeRecord memory toxicTrade) = _executeSwap(false, true, 1e15);

        _settleNeutral(neutralId);
        _settleToxic(toxicId);

        TradeSettlementRecord memory neutral = hook.getTradeSettlement(neutralId);
        TradeSettlementRecord memory toxic = hook.getTradeSettlement(toxicId);
        assertGt(neutral.rebate, toxic.rebate);
        assertLt(neutral.retainedSurcharge, toxic.retainedSurcharge);
        assertEq(uint256(neutral.rebate) + neutral.retainedSurcharge, neutralTrade.escrowedSurcharge);
        assertEq(uint256(toxic.rebate) + toxic.retainedSurcharge, toxicTrade.escrowedSurcharge);
        assertEq(
            hook.accountedBalance(neutralTrade.currency),
            hook.totalClaimableRebate(neutralTrade.currency) + hook.totalLpProtectionReserve(neutralTrade.currency)
        );
        assertEq(hook.actualBalance(neutralTrade.currency), hook.accountedBalance(neutralTrade.currency));
    }

    function test_smallAmountThatRoundsSurchargeToZeroCreatesNoTrade() public {
        uint256 nonceBefore = hook.nextTradeNonce();
        bytes32 latestBefore = hook.latestTradeId();

        swap(markoutPoolKey, true, -int256(100), _hookData(REBATE_RECIPIENT));

        assertEq(hook.nextTradeNonce(), nonceBefore);
        assertEq(hook.latestTradeId(), latestBefore);
        assertEq(hook.accountedBalance(Currency.unwrap(currency0)), 0);
        assertEq(hook.accountedBalance(Currency.unwrap(currency1)), 0);
    }

    function test_tradeIdsAreUniqueAndSequentiallyCounted() public {
        (bytes32 firstId,) = _executeSwap(true, true, 1e15);
        (bytes32 secondId,) = _executeSwap(true, true, 1e15);

        assertNotEq(firstId, secondId);
        assertEq(hook.nextTradeNonce(), 2);
        assertEq(hook.latestTradeId(), secondId);
    }

    function test_unsupportedCurrencyPairFailsBeforeAccrual() public {
        PoolKey memory unsupportedKey = markoutPoolKey;
        unsupportedKey.currency0 = CurrencyLibrary.ADDRESS_ZERO;

        vm.prank(address(manager));
        vm.expectRevert(
            abi.encodeWithSelector(
                IMarkoutHook.UnsupportedPool.selector, address(0), Currency.unwrap(unsupportedKey.currency1)
            )
        );
        hook.afterSwap(
            address(swapRouter),
            unsupportedKey,
            _swapParams(true, true, 1e15),
            // Synthetic nonzero pool delta; validation reverts before custody is attempted.
            _syntheticDelta(),
            _hookData(REBATE_RECIPIENT)
        );
    }

    function test_constructorRejectsZeroSettlementAuthority() public {
        vm.expectRevert(IMarkoutHook.ZeroSettlementAuthority.selector);
        deployCodeTo(
            "src/hooks/MarkoutHook.sol:MarkoutHook",
            abi.encode(
                manager,
                SURCHARGE_BPS,
                address(0),
                Currency.unwrap(currency0),
                uint8(18),
                Currency.unwrap(currency1),
                uint8(18)
            ),
            _hookAddress(0x4D52)
        );
    }

    function test_constructorRejectsIdenticalBaseAndQuote() public {
        address currency = Currency.unwrap(currency0);
        vm.expectRevert(abi.encodeWithSelector(IMarkoutHook.IdenticalBaseAndQuoteCurrency.selector, currency));
        deployCodeTo(
            "src/hooks/MarkoutHook.sol:MarkoutHook",
            abi.encode(manager, SURCHARGE_BPS, SETTLEMENT_OPERATOR, currency, uint8(18), currency, uint8(18)),
            _hookAddress(0x4D53)
        );
    }

    function test_constructorRejectsUnsupportedTokenDecimals() public {
        vm.expectRevert(abi.encodeWithSelector(PriceNormalization.UnsupportedDecimals.selector, uint8(37)));
        deployCodeTo(
            "src/hooks/MarkoutHook.sol:MarkoutHook",
            abi.encode(
                manager,
                SURCHARGE_BPS,
                SETTLEMENT_OPERATOR,
                Currency.unwrap(currency0),
                uint8(37),
                Currency.unwrap(currency1),
                uint8(18)
            ),
            _hookAddress(0x4D54)
        );
    }

    function test_failedNativeClaimDoesNotBlockSettlementOrOtherClaims() public {
        deal(address(this), 10 ether);
        RejectingNativeBeneficiary rejecting = new RejectingNativeBeneficiary();
        MarkoutHook nativeHook = _deployNativeHook(0x4D51);
        (PoolKey memory nativePoolKey,) = initPoolAndAddLiquidityETH(
            CurrencyLibrary.ADDRESS_ZERO, currency1, IHooks(address(nativeHook)), 3000, SQRT_PRICE_1_1, 1 ether
        );

        bytes32 rejectingTradeId = _nativeOutputSwap(nativeHook, nativePoolKey, address(rejecting));
        TradeRecord memory rejectingTrade = nativeHook.getTrade(rejectingTradeId);
        _settleDirect(nativeHook, rejectingTradeId, rejectingTrade);
        uint256 rejectingClaimable = nativeHook.claimableRebate(address(rejecting), address(0));

        vm.expectRevert(
            abi.encodeWithSelector(IMarkoutHook.NativeTransferFailed.selector, address(rejecting), rejectingClaimable)
        );
        rejecting.claim(nativeHook, address(0), payable(address(rejecting)));
        assertGt(rejectingClaimable, 0);

        vm.expectRevert(
            abi.encodeWithSelector(IMarkoutHook.NativeTransferFailed.selector, address(rejecting), rejectingClaimable)
        );
        nativeHook.claimRebateFor(address(rejecting), address(0));
        assertEq(nativeHook.claimableRebate(address(rejecting), address(0)), rejectingClaimable);

        bytes32 healthyTradeId = _nativeOutputSwap(nativeHook, nativePoolKey, REBATE_RECIPIENT);
        TradeRecord memory healthyTrade = nativeHook.getTrade(healthyTradeId);
        _settleDirect(nativeHook, healthyTradeId, healthyTrade);
        uint256 healthyClaimable = nativeHook.claimableRebate(REBATE_RECIPIENT, address(0));
        uint256 healthyBalanceBefore = CLAIM_RECIPIENT.balance;
        vm.prank(REBATE_RECIPIENT);
        nativeHook.claimRebate(address(0), payable(CLAIM_RECIPIENT));
        assertEq(CLAIM_RECIPIENT.balance - healthyBalanceBefore, healthyClaimable);

        uint256 redirectedBalanceBefore = CLAIM_RECIPIENT.balance;
        rejecting.claim(nativeHook, address(0), payable(CLAIM_RECIPIENT));
        assertEq(CLAIM_RECIPIENT.balance - redirectedBalanceBefore, rejectingClaimable);
        assertEq(nativeHook.claimableRebate(address(rejecting), address(0)), 0);
        assertEq(nativeHook.actualBalance(address(0)), nativeHook.accountedBalance(address(0)));
    }

    function testFuzz_allSwapModesAndTerminalPathsRemainConserved(
        uint96 rawAmount,
        uint8 rawQuadrant,
        uint8 rawTerminalPath
    ) public {
        uint128 amount = 1e8 + uint128(rawAmount % (1e15 - 1e8 + 1));
        uint8 quadrant = rawQuadrant % 4;
        uint8 terminalPath = rawTerminalPath % 3;
        bool zeroForOne = quadrant < 2;
        bool exactInput = quadrant % 2 == 0;
        (bytes32 tradeId, TradeRecord memory trade) = _executeSwap(zeroForOne, exactInput, amount);

        if (terminalPath == 0) {
            _settleNeutral(tradeId);
        } else if (terminalPath == 1) {
            _settleToxic(tradeId);
        } else {
            vm.warp(uint256(trade.expiryTimestamp) + 1);
            hook.expireTrade(tradeId);
        }

        TradeSettlementRecord memory allocation = hook.getTradeSettlement(tradeId);
        assertEq(uint256(allocation.retainedSurcharge) + allocation.rebate, trade.escrowedSurcharge);
        assertEq(hook.totalPendingSurcharge(trade.currency), 0);
        assertEq(hook.actualBalance(trade.currency), hook.accountedBalance(trade.currency));

        uint256 claimable = hook.claimableRebate(REBATE_RECIPIENT, trade.currency);
        if (claimable != 0) {
            vm.prank(REBATE_RECIPIENT);
            hook.claimRebate(trade.currency, payable(CLAIM_RECIPIENT));
        }
        assertEq(hook.actualBalance(trade.currency), hook.accountedBalance(trade.currency));
    }

    function _deployNativeHook(uint16 namespace) private returns (MarkoutHook nativeHook) {
        address hookAddress = _hookAddress(namespace);
        deployCodeTo(
            "src/hooks/MarkoutHook.sol:MarkoutHook",
            abi.encode(
                manager,
                SURCHARGE_BPS,
                SETTLEMENT_OPERATOR,
                address(0),
                uint8(18),
                Currency.unwrap(currency1),
                uint8(18)
            ),
            hookAddress
        );
        nativeHook = MarkoutHook(payable(hookAddress));
    }

    function _nativeOutputSwap(MarkoutHook nativeHook, PoolKey memory nativePoolKey, address beneficiary)
        private
        returns (bytes32 tradeId)
    {
        uint256 nonceBefore = nativeHook.nextTradeNonce();
        swapNativeInput(nativePoolKey, false, -int256(1e15), _hookData(beneficiary), 0);
        assertEq(nativeHook.nextTradeNonce(), nonceBefore + 1);
        tradeId = nativeHook.latestTradeId();
    }

    function _settleDirect(MarkoutHook target, bytes32 tradeId, TradeRecord memory trade) private {
        vm.warp(trade.maturityTimestamp);
        vm.prank(SETTLEMENT_OPERATOR);
        target.settleTrade(tradeId, _neutralObservation(trade));
    }

    function _neutralObservation(TradeRecord memory trade)
        private
        pure
        returns (ReferenceObservation memory observation)
    {
        observation = ReferenceObservation({
            priceX18: trade.executionPriceX18,
            observedAt: trade.maturityTimestamp,
            confidenceBps: OBSERVATION_CONFIDENCE_BPS
        });
    }

    function _swapParams(bool zeroForOne, bool exactInput, uint128 amount)
        private
        pure
        returns (SwapParams memory params)
    {
        params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: exactInput ? -int256(uint256(amount)) : int256(uint256(amount)),
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
        });
    }

    function _syntheticDelta() private pure returns (BalanceDelta) {
        return toBalanceDelta(-int128(1e15), int128(1e15));
    }
}
