// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ReactiveTest } from "reactive-test-lib/base/ReactiveTest.sol";
import { CallbackResult } from "reactive-test-lib/interfaces/IReactiveInterfaces.sol";
import { MockSystemContract } from "reactive-test-lib/mock/MockSystemContract.sol";

import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";

import { ReactiveMarkoutSettlementAdapter } from "../../src/adapters/ReactiveMarkoutSettlementAdapter.sol";
import { MarkoutHook } from "../../src/hooks/MarkoutHook.sol";
import { IMarkoutHook } from "../../src/interfaces/IMarkoutHook.sol";
import { SurchargeHookData } from "../../src/libraries/SurchargeHookData.sol";
import { MarkoutReactive } from "../../src/reactive/MarkoutReactive.sol";
import { UniswapV3MedianReferenceSampler } from "../../src/reference/UniswapV3MedianReferenceSampler.sol";
import { TradeRecord, TradeStatus } from "../../src/types/MarkoutLifecycleTypes.sol";
import {
    MarkoutReactiveConfig,
    ReactiveReferenceObservation,
    ReactiveTradeStatus
} from "../../src/types/MarkoutReactiveTypes.sol";
import { UniswapV3MedianSamplerConfig } from "../../src/types/ReferenceSamplerTypes.sol";
import { SurchargeAuthorization } from "../../src/types/SurchargeTypes.sol";
import { MockUniswapV3PoolReference } from "../mocks/MockUniswapV3PoolReference.sol";

contract MockReactiveSystemWithCron is MockSystemContract {
    function emitRawCron(uint256 topic) external {
        uint256 currentBlock = block.number;
        assembly {
            mstore(0, currentBlock)
            log1(0, 0x20, topic)
        }
    }
}

contract MarkoutReactiveAutonomousSamplingTest is ReactiveTest, Deployers {
    uint256 private constant ORIGIN_CHAIN_ID = 1301;
    uint16 private constant SURCHARGE_BPS = 50;
    uint160 private constant Q96 = 1 << 96;
    bytes32 private constant MARKET_ID = keccak256("ETH/USD");
    uint256 private constant CRON_TOPIC_10 = 0x04463f7c1651e6b9774d7f85c85bb94654e3c46ca79b0c16fb16d4183307b687;

    MarkoutHook private hook;
    ReactiveMarkoutSettlementAdapter private settlementAdapter;
    UniswapV3MedianReferenceSampler private sampler;
    MarkoutReactive private reactive;
    PoolKey private poolKey;

    function setUp() public override {
        ReactiveTest.setUp();
        MockReactiveSystemWithCron systemImplementation = new MockReactiveSystemWithCron();
        vm.etch(address(sys), address(systemImplementation).code);

        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        address base = Currency.unwrap(currency0);
        address quote = Currency.unwrap(currency1);
        address[3] memory referencePools;
        for (uint256 i = 0; i < referencePools.length; ++i) {
            referencePools[i] = address(new MockUniswapV3PoolReference(base, quote, Q96, 1_000_000));
        }
        sampler = new UniswapV3MedianReferenceSampler(
            UniswapV3MedianSamplerConfig({
                callbackSender: address(proxy),
                reactiveIdentity: rvmId,
                marketId: MARKET_ID,
                baseToken: base,
                baseDecimals: 18,
                quoteToken: quote,
                quoteDecimals: 18,
                pools: referencePools,
                minimumLiquidity: 1,
                maximumDispersionBps: 1000
            })
        );

        settlementAdapter = new ReactiveMarkoutSettlementAdapter(address(this), address(proxy), rvmId);
        address hookAddress = _hookAddress(0x5A60);
        deployCodeTo(
            "src/hooks/MarkoutHook.sol:MarkoutHook",
            abi.encode(manager, SURCHARGE_BPS, address(settlementAdapter), base, uint8(18), quote, uint8(18)),
            hookAddress
        );
        hook = MarkoutHook(payable(hookAddress));
        settlementAdapter.bindTarget(IMarkoutHook(address(hook)));
        (poolKey,) = initPoolAndAddLiquidity(currency0, currency1, IHooks(hookAddress), 3000, SQRT_PRICE_1_1);

        reactive = new MarkoutReactive(
            MarkoutReactiveConfig({
                service: address(sys),
                reactiveChainId: reactiveChainId,
                originChainId: ORIGIN_CHAIN_ID,
                destinationChainId: ORIGIN_CHAIN_ID,
                referenceChainId: ORIGIN_CHAIN_ID,
                hook: address(hook),
                settlementAdapter: address(settlementAdapter),
                referenceFeed: address(sampler),
                referenceSampler: address(sampler),
                marketId: MARKET_ID,
                cronTopic: CRON_TOPIC_10
            })
        );
    }

    function test_oneCronAutonomouslySamplesMedianSettlesAndAcknowledges() public {
        (bytes32 tradeId, TradeRecord memory trade) = _triggerSwap();
        vm.warp(trade.maturityTimestamp);

        CallbackResult[] memory callbacks = triggerFullCycle(
            address(sys), abi.encodeCall(MockReactiveSystemWithCron.emitRawCron, (CRON_TOPIC_10)), reactiveChainId, 10
        );

        assertCallbackCount(callbacks, 2);
        assertEq(callbacks[0].target, address(sampler));
        assertEq(callbacks[1].target, address(settlementAdapter));
        assertCallbackSuccess(callbacks, 0);
        assertCallbackSuccess(callbacks, 1);
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Settled));
        assertEq(uint8(reactive.getTrade(tradeId).status), uint8(ReactiveTradeStatus.Finalized));
        ReactiveReferenceObservation memory observation = reactive.getLatestReferenceObservation();
        assertEq(observation.priceX18, 1e18);

        CallbackResult[] memory replay = triggerFullCycle(
            address(sys), abi.encodeCall(MockReactiveSystemWithCron.emitRawCron, (CRON_TOPIC_10)), reactiveChainId, 10
        );
        assertNoCallbacks(replay);
    }

    function _triggerSwap() private returns (bytes32 tradeId, TradeRecord memory trade) {
        SwapParams memory params =
            SwapParams({ zeroForOne: false, amountSpecified: -int256(1e15), sqrtPriceLimitX96: MAX_PRICE_LIMIT });
        CallbackResult[] memory callbacks = triggerAndReact(
            address(swapRouter),
            abi.encodeCall(
                PoolSwapTest.swap,
                (
                    poolKey,
                    params,
                    PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
                    SurchargeHookData.encode(
                        SurchargeAuthorization({ rebateRecipient: address(this), maximumAmount: type(uint128).max })
                    )
                )
            ),
            ORIGIN_CHAIN_ID
        );
        assertNoCallbacks(callbacks);
        tradeId = hook.latestTradeId();
        trade = hook.getTrade(tradeId);
    }

    function _hookAddress(uint16 namespace) private pure returns (address) {
        uint160 flags = Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
        return address(flags | (uint160(namespace) << 144));
    }
}
