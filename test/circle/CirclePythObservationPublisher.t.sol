// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { CirclePythObservationPublisher } from "../../src/circle/CirclePythObservationPublisher.sol";
import { PythPrice } from "../../src/interfaces/IPyth.sol";
import { CirclePublisherConfig } from "../../src/types/CircleTypes.sol";
import { ReferenceObservation } from "../../src/types/MarkoutTypes.sol";
import { MockCircleMessageTransmitterV2 } from "../mocks/MockCircleMessageTransmitterV2.sol";
import { MockPyth } from "../mocks/MockPyth.sol";

contract CirclePythObservationPublisherTest is Test {
    bytes32 private constant PRICE_ID = keccak256("ETH/USD-PYTH");
    bytes32 private constant MARKET_ID = keccak256("WETH/USDC");
    bytes32 private constant TRADE_ID = keccak256("trade");
    uint32 private constant UNICHAIN_DOMAIN = 10;
    address private constant DESTINATION_RECEIVER = address(0xD357);
    address private constant STRANGER = address(0xBAD);
    uint256 private constant UPDATE_FEE = 0.01 ether;

    MockCircleMessageTransmitterV2 private transmitter;
    MockPyth private pyth;
    CirclePythObservationPublisher private publisher;

    function setUp() public {
        transmitter = new MockCircleMessageTransmitterV2();
        pyth = new MockPyth(PRICE_ID);
        pyth.setUpdateFee(UPDATE_FEE);
        pyth.setPrice(PythPrice({ price: 2000e8, conf: 1e8, expo: -8, publishTime: 1234 }));
        publisher = new CirclePythObservationPublisher(_config());
        vm.warp(1234);
    }

    function test_constructorRejectsInvalidConfiguration() public {
        CirclePublisherConfig memory config = _config();
        config.binder = address(0);
        vm.expectRevert(CirclePythObservationPublisher.ZeroBinder.selector);
        new CirclePythObservationPublisher(config);

        config = _config();
        config.messageTransmitter = MockCircleMessageTransmitterV2(address(0));
        vm.expectRevert(CirclePythObservationPublisher.ZeroMessageTransmitter.selector);
        new CirclePythObservationPublisher(config);

        config = _config();
        config.messageTransmitter = MockCircleMessageTransmitterV2(address(0xB0B));
        vm.expectRevert(
            abi.encodeWithSelector(CirclePythObservationPublisher.MessageTransmitterHasNoCode.selector, address(0xB0B))
        );
        new CirclePythObservationPublisher(config);

        config = _config();
        config.pyth = MockPyth(address(0));
        vm.expectRevert(CirclePythObservationPublisher.ZeroPyth.selector);
        new CirclePythObservationPublisher(config);

        config = _config();
        config.pyth = MockPyth(address(0xB0B));
        vm.expectRevert(abi.encodeWithSelector(CirclePythObservationPublisher.PythHasNoCode.selector, address(0xB0B)));
        new CirclePythObservationPublisher(config);

        config = _config();
        config.priceId = bytes32(0);
        vm.expectRevert(CirclePythObservationPublisher.ZeroPriceId.selector);
        new CirclePythObservationPublisher(config);

        config = _config();
        config.marketId = bytes32(0);
        vm.expectRevert(CirclePythObservationPublisher.ZeroMarketId.selector);
        new CirclePythObservationPublisher(config);

        config = _config();
        config.destinationDomain = 0;
        vm.expectRevert(CirclePythObservationPublisher.ZeroDestinationDomain.selector);
        new CirclePythObservationPublisher(config);

        config = _config();
        config.maximumPriceAge = 0;
        vm.expectRevert(
            abi.encodeWithSelector(CirclePythObservationPublisher.InvalidMaximumPriceAge.selector, uint64(0))
        );
        new CirclePythObservationPublisher(config);

        config = _config();
        config.maximumPriceAge = 121;
        vm.expectRevert(
            abi.encodeWithSelector(CirclePythObservationPublisher.InvalidMaximumPriceAge.selector, uint64(121))
        );
        new CirclePythObservationPublisher(config);
    }

    function test_destinationBindingIsAuthorizedAndPermanent() public {
        vm.prank(STRANGER);
        vm.expectRevert(abi.encodeWithSelector(CirclePythObservationPublisher.UnauthorizedBinder.selector, STRANGER));
        publisher.bindDestination(DESTINATION_RECEIVER);

        vm.expectRevert(CirclePythObservationPublisher.ZeroDestinationReceiver.selector);
        publisher.bindDestination(address(0));

        vm.expectEmit(true, false, false, true, address(publisher));
        emit CirclePythObservationPublisher.DestinationBound(DESTINATION_RECEIVER);
        publisher.bindDestination(DESTINATION_RECEIVER);
        assertEq(publisher.destinationReceiver(), DESTINATION_RECEIVER);

        vm.expectRevert(
            abi.encodeWithSelector(
                CirclePythObservationPublisher.DestinationAlreadyBound.selector, DESTINATION_RECEIVER
            )
        );
        publisher.bindDestination(address(0xD358));
    }

    function test_publishVerifiesPythAndRequestsFastConfirmedCircleMessage() public {
        publisher.bindDestination(DESTINATION_RECEIVER);
        bytes[] memory updateData = _updateData();

        vm.expectEmit(true, true, false, true, address(publisher));
        emit CirclePythObservationPublisher.ObservationPublished(TRADE_ID, MARKET_ID, 2000e18, 1234, 9995);
        ReferenceObservation memory returned = publisher.publish{ value: UPDATE_FEE }(TRADE_ID, updateData);

        assertEq(returned.priceX18, 2000e18);
        assertEq(returned.observedAt, 1234);
        assertEq(returned.confidenceBps, 9995);
        assertEq(pyth.updateCalls(), 1);
        assertEq(pyth.lastUpdateValue(), UPDATE_FEE);
        assertEq(transmitter.sendCalls(), 1);
        assertEq(transmitter.lastSender(), address(publisher));
        assertEq(transmitter.lastDestinationDomain(), UNICHAIN_DOMAIN);
        assertEq(transmitter.lastRecipient(), bytes32(uint256(uint160(DESTINATION_RECEIVER))));
        assertEq(transmitter.lastDestinationCaller(), bytes32(0));
        assertEq(transmitter.lastMinimumFinalityThreshold(), 1000);

        (uint8 version, bytes32 marketId, bytes32 tradeId, ReferenceObservation memory decoded) =
            abi.decode(transmitter.lastMessageBody(), (uint8, bytes32, bytes32, ReferenceObservation));
        assertEq(version, 1);
        assertEq(marketId, MARKET_ID);
        assertEq(tradeId, TRADE_ID);
        assertEq(decoded.priceX18, returned.priceX18);
        assertEq(decoded.observedAt, returned.observedAt);
        assertEq(decoded.confidenceBps, returned.confidenceBps);
    }

    function test_publishRejectsInvalidRequestBeforeExternalMutation() public {
        bytes[] memory updateData = _updateData();
        vm.expectRevert(CirclePythObservationPublisher.DestinationNotBound.selector);
        publisher.publish{ value: UPDATE_FEE }(TRADE_ID, updateData);

        publisher.bindDestination(DESTINATION_RECEIVER);
        vm.expectRevert(CirclePythObservationPublisher.ZeroTradeId.selector);
        publisher.publish{ value: UPDATE_FEE }(bytes32(0), updateData);

        bytes[] memory empty = new bytes[](0);
        vm.expectRevert(CirclePythObservationPublisher.EmptyUpdateData.selector);
        publisher.publish{ value: UPDATE_FEE }(TRADE_ID, empty);

        vm.expectRevert(
            abi.encodeWithSelector(
                CirclePythObservationPublisher.IncorrectUpdateFee.selector, UPDATE_FEE - 1, UPDATE_FEE
            )
        );
        publisher.publish{ value: UPDATE_FEE - 1 }(TRADE_ID, updateData);

        assertEq(pyth.updateCalls(), 0);
        assertEq(transmitter.sendCalls(), 0);
    }

    function test_stalePythPriceRevertsWithoutCircleMessage() public {
        publisher.bindDestination(DESTINATION_RECEIVER);
        vm.warp(1355);
        vm.expectRevert(
            abi.encodeWithSelector(MockPyth.StalePrice.selector, uint256(1234), uint256(1355), uint256(120))
        );
        publisher.publish{ value: UPDATE_FEE }(TRADE_ID, _updateData());
        assertEq(transmitter.sendCalls(), 0);

        vm.warp(1234);
        pyth.setPrice(PythPrice({ price: 2000e8, conf: 400e8, expo: -8, publishTime: 1234 }));
        vm.expectRevert(
            abi.encodeWithSelector(
                CirclePythObservationPublisher.ConfidenceBelowMinimum.selector, uint16(8000), uint16(9000)
            )
        );
        publisher.publish{ value: UPDATE_FEE }(TRADE_ID, _updateData());
        assertEq(transmitter.sendCalls(), 0);
    }

    function _config() private view returns (CirclePublisherConfig memory config) {
        config = CirclePublisherConfig({
            binder: address(this),
            messageTransmitter: transmitter,
            pyth: pyth,
            priceId: PRICE_ID,
            marketId: MARKET_ID,
            destinationDomain: UNICHAIN_DOMAIN,
            maximumPriceAge: 120
        });
    }

    function _updateData() private pure returns (bytes[] memory updateData) {
        updateData = new bytes[](1);
        updateData[0] = hex"1234";
    }
}
