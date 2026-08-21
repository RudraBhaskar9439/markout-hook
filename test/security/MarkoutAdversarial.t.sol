// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ReentrancyGuard } from "openzeppelin/utils/ReentrancyGuard.sol";

import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IERC20Minimal } from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import { Currency, CurrencyLibrary } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";

import { MarkoutHook } from "../../src/hooks/MarkoutHook.sol";
import { IMarkoutHook } from "../../src/interfaces/IMarkoutHook.sol";
import { MarkoutParameters } from "../../src/libraries/MarkoutParameters.sol";
import { ReferenceObservationValidator } from "../../src/libraries/ReferenceObservationValidator.sol";
import { TradeRecord, TradeStatus } from "../../src/types/MarkoutLifecycleTypes.sol";
import { ReferenceObservation } from "../../src/types/MarkoutTypes.sol";
import { MarkoutTestFixture } from "../fixtures/MarkoutTestFixture.sol";

contract ReentrantNativeClaimant {
    MarkoutHook private immutable _hook;

    bool public reentryBlocked;
    uint256 public receiveCount;

    constructor(MarkoutHook hook_) {
        _hook = hook_;
    }

    function claim() external returns (uint256 amount) {
        amount = _hook.claimRebate(address(0), payable(address(this)));
    }

    receive() external payable {
        ++receiveCount;
        (bool success, bytes memory returndata) =
            address(_hook).call(abi.encodeCall(_hook.claimRebate, (address(0), payable(address(this)))));
        reentryBlocked = !success && returndata.length >= 4
            // The length check proves that reading the first four revert-data bytes is safe.
            // forge-lint: disable-next-line(unsafe-typecast)
            && bytes4(returndata) == ReentrancyGuard.ReentrancyGuardReentrantCall.selector;
    }
}

/// @notice Phase 7 adversarial probes for authorization, solvency, liveness, donations, and reentrancy.
contract MarkoutAdversarialTest is MarkoutTestFixture {
    using CurrencyLibrary for Currency;

    address private constant ATTACKER = address(0xBAD);

    function setUp() public {
        _setUpMarkout();
    }

    function test_attackerCannotRedirectAnotherBeneficiaryRebate() public {
        (bytes32 tradeId, TradeRecord memory trade) = _executeSwap(true, true, 1e15);
        _settleNeutral(tradeId);

        uint256 claimableBefore = hook.claimableRebate(REBATE_RECIPIENT, trade.currency);
        uint256 accountedBefore = hook.accountedBalance(trade.currency);
        uint256 attackerBalanceBefore = IERC20Minimal(trade.currency).balanceOf(ATTACKER);

        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(IMarkoutHook.NoClaimableRebate.selector, ATTACKER, trade.currency));
        hook.claimRebate(trade.currency, payable(ATTACKER));

        assertEq(hook.claimableRebate(REBATE_RECIPIENT, trade.currency), claimableBefore);
        assertEq(hook.accountedBalance(trade.currency), accountedBefore);
        assertEq(IERC20Minimal(trade.currency).balanceOf(ATTACKER), attackerBalanceBefore);

        vm.prank(REBATE_RECIPIENT);
        hook.claimRebate(trade.currency, payable(ATTACKER));
        assertEq(IERC20Minimal(trade.currency).balanceOf(ATTACKER) - attackerBalanceBefore, claimableBefore);
    }

    function test_sponsoredClaimAlwaysPaysTheRecordedBeneficiary() public {
        (bytes32 tradeId, TradeRecord memory trade) = _executeSwap(true, true, 1e15);
        _settleNeutral(tradeId);
        uint256 claimableBefore = hook.claimableRebate(REBATE_RECIPIENT, trade.currency);
        uint256 beneficiaryBalanceBefore = IERC20Minimal(trade.currency).balanceOf(REBATE_RECIPIENT);
        uint256 attackerBalanceBefore = IERC20Minimal(trade.currency).balanceOf(ATTACKER);

        vm.prank(ATTACKER);
        assertEq(hook.claimRebateFor(REBATE_RECIPIENT, trade.currency), claimableBefore);

        assertEq(IERC20Minimal(trade.currency).balanceOf(REBATE_RECIPIENT) - beneficiaryBalanceBefore, claimableBefore);
        assertEq(IERC20Minimal(trade.currency).balanceOf(ATTACKER), attackerBalanceBefore);
        assertEq(hook.claimableRebate(REBATE_RECIPIENT, trade.currency), 0);
    }

    function test_invalidObservationCannotMutateAccountingAndTradeCanStillExpire() public {
        (bytes32 tradeId, TradeRecord memory trade) = _executeSwap(false, false, 1e15);
        uint256 pendingBefore = hook.totalPendingSurcharge(trade.currency);
        uint256 accountedBefore = hook.accountedBalance(trade.currency);

        vm.warp(trade.maturityTimestamp);
        vm.prank(SETTLEMENT_OPERATOR);
        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceObservationValidator.ConfidenceBelowMinimum.selector,
                uint16(MarkoutParameters.MINIMUM_CONFIDENCE_BPS - 1),
                MarkoutParameters.MINIMUM_CONFIDENCE_BPS
            )
        );
        adapter.settle(
            tradeId,
            ReferenceObservation({
                priceX18: trade.executionPriceX18,
                observedAt: trade.maturityTimestamp,
                confidenceBps: MarkoutParameters.MINIMUM_CONFIDENCE_BPS - 1
            })
        );

        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Pending));
        assertEq(hook.totalPendingSurcharge(trade.currency), pendingBefore);
        assertEq(hook.accountedBalance(trade.currency), accountedBefore);

        vm.warp(uint256(trade.expiryTimestamp) + 1);
        vm.prank(ATTACKER);
        hook.expireTrade(tradeId);
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Expired));
        assertEq(hook.totalPendingSurcharge(trade.currency), 0);
        assertEq(hook.claimableRebate(REBATE_RECIPIENT, trade.currency), trade.escrowedSurcharge);
        assertEq(hook.actualBalance(trade.currency), hook.accountedBalance(trade.currency));
    }

    function test_forcedTokenDonationCannotBeClaimedOrMisclassified() public {
        address token = Currency.unwrap(currency0);
        uint256 donation = 1 ether;
        assertTrue(IERC20Minimal(token).transfer(address(hook), donation));

        assertEq(hook.accountedBalance(token), 0);
        assertEq(hook.actualBalance(token), donation);
        assertEq(hook.totalPendingSurcharge(token), 0);
        assertEq(hook.totalClaimableRebate(token), 0);
        assertEq(hook.totalLpProtectionReserve(token), 0);

        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(IMarkoutHook.NoClaimableRebate.selector, ATTACKER, token));
        hook.claimRebate(token, payable(ATTACKER));
        assertEq(hook.actualBalance(token), donation);
    }

    function test_failedSettlementCannotConsumeReplayProtection() public {
        (bytes32 tradeId, TradeRecord memory trade) = _executeSwap(true, false, 1e15);
        vm.warp(trade.maturityTimestamp);

        vm.prank(SETTLEMENT_OPERATOR);
        vm.expectRevert(ReferenceObservationValidator.ZeroObservationPrice.selector);
        adapter.settle(
            tradeId,
            ReferenceObservation({
                priceX18: 0, observedAt: trade.maturityTimestamp, confidenceBps: OBSERVATION_CONFIDENCE_BPS
            })
        );
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Pending));

        vm.prank(SETTLEMENT_OPERATOR);
        adapter.settle(
            tradeId,
            ReferenceObservation({
                priceX18: trade.executionPriceX18,
                observedAt: trade.maturityTimestamp,
                confidenceBps: OBSERVATION_CONFIDENCE_BPS
            })
        );
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Settled));
        assertEq(hook.actualBalance(trade.currency), hook.accountedBalance(trade.currency));
    }

    function test_nativeClaimReentrancyIsBlockedWithoutLosingTheOuterClaim() public {
        vm.deal(address(this), 10 ether);
        MarkoutHook nativeHook = _deployNativeHook(0x5EC0);
        ReentrantNativeClaimant claimant = new ReentrantNativeClaimant(nativeHook);
        (PoolKey memory nativePoolKey,) = initPoolAndAddLiquidityETH(
            CurrencyLibrary.ADDRESS_ZERO, currency1, IHooks(address(nativeHook)), 3000, SQRT_PRICE_1_1, 1 ether
        );

        swapNativeInput(nativePoolKey, false, -int256(1e15), _hookData(address(claimant)), 0);
        bytes32 tradeId = nativeHook.latestTradeId();
        TradeRecord memory trade = nativeHook.getTrade(tradeId);
        vm.warp(trade.maturityTimestamp);
        vm.prank(SETTLEMENT_OPERATOR);
        nativeHook.settleTrade(
            tradeId,
            ReferenceObservation({
                priceX18: trade.executionPriceX18,
                observedAt: trade.maturityTimestamp,
                confidenceBps: OBSERVATION_CONFIDENCE_BPS
            })
        );

        uint256 claimable = nativeHook.claimableRebate(address(claimant), address(0));
        uint256 balanceBefore = address(claimant).balance;
        assertEq(claimant.claim(), claimable);

        assertTrue(claimant.reentryBlocked());
        assertEq(claimant.receiveCount(), 1);
        assertEq(address(claimant).balance - balanceBefore, claimable);
        assertEq(nativeHook.claimableRebate(address(claimant), address(0)), 0);
        assertEq(nativeHook.actualBalance(address(0)), nativeHook.accountedBalance(address(0)));
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
}
