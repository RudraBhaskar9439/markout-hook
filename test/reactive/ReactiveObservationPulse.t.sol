// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ReactiveTest } from "reactive-test-lib/base/ReactiveTest.sol";
import { ReactiveConstants } from "reactive-test-lib/constants/ReactiveConstants.sol";
import { CallbackResult } from "reactive-test-lib/interfaces/IReactiveInterfaces.sol";

import { AuthenticatedReactiveCallback } from "../../src/base/AuthenticatedReactiveCallback.sol";
import { CirclePythObservationPublisher } from "../../src/circle/CirclePythObservationPublisher.sol";
import { ICoordinatedMarkoutTarget } from "../../src/interfaces/ICoordinatedMarkoutTarget.sol";
import { IMarkoutSettlementTarget } from "../../src/interfaces/IMarkoutSettlementTarget.sol";
import { PythPrice } from "../../src/interfaces/IPyth.sol";
import { MarkoutPulseReactive } from "../../src/reactive/MarkoutPulseReactive.sol";
import { ReactiveObservationReceiver } from "../../src/reactive/ReactiveObservationReceiver.sol";
import { SettlementCoordinator } from "../../src/settlement/SettlementCoordinator.sol";
import { CirclePublisherConfig } from "../../src/types/CircleTypes.sol";
import { TradeRecord, TradeStatus } from "../../src/types/MarkoutLifecycleTypes.sol";
import { ReferenceObservation, TradeDirection } from "../../src/types/MarkoutTypes.sol";
import { ReactivePulseConfig } from "../../src/types/ReactivePulseTypes.sol";
import { MockCircleMessageTransmitterV2 } from "../mocks/MockCircleMessageTransmitterV2.sol";
import { MockPyth } from "../mocks/MockPyth.sol";

contract PulseCircleSource { }

contract PulseTargetSpy is ICoordinatedMarkoutTarget {
    address public immutable override settlementAuthority;

    mapping(bytes32 tradeId => TradeRecord trade) private _trades;
    mapping(bytes32 tradeId => ReferenceObservation observation) private _observations;

    constructor(address settlementAuthority_) {
        settlementAuthority = settlementAuthority_;
    }

    function seedTrade(bytes32 tradeId) external {
        _trades[tradeId] = TradeRecord({
            poolId: bytes32(uint256(1)),
            rebateRecipient: address(0xBEEF),
            currency: address(0xCAFE),
            executionPriceX18: 2000e18,
            escrowedSurcharge: 100,
            executedAt: 100,
            maturityTimestamp: 400,
            expiryTimestamp: 1000,
            direction: TradeDirection.BuyBase,
            status: TradeStatus.Pending
        });
    }

    function getTrade(bytes32 tradeId) external view returns (TradeRecord memory) {
        return _trades[tradeId];
    }

    function getObservation(bytes32 tradeId) external view returns (ReferenceObservation memory) {
        return _observations[tradeId];
    }

    function settleTrade(bytes32 tradeId, ReferenceObservation calldata observation) external {
        require(msg.sender == settlementAuthority, "unauthorized coordinator");
        require(_trades[tradeId].status == TradeStatus.Pending, "not pending");
        _trades[tradeId].status = TradeStatus.Settled;
        _observations[tradeId] = observation;
    }
}

    contract ReactiveObservationPulseTest is ReactiveTest {
        uint256 private constant SEPOLIA_CHAIN_ID = 11_155_111;
        uint256 private constant UNICHAIN_SEPOLIA_CHAIN_ID = 1301;
        uint32 private constant UNICHAIN_CIRCLE_DOMAIN = 10;
        bytes32 private constant PRICE_ID = keccak256("ETH/USD-PYTH");
        bytes32 private constant MARKET_ID = keccak256("WETH/USDC");
        bytes32 private constant TRADE_A = keccak256("trade-a");
        bytes32 private constant TRADE_B = keccak256("trade-b");

        MockCircleMessageTransmitterV2 private transmitter;
        MockPyth private pyth;
        CirclePythObservationPublisher private publisher;
        SettlementCoordinator private coordinator;
        PulseTargetSpy private target;
        PulseCircleSource private circleSource;
        ReactiveObservationReceiver private receiver;
        MarkoutPulseReactive private pulse;

        function setUp() public override {
            super.setUp();
            vm.warp(1000);

            transmitter = new MockCircleMessageTransmitterV2();
            pyth = new MockPyth(PRICE_ID);
            coordinator = new SettlementCoordinator(address(this));
            target = new PulseTargetSpy(address(coordinator));
            circleSource = new PulseCircleSource();
            receiver = new ReactiveObservationReceiver(address(proxy), rvmId, MARKET_ID, coordinator);

            address[] memory sources = new address[](2);
            sources[0] = address(circleSource);
            sources[1] = address(receiver);
            coordinator.bindTopology(target, sources);

            publisher = new CirclePythObservationPublisher(
                CirclePublisherConfig({
                    binder: address(this),
                    messageTransmitter: transmitter,
                    pyth: pyth,
                    priceId: PRICE_ID,
                    marketId: MARKET_ID,
                    destinationDomain: UNICHAIN_CIRCLE_DOMAIN,
                    maximumPriceAge: 120
                })
            );
            publisher.bindDestination(address(receiver));

            pulse = new MarkoutPulseReactive(_pulseConfig());
            enableVmMode(address(pulse));
            registerChain(address(publisher), SEPOLIA_CHAIN_ID);
        }

        function test_constructorCreatesOneExactPublisherSubscription() public view {
            assertEq(sys.subscriptionCount(), 1);
            (
                uint256 chainId,
                address contractAddress,
                uint256 topic0,
                uint256 topic1,
                uint256 topic2,
                uint256 topic3,
                address subscriber
            ) = sys.subscriptions(0);

            assertEq(chainId, SEPOLIA_CHAIN_ID);
            assertEq(contractAddress, address(publisher));
            assertEq(topic0, pulse.OBSERVATION_PUBLISHED_TOPIC());
            assertEq(topic1, ReactiveConstants.REACTIVE_IGNORE);
            assertEq(topic2, uint256(MARKET_ID));
            assertEq(topic3, ReactiveConstants.REACTIVE_IGNORE);
            assertEq(subscriber, address(pulse));
        }

        function test_publisherEventProducesOneAuthenticatedExactObservationCallback() public {
            target.seedTrade(TRADE_A);
            _setPythPrice(2050e8);

            CallbackResult[] memory callbacks = triggerAndReact(address(publisher), _publishCall(TRADE_A));

            assertCallbackCount(callbacks, 1);
            assertCallbackSuccess(callbacks, 0);
            assertCallbackEmitted(callbacks, address(receiver));
            assertEq(callbacks[0].chainId, UNICHAIN_SEPOLIA_CHAIN_ID);
            assertEq(callbacks[0].gasLimit, pulse.CALLBACK_GAS_LIMIT());
            assertEq(uint8(target.getTrade(TRADE_A).status), uint8(TradeStatus.Settled));

            ReferenceObservation memory observation = target.getObservation(TRADE_A);
            assertEq(observation.priceX18, 2050e18);
            assertEq(observation.observedAt, 1000);
            assertEq(observation.confidenceBps, 9995);
        }

        function test_circleFirstAndReactiveFirstPreserveTheFirstTerminalObservation() public {
            target.seedTrade(TRADE_A);
            ReferenceObservation memory circleObservation = _observation(2100e18);
            vm.prank(address(circleSource));
            coordinator.settleTrade(TRADE_A, circleObservation);

            _setPythPrice(1900e8);
            CallbackResult[] memory circleFirstCallbacks = triggerAndReact(address(publisher), _publishCall(TRADE_A));
            assertCallbackSuccess(circleFirstCallbacks, 0);
            assertEq(target.getObservation(TRADE_A).priceX18, circleObservation.priceX18);

            target.seedTrade(TRADE_B);
            _setPythPrice(1950e8);
            CallbackResult[] memory reactiveFirstCallbacks = triggerAndReact(address(publisher), _publishCall(TRADE_B));
            assertCallbackSuccess(reactiveFirstCallbacks, 0);
            assertEq(target.getObservation(TRADE_B).priceX18, 1950e18);

            vm.prank(address(circleSource));
            coordinator.settleTrade(TRADE_B, _observation(2200e18));
            assertEq(target.getObservation(TRADE_B).priceX18, 1950e18);
        }

        function test_receiverRejectsUnauthenticatedIdentityWrongMarketAndZeroTrade() public {
            ReferenceObservation memory observation = _observation(2000e18);
            vm.expectRevert(
                abi.encodeWithSelector(AuthenticatedReactiveCallback.UnauthorizedCallbackSender.selector, address(this))
            );
            receiver.receiveObservation(rvmId, MARKET_ID, TRADE_A, observation);

            bytes memory payload = abi.encodeCall(
                ReactiveObservationReceiver.receiveObservation, (address(0), MARKET_ID, TRADE_A, observation)
            );
            (bool success, bytes memory result) =
                proxy.executeCallback(address(receiver), payload, pulse.CALLBACK_GAS_LIMIT(), address(0xBAD));
            assertFalse(success);
            assertEq(
                result,
                abi.encodeWithSelector(
                    AuthenticatedReactiveCallback.UnauthorizedReactiveIdentity.selector, address(0xBAD), rvmId
                )
            );

            payload = abi.encodeCall(
                ReactiveObservationReceiver.receiveObservation, (address(0), keccak256("OTHER"), TRADE_A, observation)
            );
            (success, result) = proxy.executeCallback(address(receiver), payload, pulse.CALLBACK_GAS_LIMIT(), rvmId);
            assertFalse(success);
            assertEq(
                result,
                abi.encodeWithSelector(
                    ReactiveObservationReceiver.UnexpectedMarket.selector, keccak256("OTHER"), MARKET_ID
                )
            );

            payload = abi.encodeCall(
                ReactiveObservationReceiver.receiveObservation, (address(0), MARKET_ID, bytes32(0), observation)
            );
            (success, result) = proxy.executeCallback(address(receiver), payload, pulse.CALLBACK_GAS_LIMIT(), rvmId);
            assertFalse(success);
            assertEq(result, abi.encodeWithSelector(ReactiveObservationReceiver.ZeroTradeId.selector));
        }

        function test_invalidPulseAndReceiverConfigurationReverts() public {
            ReactivePulseConfig memory config = _pulseConfig();
            config.originChainId = 0;
            vm.expectRevert(MarkoutPulseReactive.ZeroChainId.selector);
            new MarkoutPulseReactive(config);

            config = _pulseConfig();
            config.sourcePublisher = address(0);
            vm.expectRevert(MarkoutPulseReactive.ZeroSourcePublisher.selector);
            new MarkoutPulseReactive(config);

            config = _pulseConfig();
            config.destinationReceiver = address(0);
            vm.expectRevert(MarkoutPulseReactive.ZeroDestinationReceiver.selector);
            new MarkoutPulseReactive(config);

            config = _pulseConfig();
            config.marketId = bytes32(0);
            vm.expectRevert(MarkoutPulseReactive.ZeroMarketId.selector);
            new MarkoutPulseReactive(config);

            vm.expectRevert(ReactiveObservationReceiver.ZeroMarketId.selector);
            new ReactiveObservationReceiver(address(proxy), rvmId, bytes32(0), coordinator);

            vm.expectRevert(ReactiveObservationReceiver.ZeroSettlementCoordinator.selector);
            new ReactiveObservationReceiver(address(proxy), rvmId, MARKET_ID, IMarkoutSettlementTarget(address(0)));

            vm.expectRevert(
                abi.encodeWithSelector(
                    ReactiveObservationReceiver.SettlementCoordinatorHasNoCode.selector, address(0xB0B)
                )
            );
            new ReactiveObservationReceiver(address(proxy), rvmId, MARKET_ID, IMarkoutSettlementTarget(address(0xB0B)));
        }

        function _pulseConfig() private view returns (ReactivePulseConfig memory config) {
            config = ReactivePulseConfig({
                originChainId: SEPOLIA_CHAIN_ID,
                destinationChainId: UNICHAIN_SEPOLIA_CHAIN_ID,
                sourcePublisher: address(publisher),
                destinationReceiver: address(receiver),
                marketId: MARKET_ID
            });
        }

        function _publishCall(bytes32 tradeId) private pure returns (bytes memory) {
            bytes[] memory updateData = new bytes[](1);
            updateData[0] = hex"1234";
            return abi.encodeCall(CirclePythObservationPublisher.publish, (tradeId, updateData));
        }

        function _setPythPrice(int64 rawPrice) private {
            // Test inputs are small positive USD prices, so division is safely within uint64.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint64 confidence = uint64(rawPrice / 2000);
            pyth.setPrice(PythPrice({ price: rawPrice, conf: confidence, expo: -8, publishTime: block.timestamp }));
        }

        function _observation(uint192 priceX18) private pure returns (ReferenceObservation memory observation) {
            observation = ReferenceObservation({ priceX18: priceX18, observedAt: 500, confidenceBps: 9995 });
        }
    }
