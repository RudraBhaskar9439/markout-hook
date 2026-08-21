// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "openzeppelin/utils/ReentrancyGuard.sol";

import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { BalanceDelta, BalanceDeltaLibrary } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { Currency, CurrencyLibrary } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";

import { IMarkoutHook } from "../interfaces/IMarkoutHook.sol";
import { MarkoutParameters } from "../libraries/MarkoutParameters.sol";
import { MarkoutSettlementEngine } from "../libraries/MarkoutSettlementEngine.sol";
import { PriceNormalization } from "../libraries/PriceNormalization.sol";
import { ReferenceObservationValidator } from "../libraries/ReferenceObservationValidator.sol";
import { SwapDeltaAccounting } from "../libraries/SwapDeltaAccounting.sol";
import { TradeRecord, TradeSettlementRecord, TradeStatus } from "../types/MarkoutLifecycleTypes.sol";
import { MarkoutSettlement, ObservationRules, ReferenceObservation, TradeDirection } from "../types/MarkoutTypes.sol";
import { SurchargeQuote } from "../types/SurchargeTypes.sol";
import { FixedBpsProvisionalSurchargeHook } from "./FixedBpsProvisionalSurchargeHook.sol";

/// @title MARKOUT Hook
/// @notice Local end-to-end MARKOUT lifecycle composed from the Phase 1 custody and Phase 2 economic primitives.
contract MarkoutHook is FixedBpsProvisionalSurchargeHook, ReentrancyGuard, IMarkoutHook {
    using BalanceDeltaLibrary for BalanceDelta;
    using CurrencyLibrary for Currency;
    using SafeERC20 for IERC20;

    address public immutable override settlementAuthority;
    address public immutable baseCurrency;
    address public immutable quoteCurrency;
    uint8 public immutable baseDecimals;
    uint8 public immutable quoteDecimals;

    bytes32 public override latestTradeId;
    uint256 public override nextTradeNonce;

    mapping(bytes32 tradeId => TradeRecord trade) private _trades;
    mapping(bytes32 tradeId => TradeSettlementRecord settlement) private _tradeSettlements;
    mapping(bytes32 poolId => mapping(address currency => uint256 amount)) private _poolPending;
    mapping(address currency => uint256 amount) private _totalPending;
    mapping(address beneficiary => mapping(address currency => uint256 amount)) private _claimable;
    mapping(address currency => uint256 amount) private _totalClaimable;
    mapping(bytes32 poolId => mapping(address currency => uint256 amount)) private _poolReserve;
    mapping(address currency => uint256 amount) private _totalReserve;

    constructor(
        IPoolManager poolManager_,
        uint16 surchargeBps_,
        address settlementAuthority_,
        address baseCurrency_,
        uint8 baseDecimals_,
        address quoteCurrency_,
        uint8 quoteDecimals_
    ) FixedBpsProvisionalSurchargeHook(poolManager_, surchargeBps_) {
        if (settlementAuthority_ == address(0)) revert ZeroSettlementAuthority();
        if (baseCurrency_ == quoteCurrency_) revert IdenticalBaseAndQuoteCurrency(baseCurrency_);
        PriceNormalization.validateDecimals(baseDecimals_);
        PriceNormalization.validateDecimals(quoteDecimals_);

        settlementAuthority = settlementAuthority_;
        baseCurrency = baseCurrency_;
        quoteCurrency = quoteCurrency_;
        baseDecimals = baseDecimals_;
        quoteDecimals = quoteDecimals_;
    }

    modifier onlySettlementAuthority() {
        if (msg.sender != settlementAuthority) revert UnauthorizedSettlement(msg.sender);
        _;
    }

    /// @inheritdoc IMarkoutHook
    function getTrade(bytes32 tradeId) external view returns (TradeRecord memory) {
        return _trades[tradeId];
    }

    /// @inheritdoc IMarkoutHook
    function getTradeSettlement(bytes32 tradeId) external view returns (TradeSettlementRecord memory) {
        return _tradeSettlements[tradeId];
    }

    /// @inheritdoc IMarkoutHook
    function claimableRebate(address beneficiary, address currency) external view returns (uint256) {
        return _claimable[beneficiary][currency];
    }

    /// @inheritdoc IMarkoutHook
    function totalClaimableRebate(address currency) external view returns (uint256) {
        return _totalClaimable[currency];
    }

    /// @inheritdoc IMarkoutHook
    function poolPendingSurcharge(bytes32 poolId, address currency) external view returns (uint256) {
        return _poolPending[poolId][currency];
    }

    /// @inheritdoc IMarkoutHook
    function totalPendingSurcharge(address currency) external view returns (uint256) {
        return _totalPending[currency];
    }

    /// @inheritdoc IMarkoutHook
    function lpProtectionReserve(bytes32 poolId, address currency) external view returns (uint256) {
        return _poolReserve[poolId][currency];
    }

    /// @inheritdoc IMarkoutHook
    function totalLpProtectionReserve(address currency) external view returns (uint256) {
        return _totalReserve[currency];
    }

    /// @inheritdoc IMarkoutHook
    function accountedBalance(address currency) public view returns (uint256) {
        return _totalPending[currency] + _totalClaimable[currency] + _totalReserve[currency];
    }

    /// @inheritdoc IMarkoutHook
    function actualBalance(address currency) public view returns (uint256) {
        return Currency.wrap(currency).balanceOf(address(this));
    }

    /// @notice Finalizes a pending trade using an authenticated reference observation.
    function settleTrade(bytes32 tradeId, ReferenceObservation calldata observation)
        external
        override
        onlySettlementAuthority
    {
        TradeRecord storage trade = _requirePendingTrade(tradeId);
        uint64 evaluatedAt = _currentTimestamp();
        ObservationRules memory rules = MarkoutParameters.defaultObservationRules(trade.maturityTimestamp, evaluatedAt);
        MarkoutSettlement memory result = MarkoutSettlementEngine.evaluate(
            trade.escrowedSurcharge,
            trade.executionPriceX18,
            observation,
            trade.direction,
            MarkoutParameters.defaultCurve(),
            rules
        );

        trade.status = TradeStatus.Settled;
        _movePendingToTerminalAllocation(trade, result.retainedSurcharge, result.rebate);
        _tradeSettlements[tradeId] = TradeSettlementRecord({
            markoutWad: result.markoutWad,
            referencePriceX18: observation.priceX18,
            retainedSurcharge: result.retainedSurcharge,
            rebate: result.rebate,
            observedAt: observation.observedAt,
            confidenceBps: observation.confidenceBps,
            retentionBps: result.retentionBps
        });

        emit MarkoutSettled(
            tradeId,
            trade.rebateRecipient,
            trade.currency,
            result.markoutWad,
            result.retentionBps,
            result.retainedSurcharge,
            result.rebate,
            observation.priceX18,
            observation.observedAt,
            observation.confidenceBps
        );
        _assertSolvent(trade.currency);
    }

    /// @inheritdoc IMarkoutHook
    function expireTrade(bytes32 tradeId) external {
        TradeRecord storage trade = _requirePendingTrade(tradeId);
        uint64 currentTimestamp = _currentTimestamp();
        if (!ReferenceObservationValidator.isExpired(
                trade.maturityTimestamp, currentTimestamp, MarkoutParameters.SETTLEMENT_GRACE_PERIOD
            )) {
            revert TradeNotExpired(tradeId, trade.expiryTimestamp, currentTimestamp);
        }

        trade.status = TradeStatus.Expired;
        _movePendingToTerminalAllocation(trade, 0, trade.escrowedSurcharge);
        _tradeSettlements[tradeId] = TradeSettlementRecord({
            markoutWad: 0,
            referencePriceX18: 0,
            retainedSurcharge: 0,
            rebate: trade.escrowedSurcharge,
            observedAt: 0,
            confidenceBps: 0,
            retentionBps: 0
        });

        emit MarkoutExpired(tradeId, trade.rebateRecipient, trade.currency, trade.escrowedSurcharge);
        _assertSolvent(trade.currency);
    }

    /// @inheritdoc IMarkoutHook
    function claimRebate(address currency, address payable recipient) external nonReentrant returns (uint256 amount) {
        if (recipient == address(0)) revert ZeroClaimRecipient();
        amount = _claimRebate(msg.sender, currency, recipient);
    }

    /// @inheritdoc IMarkoutHook
    function claimRebateFor(address beneficiary, address currency) external nonReentrant returns (uint256 amount) {
        amount = _claimRebate(beneficiary, currency, payable(beneficiary));
    }

    /// @dev Shared pull-payment path. Sponsored claims cannot choose or redirect the recipient.
    function _claimRebate(address beneficiary, address currency, address payable recipient)
        private
        returns (uint256 amount)
    {
        amount = _claimable[beneficiary][currency];
        if (amount == 0) revert NoClaimableRebate(beneficiary, currency);

        _claimable[beneficiary][currency] = 0;
        _totalClaimable[currency] -= amount;

        if (currency == address(0)) {
            (bool success,) = recipient.call{ value: amount }("");
            if (!success) revert NativeTransferFailed(recipient, amount);
        } else {
            IERC20(currency).safeTransfer(recipient, amount);
        }

        emit RebateClaimed(beneficiary, currency, recipient, amount);
        _assertSolvent(currency);
    }

    /// @dev Restricts this hook instance to its configured base/quote market.
    function _validateSurchargeContext(SurchargeQuote memory, PoolKey calldata key, BalanceDelta)
        internal
        view
        override
    {
        address currency0 = Currency.unwrap(key.currency0);
        address currency1 = Currency.unwrap(key.currency1);
        bool supported = (currency0 == baseCurrency && currency1 == quoteCurrency)
            || (currency0 == quoteCurrency && currency1 == baseCurrency);
        if (!supported) revert UnsupportedPool(currency0, currency1);
    }

    /// @dev Persists the trade and moves the collected surcharge into pending settlement accounting.
    function _afterSurchargeAccrued(
        SurchargeQuote memory quote,
        PoolKey calldata key,
        BalanceDelta swapDelta,
        uint128 amount
    ) internal override {
        (uint192 executionPriceX18, TradeDirection direction) = _deriveExecution(key, swapDelta);
        _recordPendingTrade(quote, amount, executionPriceX18, direction);
    }

    function _deriveExecution(PoolKey calldata key, BalanceDelta swapDelta)
        private
        view
        returns (uint192 executionPriceX18, TradeDirection direction)
    {
        bool baseIsCurrency0 = Currency.unwrap(key.currency0) == baseCurrency;
        int128 baseDelta = baseIsCurrency0 ? swapDelta.amount0() : swapDelta.amount1();
        int128 quoteDelta = baseIsCurrency0 ? swapDelta.amount1() : swapDelta.amount0();
        executionPriceX18 = PriceNormalization.fromAmounts(
            SwapDeltaAccounting.absolute(baseDelta),
            baseDecimals,
            SwapDeltaAccounting.absolute(quoteDelta),
            quoteDecimals
        );
        direction = baseDelta > 0 ? TradeDirection.BuyBase : TradeDirection.SellBase;
    }

    function _recordPendingTrade(
        SurchargeQuote memory quote,
        uint128 amount,
        uint192 executionPriceX18,
        TradeDirection direction
    ) private {
        uint256 nonce = nextTradeNonce++;
        bytes32 tradeId = keccak256(abi.encode(block.chainid, address(this), PoolId.unwrap(quote.poolId), nonce));
        TradeRecord storage trade = _trades[tradeId];
        trade.poolId = PoolId.unwrap(quote.poolId);
        trade.rebateRecipient = quote.rebateRecipient;
        trade.currency = Currency.unwrap(quote.currency);
        trade.executionPriceX18 = executionPriceX18;
        trade.escrowedSurcharge = amount;
        trade.executedAt = _currentTimestamp();
        trade.maturityTimestamp = MarkoutParameters.maturityTimestamp(trade.executedAt);
        trade.expiryTimestamp = MarkoutParameters.expiryTimestamp(trade.maturityTimestamp);
        trade.direction = direction;
        trade.status = TradeStatus.Pending;

        latestTradeId = tradeId;
        _poolPending[trade.poolId][trade.currency] += amount;
        _totalPending[trade.currency] += amount;

        emit MarkoutRequested(
            tradeId,
            trade.poolId,
            trade.rebateRecipient,
            trade.currency,
            trade.escrowedSurcharge,
            trade.executionPriceX18,
            trade.executedAt,
            trade.maturityTimestamp,
            trade.expiryTimestamp,
            trade.direction
        );
        _assertSolvent(trade.currency);
    }

    function _requirePendingTrade(bytes32 tradeId) private view returns (TradeRecord storage trade) {
        trade = _trades[tradeId];
        if (trade.status == TradeStatus.None) revert UnknownTrade(tradeId);
        if (trade.status != TradeStatus.Pending) {
            revert InvalidTradeStatus(tradeId, trade.status, TradeStatus.Pending);
        }
    }

    function _movePendingToTerminalAllocation(TradeRecord storage trade, uint128 retained, uint128 rebate) private {
        if (uint256(retained) + rebate != trade.escrowedSurcharge) {
            revert InvalidTerminalAllocation(trade.escrowedSurcharge, retained, rebate);
        }
        _poolPending[trade.poolId][trade.currency] -= trade.escrowedSurcharge;
        _totalPending[trade.currency] -= trade.escrowedSurcharge;
        _claimable[trade.rebateRecipient][trade.currency] += rebate;
        _totalClaimable[trade.currency] += rebate;
        _poolReserve[trade.poolId][trade.currency] += retained;
        _totalReserve[trade.currency] += retained;
    }

    function _currentTimestamp() private view returns (uint64 timestamp) {
        // Wall-clock time defines the deliberately delayed markout and expiry windows.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp > type(uint64).max) revert TimestampOutOfRange(block.timestamp);
        // The bound above proves this conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64(block.timestamp);
    }

    function _assertSolvent(address currency) private view {
        uint256 actual = actualBalance(currency);
        uint256 accounted = accountedBalance(currency);
        if (actual < accounted) revert InsolventCurrency(currency, actual, accounted);
    }
}
