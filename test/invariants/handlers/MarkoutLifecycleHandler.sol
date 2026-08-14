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

    function tradeCount() external view returns (uint256) {
        return _tradeIds.length;
    }

    function _checkTerminalConservation(bytes32 tradeId, uint128 escrowedSurcharge) private {
        TradeSettlementRecord memory settlement = hook.getTradeSettlement(tradeId);
        if (uint256(settlement.retainedSurcharge) + settlement.rebate != escrowedSurcharge) {
            ++conservationViolations;
        }
        ++completedAllocationChecks;
    }
}
