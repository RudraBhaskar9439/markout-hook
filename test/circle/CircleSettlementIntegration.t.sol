// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";

import { CircleObservationReceiver } from "../../src/circle/CircleObservationReceiver.sol";
import { CirclePythObservationPublisher } from "../../src/circle/CirclePythObservationPublisher.sol";
import { MarkoutHook } from "../../src/hooks/MarkoutHook.sol";
import { ICoordinatedMarkoutTarget } from "../../src/interfaces/ICoordinatedMarkoutTarget.sol";
import { PythPrice } from "../../src/interfaces/IPyth.sol";
import { ReferenceObservationValidator } from "../../src/libraries/ReferenceObservationValidator.sol";
import { SurchargeHookData } from "../../src/libraries/SurchargeHookData.sol";
import { SettlementCoordinator } from "../../src/settlement/SettlementCoordinator.sol";
import { CirclePublisherConfig, CircleReceiverConfig } from "../../src/types/CircleTypes.sol";
import { TradeRecord, TradeSettlementRecord, TradeStatus } from "../../src/types/MarkoutLifecycleTypes.sol";
import { SurchargeAuthorization } from "../../src/types/SurchargeTypes.sol";
import { MockCircleMessageTransmitterV2 } from "../mocks/MockCircleMessageTransmitterV2.sol";
import { MockPyth } from "../mocks/MockPyth.sol";

contract CircleSettlementIntegrationTest is Test, Deployers {
    bytes32 private constant PRICE_ID = keccak256("ETH/USD-PYTH");
    bytes32 private constant MARKET_ID = keccak256("WETH/USDC");
    uint16 private constant SURCHARGE_BPS = 50;
    uint32 private constant SEPOLIA_DOMAIN = 0;
    uint32 private constant UNICHAIN_DOMAIN = 10;
    address private constant REBATE_RECIPIENT = address(0xBEEF);

    MockCircleMessageTransmitterV2 private transmitter;
    MockPyth private pyth;
    SettlementCoordinator private coordinator;
    CirclePythObservationPublisher private publisher;
    CircleObservationReceiver private receiver;
    MarkoutHook private hook;
    PoolKey private poolKey;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        transmitter = new MockCircleMessageTransmitterV2();
        pyth = new MockPyth(PRICE_ID);
        coordinator = new SettlementCoordinator(address(this));
        publisher = new CirclePythObservationPublisher(
            CirclePublisherConfig({
                binder: address(this),
                messageTransmitter: transmitter,
                pyth: pyth,
                priceId: PRICE_ID,
                marketId: MARKET_ID,
                destinationDomain: UNICHAIN_DOMAIN,
                maximumPriceAge: 120
            })
        );
        receiver = new CircleObservationReceiver(
            CircleReceiverConfig({
                messageTransmitter: address(transmitter),
                sourceDomain: SEPOLIA_DOMAIN,
                sourcePublisher: address(publisher),
                marketId: MARKET_ID,
                settlementCoordinator: coordinator
            })
        );
        publisher.bindDestination(address(receiver));

        address hookAddress = _hookAddress(0xC1C1);
        deployCodeTo(
            "src/hooks/MarkoutHook.sol:MarkoutHook",
            abi.encode(
                manager,
                SURCHARGE_BPS,
                address(coordinator),
                Currency.unwrap(currency0),
                uint8(18),
                Currency.unwrap(currency1),
                uint8(18)
            ),
            hookAddress
        );
        hook = MarkoutHook(payable(hookAddress));

        address[] memory sources = new address[](1);
        sources[0] = address(receiver);
        coordinator.bindTopology(ICoordinatedMarkoutTarget(address(hook)), sources);

        (poolKey,) = initPoolAndAddLiquidity(currency0, currency1, IHooks(hookAddress), 3000, SQRT_PRICE_1_1);
    }

    function test_pythToCircleToCoordinatorSettlesRealMarkoutTrade() public {
        (bytes32 tradeId, TradeRecord memory trade) = _executeSwap();
        vm.warp(trade.maturityTimestamp);
        _configurePythAtExecutionPrice(trade);

        publisher.publish(tradeId, _updateData());
        assertEq(transmitter.lastSender(), address(publisher));
        assertEq(transmitter.lastRecipient(), bytes32(uint256(uint160(address(receiver)))));

        bool delivered = transmitter.relayUnfinalized(receiver, SEPOLIA_DOMAIN, 1000);
        assertTrue(delivered);

        TradeRecord memory settledTrade = hook.getTrade(tradeId);
        TradeSettlementRecord memory settlement = hook.getTradeSettlement(tradeId);
        assertEq(uint8(settledTrade.status), uint8(TradeStatus.Settled));
        assertEq(uint256(settlement.retainedSurcharge) + settlement.rebate, trade.escrowedSurcharge);
        assertEq(hook.totalPendingSurcharge(trade.currency), 0);
        assertEq(hook.accountedBalance(trade.currency), hook.actualBalance(trade.currency));

        // MARKOUT remains idempotent even if an alternate transport later carries the same observation.
        assertTrue(transmitter.relayUnfinalized(receiver, SEPOLIA_DOMAIN, 1000));
        TradeSettlementRecord memory afterDuplicate = hook.getTradeSettlement(tradeId);
        assertEq(afterDuplicate.retainedSurcharge, settlement.retainedSurcharge);
        assertEq(afterDuplicate.rebate, settlement.rebate);
    }

    function test_invalidCircleObservationDoesNotConsumeTradeAndValidRetrySettles() public {
        (bytes32 tradeId, TradeRecord memory trade) = _executeSwap();

        uint64 tooEarly = trade.maturityTimestamp - 1;
        vm.warp(trade.maturityTimestamp);
        _setPythPrice(trade, tooEarly);
        publisher.publish(tradeId, _updateData());

        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceObservationValidator.ObservationBeforeMaturity.selector, tooEarly, trade.maturityTimestamp
            )
        );
        transmitter.relayUnfinalized(receiver, SEPOLIA_DOMAIN, 1000);
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Pending));

        _configurePythAtExecutionPrice(trade);
        publisher.publish(tradeId, _updateData());
        assertTrue(transmitter.relayUnfinalized(receiver, SEPOLIA_DOMAIN, 1000));
        assertEq(uint8(hook.getTrade(tradeId).status), uint8(TradeStatus.Settled));
    }

    function _executeSwap() private returns (bytes32 tradeId, TradeRecord memory trade) {
        swapRouter.swap(
            poolKey,
            SwapParams({ zeroForOne: true, amountSpecified: -int256(1 ether), sqrtPriceLimitX96: MIN_PRICE_LIMIT }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            SurchargeHookData.encode(
                SurchargeAuthorization({ rebateRecipient: REBATE_RECIPIENT, maximumAmount: type(uint128).max })
            )
        );
        tradeId = hook.latestTradeId();
        trade = hook.getTrade(tradeId);
        assertEq(uint8(trade.status), uint8(TradeStatus.Pending));
    }

    function _configurePythAtExecutionPrice(TradeRecord memory trade) private {
        _setPythPrice(trade, trade.maturityTimestamp);
    }

    function _setPythPrice(TradeRecord memory trade, uint64 publishTime) private {
        uint256 rawPrice = uint256(trade.executionPriceX18) / 1e10;
        assertLe(rawPrice, uint256(uint64(type(int64).max)));
        // The assertion above and positive execution price prove both conversions are safe.
        // forge-lint: disable-next-line(unsafe-typecast)
        int64 price = int64(uint64(rawPrice));
        // A 5 bps relative confidence interval produces normalized confidence of 9_995 bps.
        uint64 conf = uint64(rawPrice / 2000);
        pyth.setPrice(PythPrice({ price: price, conf: conf, expo: -8, publishTime: publishTime }));
    }

    function _updateData() private pure returns (bytes[] memory updateData) {
        updateData = new bytes[](1);
        updateData[0] = hex"1234";
    }

    function _hookAddress(uint16 namespace) private pure returns (address) {
        uint160 flags = Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
        return address(flags | (uint160(namespace) << 144));
    }
}
