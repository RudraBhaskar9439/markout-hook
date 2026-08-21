// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm } from "forge-std/Vm.sol";

import { IERC20Minimal } from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";

import { MarkoutHook } from "../../../src/hooks/MarkoutHook.sol";
import { SurchargeHookData } from "../../../src/libraries/SurchargeHookData.sol";
import { TradeRecord, TradeSettlementRecord, TradeStatus } from "../../../src/types/MarkoutLifecycleTypes.sol";
import { ReferenceObservation } from "../../../src/types/MarkoutTypes.sol";
import { SurchargeAuthorization } from "../../../src/types/SurchargeTypes.sol";

/// @notice Stateful action generator that drives real PoolManager swaps through every terminal lifecycle path.
contract MarkoutLifecycleHandler {
    uint128 private constant MIN_AMOUNT = 1e6;
    uint128 private constant MAX_AMOUNT = 1e10;
    uint16 private constant CONFIDENCE_BPS = 9500;
    Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    MarkoutHook public immutable hook;
    PoolSwapTest public immutable swapRouter;
    address public immutable settlementAuthority;
    address public immutable currency0;
    address public immutable currency1;

    PoolKey private _poolKey;
    bytes32[] private _tradeIds;
    mapping(address currency => uint256 amount) public claimed;

    uint256 public completedAllocationChecks;
    uint256 public conservationViolations;
    uint256 public adversarialMutationViolations;

    constructor(MarkoutHook hook_, PoolSwapTest swapRouter_, PoolKey memory poolKey_, address settlementAuthority_) {
        hook = hook_;
        swapRouter = swapRouter_;
        settlementAuthority = settlementAuthority_;
        currency0 = Currency.unwrap(poolKey_.currency0);
        currency1 = Currency.unwrap(poolKey_.currency1);
        _poolKey = poolKey_;

        IERC20Minimal(currency0).approve(address(swapRouter_), type(uint256).max);
        IERC20Minimal(currency1).approve(address(swapRouter_), type(uint256).max);
    }

    function swap(uint96 amountSeed, uint8 quadrantSeed) external {
        uint128 amount = MIN_AMOUNT + uint128(amountSeed % (MAX_AMOUNT - MIN_AMOUNT + 1));
        uint8 quadrant = quadrantSeed % 4;
        bool zeroForOne = quadrant < 2;
        bool exactInput = quadrant % 2 == 0;

        swapRouter.swap(
            _poolKey,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: exactInput ? -int256(uint256(amount)) : int256(uint256(amount)),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            SurchargeHookData.encode(
                SurchargeAuthorization({ rebateRecipient: address(this), maximumAmount: type(uint128).max })
            )
        );

        _tradeIds.push(hook.latestTradeId());
    }

    function settle(uint256 tradeSeed) external {
        if (_tradeIds.length == 0) return;
        bytes32 tradeId = _tradeIds[tradeSeed % _tradeIds.length];
        TradeRecord memory trade = hook.getTrade(tradeId);
        if (trade.status != TradeStatus.Pending) return;

        // Time-window branching is the behavior this stateful handler is designed to exercise.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp > trade.expiryTimestamp) {
            hook.expireTrade(tradeId);
        } else {
            // forge-lint: disable-next-line(block-timestamp)
            if (block.timestamp < trade.maturityTimestamp) VM.warp(trade.maturityTimestamp);
            // Handler time advances only by bounded phase windows, so this conversion remains lossless.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint64 observedAt = uint64(block.timestamp);
            VM.prank(settlementAuthority);
            hook.settleTrade(
                tradeId,
                ReferenceObservation({
                    priceX18: trade.executionPriceX18, observedAt: observedAt, confidenceBps: CONFIDENCE_BPS
                })
            );
        }

        _checkTerminalConservation(tradeId, trade.escrowedSurcharge);
    }

    function expire(uint256 tradeSeed) external {
        if (_tradeIds.length == 0) return;
        bytes32 tradeId = _tradeIds[tradeSeed % _tradeIds.length];
        TradeRecord memory trade = hook.getTrade(tradeId);
        if (trade.status != TradeStatus.Pending) return;

        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp <= trade.expiryTimestamp) VM.warp(uint256(trade.expiryTimestamp) + 1);
        hook.expireTrade(tradeId);
        _checkTerminalConservation(tradeId, trade.escrowedSurcharge);
    }

    function claim(uint8 currencySeed) external {
        address currency = currencySeed % 2 == 0 ? currency0 : currency1;
        uint256 amount = hook.claimableRebate(address(this), currency);
        if (amount == 0) return;

        uint256 received = hook.claimRebate(currency, payable(address(this)));
        claimed[currency] += received;
    }

    /// @notice Exercises gas sponsorship while ensuring the handler remains the only payment recipient.
    function sponsoredClaim(uint8 currencySeed) external {
        address currency = currencySeed % 2 == 0 ? currency0 : currency1;
        uint256 amount = hook.claimableRebate(address(this), currency);
        if (amount == 0) return;

        VM.prank(address(0x5F0A50));
        uint256 received = hook.claimRebateFor(address(this), currency);
        claimed[currency] += received;
    }

    /// @notice Probes the settlement authorization boundary without allowing expected reverts to stop invariant runs.
    function unauthorizedSettle(uint256 tradeSeed) external {
        if (_tradeIds.length == 0) return;
        bytes32 tradeId = _tradeIds[tradeSeed % _tradeIds.length];
        TradeRecord memory trade = hook.getTrade(tradeId);
        if (trade.status != TradeStatus.Pending) return;

        AccountingSnapshot memory before_ = _accountingSnapshot(trade.currency);
        VM.prank(address(0xBAD));
        (bool success,) = address(hook)
            .call(
                abi.encodeCall(
                    hook.settleTrade,
                    (
                        tradeId,
                        ReferenceObservation({
                        priceX18: trade.executionPriceX18,
                        observedAt: trade.maturityTimestamp,
                        confidenceBps: CONFIDENCE_BPS
                    })
                    )
                )
            );

        if (success || _snapshotChanged(before_, _accountingSnapshot(trade.currency))) {
            ++adversarialMutationViolations;
        }
    }

    /// @notice Probes that an unrelated caller cannot redirect the handler's rebate credit.
    function unauthorizedClaim(uint8 currencySeed) external {
        address currency = currencySeed % 2 == 0 ? currency0 : currency1;
        AccountingSnapshot memory before_ = _accountingSnapshot(currency);
        uint256 beneficiaryClaimableBefore = hook.claimableRebate(address(this), currency);

        address attacker = address(0xBAD);
        VM.prank(attacker);
        (bool success,) = address(hook).call(abi.encodeCall(hook.claimRebate, (currency, payable(attacker))));

        if (
            success || hook.claimableRebate(address(this), currency) != beneficiaryClaimableBefore
                || _snapshotChanged(before_, _accountingSnapshot(currency))
        ) {
            ++adversarialMutationViolations;
        }
    }

    /// @notice Probes that permissionless expiry remains unavailable until the documented fail-open boundary.
    function prematureExpiry(uint256 tradeSeed) external {
        if (_tradeIds.length == 0) return;
        bytes32 tradeId = _tradeIds[tradeSeed % _tradeIds.length];
        TradeRecord memory trade = hook.getTrade(tradeId);
        // This handler intentionally branches across the exact production expiry boundary.
        // forge-lint: disable-next-line(block-timestamp)
        if (trade.status != TradeStatus.Pending || block.timestamp > trade.expiryTimestamp) return;

        AccountingSnapshot memory before_ = _accountingSnapshot(trade.currency);
        (bool success,) = address(hook).call(abi.encodeCall(hook.expireTrade, (tradeId)));

        if (
            success || hook.getTrade(tradeId).status != TradeStatus.Pending
                || _snapshotChanged(before_, _accountingSnapshot(trade.currency))
        ) {
            ++adversarialMutationViolations;
        }
    }

    function tradeCount() external view returns (uint256) {
        return _tradeIds.length;
    }

    struct AccountingSnapshot {
        uint256 pending;
        uint256 claimable;
        uint256 reserve;
        uint256 accounted;
        uint256 actual;
    }

    function _accountingSnapshot(address currency) private view returns (AccountingSnapshot memory snapshot) {
        snapshot = AccountingSnapshot({
            pending: hook.totalPendingSurcharge(currency),
            claimable: hook.totalClaimableRebate(currency),
            reserve: hook.totalLpProtectionReserve(currency),
            accounted: hook.accountedBalance(currency),
            actual: hook.actualBalance(currency)
        });
    }

    function _snapshotChanged(AccountingSnapshot memory before_, AccountingSnapshot memory after_)
        private
        pure
        returns (bool)
    {
        return before_.pending != after_.pending || before_.claimable != after_.claimable
            || before_.reserve != after_.reserve || before_.accounted != after_.accounted
            || before_.actual != after_.actual;
    }

    function _checkTerminalConservation(bytes32 tradeId, uint128 escrowedSurcharge) private {
        TradeSettlementRecord memory settlement = hook.getTradeSettlement(tradeId);
        if (uint256(settlement.retainedSurcharge) + settlement.rebate != escrowedSurcharge) {
            ++conservationViolations;
        }
        ++completedAllocationChecks;
    }
}
