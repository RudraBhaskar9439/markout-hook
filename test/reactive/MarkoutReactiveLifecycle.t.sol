// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ReactiveTest } from "reactive-test-lib/base/ReactiveTest.sol";
import { ReactiveConstants } from "reactive-test-lib/constants/ReactiveConstants.sol";
import {
    CallbackResult,
    CronType,
    IReactive as TestReactiveInterface,
    LogRecord as TestLogRecord
} from "reactive-test-lib/interfaces/IReactiveInterfaces.sol";
import { ReactiveSimulator } from "reactive-test-lib/simulator/ReactiveSimulator.sol";

import { console2 } from "forge-std/console2.sol";

import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";

import { ReactiveMarkoutSettlementAdapter } from "../../src/adapters/ReactiveMarkoutSettlementAdapter.sol";
import { MarkoutHook } from "../../src/hooks/MarkoutHook.sol";
import { IMarkoutHook } from "../../src/interfaces/IMarkoutHook.sol";
import { MarkoutParameters } from "../../src/libraries/MarkoutParameters.sol";
import { SurchargeHookData } from "../../src/libraries/SurchargeHookData.sol";
import { MarkoutReactive } from "../../src/reactive/MarkoutReactive.sol";
import { TradeRecord, TradeSettlementRecord, TradeStatus } from "../../src/types/MarkoutLifecycleTypes.sol";
import {
    MarkoutReactiveConfig,
    MarkoutRequestEventData,
    ReactiveReferenceObservation,
    ReactiveTradeRecord,
    ReactiveTradeStatus
} from "../../src/types/MarkoutReactiveTypes.sol";
import { ReferenceObservation } from "../../src/types/MarkoutTypes.sol";
import { SurchargeAuthorization } from "../../src/types/SurchargeTypes.sol";
import { MockNormalizedReferencePriceFeed } from "../mocks/MockNormalizedReferencePriceFeed.sol";

contract MarkoutReactiveLifecycleTest is ReactiveTest, Deployers {
    uint256 private constant ORIGIN_CHAIN_ID = 1301;
    uint256 private constant REFERENCE_CHAIN_ID = 11_155_111;
    uint16 private constant SURCHARGE_BPS = 50;
    uint16 private constant CONFIDENCE_BPS = 9500;
    address private constant REBATE_RECIPIENT = address(0xBEEF);
    bytes32 private constant MARKET_ID = keccak256("ETH/USD");

    MarkoutHook private hook;
    ReactiveMarkoutSettlementAdapter private settlementAdapter;
    MarkoutReactive private reactive;
    MockNormalizedReferencePriceFeed private referenceFeed;
    PoolKey private markoutPoolKey;
    PoolId private markoutPoolId;

    function setUp() public override {
        ReactiveTest.setUp();
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        referenceFeed = new MockNormalizedReferencePriceFeed();
        settlementAdapter = new ReactiveMarkoutSettlementAdapter(address(this), address(proxy), rvmId);

        address hookAddress = _hookAddress(0x4D60);
        deployCodeTo(
            "src/hooks/MarkoutHook.sol:MarkoutHook",
            abi.encode(
                manager,
                SURCHARGE_BPS,
                address(settlementAdapter),
                Currency.unwrap(currency0),
                uint8(18),
                Currency.unwrap(currency1),
                uint8(18)
            ),
            hookAddress
        );
        hook = MarkoutHook(payable(hookAddress));
        settlementAdapter.bindTarget(IMarkoutHook(address(hook)));
        (markoutPoolKey, markoutPoolId) =
            initPoolAndAddLiquidity(currency0, currency1, IHooks(hookAddress), 3000, SQRT_PRICE_1_1);

        reactive = new MarkoutReactive(
            MarkoutReactiveConfig({
                service: address(sys),
                reactiveChainId: reactiveChainId,
                originChainId: ORIGIN_CHAIN_ID,
                destinationChainId: ORIGIN_CHAIN_ID,
                referenceChainId: REFERENCE_CHAIN_ID,
                hook: address(hook),
                settlementAdapter: address(settlementAdapter),
                referenceFeed: address(referenceFeed),
                marketId: MARKET_ID,
                cronTopic: ReactiveConstants.CRON_TOPIC_10
            })
        );

        registerChain(address(referenceFeed), REFERENCE_CHAIN_ID);
        vm.label(address(hook), "MarkoutHook");
        vm.label(address(reactive), "MarkoutReactive");
        vm.label(address(settlementAdapter), "ReactiveSettlementAdapter");
    }

    function test_constructorRegistersFiveNarrowSubscriptions() public view {
        assertEq(sys.subscriptionCount(), 5);
    }

    function test_eventToMaturityToCallback_settlesAndAcknowledgesTrade() public {
        (bytes32 tradeId, TradeRecord memory trade) = _triggerSwap();
        assertEq(uint8(reactive.getTrade(tradeId).status), uint8(ReactiveTradeStatus.Pending));

        vm.warp(trade.maturityTimestamp);
        _publish(trade.executionPriceX18, trade.maturityTimestamp, CONFIDENCE_BPS);
        CallbackResult[] memory callbacks = triggerCron(CronType.Cron10);

        assertCallbackCount(callbacks, 1);
        assertCallbackSuccess(callbacks, 0);
        assertCallbackEmitted(callbacks, address(settlementAdapter));
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Settled));
        TradeSettlementRecord memory allocation = hook.getTradeSettlement(tradeId);
        assertEq(allocation.retentionBps, MarkoutParameters.NEUTRAL_RETENTION_BPS);
        assertEq(uint256(allocation.retainedSurcharge) + allocation.rebate, trade.escrowedSurcharge);
        assertEq(uint8(reactive.getTrade(tradeId).status), uint8(ReactiveTradeStatus.SettlementPendingAcknowledgement));

        _deliverTerminalAcknowledgement(tradeId, false);
        assertEq(uint8(reactive.getTrade(tradeId).status), uint8(ReactiveTradeStatus.Finalized));
        vm.warp(uint256(trade.expiryTimestamp) + 1);
        assertNoCallbacks(triggerCron(CronType.Cron10));
    }

    function test_beforeMaturityNeverSettles() public {
        (bytes32 tradeId, TradeRecord memory trade) = _triggerSwap();
        _publish(trade.executionPriceX18, trade.maturityTimestamp, CONFIDENCE_BPS);

        assertNoCallbacks(triggerCron(CronType.Cron10));
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Pending));

        vm.warp(trade.maturityTimestamp);
        CallbackResult[] memory callbacks = triggerCron(CronType.Cron10);
        assertCallbackCount(callbacks, 1);
        assertCallbackSuccess(callbacks, 0);
    }

    function test_missingObservationTriggersAuthenticatedExpiryAfterGracePeriod() public {
        (bytes32 tradeId, TradeRecord memory trade) = _triggerSwap();
        vm.warp(uint256(trade.expiryTimestamp) + 1);

        CallbackResult[] memory callbacks = triggerCron(CronType.Cron10);

        assertCallbackCount(callbacks, 1);
        assertCallbackSuccess(callbacks, 0);
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Expired));
        assertEq(hook.getTradeSettlement(tradeId).rebate, trade.escrowedSurcharge);
        assertEq(uint8(reactive.getTrade(tradeId).status), uint8(ReactiveTradeStatus.ExpiryPendingAcknowledgement));

        _deliverTerminalAcknowledgement(tradeId, true);
        assertEq(uint8(reactive.getTrade(tradeId).status), uint8(ReactiveTradeStatus.Finalized));
    }

    function test_staleObservationWaitsAndThenExpires() public {
        (bytes32 tradeId, TradeRecord memory trade) = _triggerSwap();
        vm.warp(trade.maturityTimestamp);
        _publish(trade.executionPriceX18, trade.maturityTimestamp, CONFIDENCE_BPS);
        vm.warp(uint256(trade.maturityTimestamp) + MarkoutParameters.MAXIMUM_OBSERVATION_AGE + 1);

        assertNoCallbacks(triggerCron(CronType.Cron10));
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Pending));

        vm.warp(uint256(trade.expiryTimestamp) + 1);
        CallbackResult[] memory callbacks = triggerCron(CronType.Cron10);
        assertCallbackCount(callbacks, 1);
        assertCallbackSuccess(callbacks, 0);
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Expired));
    }

    function test_outOfOrderDuplicateAndLowConfidencePricesCannotReplaceAcceptedObservation() public {
        (, TradeRecord memory trade) = _triggerSwap();
        vm.warp(trade.maturityTimestamp);
        _publish(trade.executionPriceX18, trade.maturityTimestamp, CONFIDENCE_BPS);
        ReactiveReferenceObservation memory accepted = reactive.getLatestReferenceObservation();

        _publish(trade.executionPriceX18 + 1, trade.maturityTimestamp - 1, CONFIDENCE_BPS);
        _publish(trade.executionPriceX18 + 2, trade.maturityTimestamp, CONFIDENCE_BPS);
        _publish(trade.executionPriceX18 + 3, trade.maturityTimestamp + 1, 8999);

        ReactiveReferenceObservation memory current = reactive.getLatestReferenceObservation();
        assertEq(current.priceX18, accepted.priceX18);
        assertEq(current.observedAt, accepted.observedAt);
        assertEq(current.confidenceBps, accepted.confidenceBps);
    }

    function test_duplicateRequestEventIsIdempotent() public {
        (bytes32 tradeId, TradeRecord memory trade) = _triggerSwap();
        assertEq(reactive.tradeCount(), 1);

        _deliverRequest(tradeId, trade);

        assertEq(reactive.tradeCount(), 1);
        assertEq(reactive.tradeIdAt(0), tradeId);
        assertEq(uint8(reactive.getTrade(tradeId).status), uint8(ReactiveTradeStatus.Pending));
    }

    function test_settlementCallbackRetriesUntilAcknowledgedAndRemainsIdempotent() public {
        (bytes32 tradeId, TradeRecord memory trade) = _triggerSwap();
        vm.warp(trade.maturityTimestamp);
        _publish(trade.executionPriceX18, trade.maturityTimestamp, CONFIDENCE_BPS);

        CallbackResult[] memory first = triggerCron(CronType.Cron10);
        assertCallbackSuccess(first, 0);
        uint256 accountedAfterFirst = hook.accountedBalance(trade.currency);

        CallbackResult[] memory retry = triggerCron(CronType.Cron10);
        assertCallbackCount(retry, 1);
        assertCallbackSuccess(retry, 0);
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Settled));
        assertEq(hook.accountedBalance(trade.currency), accountedAfterFirst);

        _deliverTerminalAcknowledgement(tradeId, false);
        assertNoCallbacks(triggerCron(CronType.Cron10));
    }

    function test_callbackAuthenticationRejectsDirectCallerAndWrongReactiveIdentity() public {
        (bytes32 tradeId, TradeRecord memory trade) = _triggerSwap();
        ReferenceObservation memory observation = _neutralObservation(trade);

        vm.expectRevert(
            abi.encodeWithSelector(ReactiveMarkoutSettlementAdapter.UnauthorizedCallbackSender.selector, address(this))
        );
        settlementAdapter.settle(rvmId, tradeId, observation);

        bytes memory payload =
            abi.encodeCall(ReactiveMarkoutSettlementAdapter.settle, (address(0), tradeId, observation));
        (bool success,) =
            proxy.executeCallback(address(settlementAdapter), payload, reactive.CALLBACK_GAS_LIMIT(), address(0xBAD));
        assertFalse(success);
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Pending));
    }

    function test_exactExpiryBoundaryCanStillSettle() public {
        (bytes32 tradeId, TradeRecord memory trade) = _triggerSwap();
        vm.warp(trade.expiryTimestamp);
        _publish(trade.executionPriceX18, trade.expiryTimestamp, CONFIDENCE_BPS);

        CallbackResult[] memory callbacks = triggerCron(CronType.Cron10);
        assertCallbackCount(callbacks, 1);
        assertCallbackSuccess(callbacks, 0);
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Settled));
    }

    function test_futureObservationWaitsUntilItsTimestamp() public {
        (bytes32 tradeId, TradeRecord memory trade) = _triggerSwap();
        uint64 futureObservation = trade.maturityTimestamp + 30;
        _publish(trade.executionPriceX18, futureObservation, CONFIDENCE_BPS);
        vm.warp(trade.maturityTimestamp);

        assertNoCallbacks(triggerCron(CronType.Cron10));
        vm.warp(futureObservation);
        CallbackResult[] memory callbacks = triggerCron(CronType.Cron10);
        assertCallbackSuccess(callbacks, 0);
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Settled));
    }

    function test_onlyConfiguredServiceCanInvokeReact() public {
        TestLogRecord memory log;
        vm.expectRevert(abi.encodeWithSelector(MarkoutReactive.UnauthorizedService.selector, address(this)));
        TestReactiveInterface(address(reactive)).react(log);
    }

    function test_wrongMarketReferenceEventIsNotDelivered() public {
        (, uint64 observedAt,) = reactive.latestReferenceObservation();
        assertEq(observedAt, 0);

        CallbackResult[] memory callbacks = triggerAndReact(
            address(referenceFeed),
            abi.encodeCall(
                MockNormalizedReferencePriceFeed.publish,
                (keccak256("OTHER/MARKET"), uint192(2000e18), uint64(1234), CONFIDENCE_BPS)
            ),
            REFERENCE_CHAIN_ID
        );

        assertNoCallbacks(callbacks);
        (, observedAt,) = reactive.latestReferenceObservation();
        assertEq(observedAt, 0);
    }

    function test_cronBatchIsBoundedAndCursorRevisitsRemainingTrade() public {
        bytes32[] memory tradeIds = new bytes32[](9);
        TradeRecord memory lastTrade;
        for (uint256 i = 0; i < tradeIds.length; ++i) {
            (tradeIds[i], lastTrade) = _triggerSwap(i % 2 == 0, 1e12);
        }
        vm.warp(lastTrade.maturityTimestamp);
        _publish(lastTrade.executionPriceX18, lastTrade.maturityTimestamp, CONFIDENCE_BPS);

        CallbackResult[] memory firstBatch = triggerCron(CronType.Cron10);
        assertCallbackCount(firstBatch, reactive.MAX_TRADES_PER_CRON());
        for (uint256 i = 0; i < firstBatch.length; ++i) {
            assertCallbackSuccess(firstBatch, i);
            _deliverTerminalAcknowledgement(tradeIds[i], false);
        }
        assertEq(uint8(hook.getTrade(tradeIds[8]).status), uint8(TradeStatus.Pending));

        CallbackResult[] memory secondBatch = triggerCron(CronType.Cron10);
        assertCallbackCount(secondBatch, 1);
        assertCallbackSuccess(secondBatch, 0);
        assertEq(uint8(hook.getTrade(tradeIds[8]).status), uint8(TradeStatus.Settled));
    }

    /// @notice Human-readable Phase 4 acceptance trace used by `scripts/run-phase-4-demo.sh`.
    function test_demo_reactiveEventMaturityCallbackAndAcknowledgement() public {
        (bytes32 tradeId, TradeRecord memory trade) = _triggerSwap();
        console2.log("1. MarkoutRequested observed");
        console2.logBytes32(tradeId);
        console2.log("   maturity", trade.maturityTimestamp);
        console2.log("   expiry", trade.expiryTimestamp);

        vm.warp(trade.maturityTimestamp);
        _publish(trade.executionPriceX18, trade.maturityTimestamp, CONFIDENCE_BPS);
        console2.log("2. Reference observation accepted");
        console2.log("   price X18", trade.executionPriceX18);
        console2.log("   observed at", trade.maturityTimestamp);

        CallbackResult[] memory callbacks = triggerCron(CronType.Cron10);
        assertCallbackCount(callbacks, 1);
        assertCallbackSuccess(callbacks, 0);
        console2.log("3. Cron emitted one authenticated callback");
        console2.log("4. Destination trade settled", uint8(hook.getTrade(tradeId).status));

        _deliverTerminalAcknowledgement(tradeId, false);
        assertEq(uint8(reactive.getTrade(tradeId).status), uint8(ReactiveTradeStatus.Finalized));
        console2.log("5. Terminal event acknowledged; Reactive state finalized");
    }

    function test_adapterConstructorAndOneTimeBindingGuards() public {
        vm.expectRevert(ReactiveMarkoutSettlementAdapter.ZeroBinder.selector);
        new ReactiveMarkoutSettlementAdapter(address(0), address(proxy), rvmId);
        vm.expectRevert(ReactiveMarkoutSettlementAdapter.ZeroCallbackSender.selector);
        new ReactiveMarkoutSettlementAdapter(address(this), address(0), rvmId);
        vm.expectRevert(ReactiveMarkoutSettlementAdapter.ZeroReactiveIdentity.selector);
        new ReactiveMarkoutSettlementAdapter(address(this), address(proxy), address(0));

        ReactiveMarkoutSettlementAdapter unbound =
            new ReactiveMarkoutSettlementAdapter(address(this), address(proxy), rvmId);
        vm.expectRevert(ReactiveMarkoutSettlementAdapter.ZeroTarget.selector);
        unbound.bindTarget(IMarkoutHook(address(0)));
        unbound.bindTarget(IMarkoutHook(address(hook)));
        vm.expectRevert(
            abi.encodeWithSelector(ReactiveMarkoutSettlementAdapter.TargetAlreadyBound.selector, address(hook))
        );
        unbound.bindTarget(IMarkoutHook(address(hook)));
    }

    function test_onlyBinderCanBindDestination() public {
        ReactiveMarkoutSettlementAdapter unbound =
            new ReactiveMarkoutSettlementAdapter(address(this), address(proxy), rvmId);
        vm.prank(address(0xBAD));
        vm.expectRevert(
            abi.encodeWithSelector(ReactiveMarkoutSettlementAdapter.UnauthorizedBinder.selector, address(0xBAD))
        );
        unbound.bindTarget(IMarkoutHook(address(hook)));
    }

    function _triggerSwap() private returns (bytes32 tradeId, TradeRecord memory trade) {
        return _triggerSwap(false, 1e15);
    }

    function _triggerSwap(bool zeroForOne, uint128 amount) private returns (bytes32 tradeId, TradeRecord memory trade) {
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(uint256(amount)),
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
        });
        CallbackResult[] memory callbacks = triggerAndReact(
            address(swapRouter),
            abi.encodeCall(
                PoolSwapTest.swap,
                (
                    markoutPoolKey,
                    params,
                    PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
                    _hookData()
                )
            ),
            ORIGIN_CHAIN_ID
        );
        assertNoCallbacks(callbacks);
        tradeId = hook.latestTradeId();
        trade = hook.getTrade(tradeId);
        assertEq(trade.poolId, PoolId.unwrap(markoutPoolId));
    }

    function _publish(uint192 priceX18, uint64 observedAt, uint16 confidenceBps) private {
        CallbackResult[] memory callbacks = triggerAndReact(
            address(referenceFeed),
            abi.encodeCall(MockNormalizedReferencePriceFeed.publish, (MARKET_ID, priceX18, observedAt, confidenceBps)),
            REFERENCE_CHAIN_ID
        );
        assertNoCallbacks(callbacks);
    }

    function _deliverRequest(bytes32 tradeId, TradeRecord memory trade) private {
        MarkoutRequestEventData memory data = MarkoutRequestEventData({
            currency: trade.currency,
            escrowedSurcharge: trade.escrowedSurcharge,
            executionPriceX18: trade.executionPriceX18,
            executedAt: trade.executedAt,
            maturityTimestamp: trade.maturityTimestamp,
            expiryTimestamp: trade.expiryTimestamp,
            direction: trade.direction
        });
        _deliverRaw(
            TestLogRecord({
                chain_id: ORIGIN_CHAIN_ID,
                _contract: address(hook),
                topic_0: reactive.MARKOUT_REQUESTED_TOPIC(),
                topic_1: uint256(tradeId),
                topic_2: 0,
                topic_3: 0,
                data: abi.encode(data),
                block_number: block.number,
                op_code: 0,
                block_hash: 0,
                tx_hash: 0,
                log_index: 0
            })
        );
    }

    function _deliverTerminalAcknowledgement(bytes32 tradeId, bool expired) private {
        _deliverRaw(
            TestLogRecord({
                chain_id: ORIGIN_CHAIN_ID,
                _contract: address(hook),
                topic_0: expired ? reactive.MARKOUT_EXPIRED_TOPIC() : reactive.MARKOUT_SETTLED_TOPIC(),
                topic_1: uint256(tradeId),
                topic_2: 0,
                topic_3: 0,
                data: bytes(""),
                block_number: block.number,
                op_code: 0,
                block_hash: 0,
                tx_hash: 0,
                log_index: 0
            })
        );
    }

    function _deliverRaw(TestLogRecord memory log) private {
        ReactiveSimulator.deliverRawEvent(vm, TestReactiveInterface(address(reactive)), log);
    }

    function _neutralObservation(TradeRecord memory trade)
        private
        pure
        returns (ReferenceObservation memory observation)
    {
        observation = ReferenceObservation({
            priceX18: trade.executionPriceX18, observedAt: trade.maturityTimestamp, confidenceBps: CONFIDENCE_BPS
        });
    }

    function _hookData() private pure returns (bytes memory) {
        return SurchargeHookData.encode(
            SurchargeAuthorization({ rebateRecipient: REBATE_RECIPIENT, maximumAmount: type(uint128).max })
        );
    }

    function _hookAddress(uint16 namespace) private pure returns (address) {
        uint160 flags = Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
        return address(flags | (uint160(namespace) << 144));
    }
}
