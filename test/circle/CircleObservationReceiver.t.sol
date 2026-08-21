// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { CircleObservationReceiver } from "../../src/circle/CircleObservationReceiver.sol";
import { IMarkoutSettlementTarget } from "../../src/interfaces/IMarkoutSettlementTarget.sol";
import { CircleReceiverConfig } from "../../src/types/CircleTypes.sol";
import { ReferenceObservation } from "../../src/types/MarkoutTypes.sol";
import { MockCircleMessageTransmitterV2 } from "../mocks/MockCircleMessageTransmitterV2.sol";

contract CircleSettlementTargetSpy is IMarkoutSettlementTarget {
    bool public rejectSettlement;
    uint256 public calls;
    bytes32 public lastTradeId;
    ReferenceObservation public lastObservation;

    function setRejectSettlement(bool reject) external {
        rejectSettlement = reject;
    }

    function settleTrade(bytes32 tradeId, ReferenceObservation calldata observation) external {
        require(!rejectSettlement, "coordinator rejected");
        ++calls;
        lastTradeId = tradeId;
        lastObservation = observation;
    }
}

contract CircleObservationReceiverTest is Test {
    bytes32 private constant MARKET_ID = keccak256("WETH/USDC");
    bytes32 private constant OTHER_MARKET_ID = keccak256("WBTC/USDC");
    bytes32 private constant TRADE_ID = keccak256("trade");
    uint32 private constant SEPOLIA_DOMAIN = 0;
    address private constant SOURCE_PUBLISHER = address(0x5150);
    address private constant STRANGER = address(0xBAD);

    MockCircleMessageTransmitterV2 private transmitter;
    CircleSettlementTargetSpy private coordinator;
    CircleObservationReceiver private receiver;

    function setUp() public {
        transmitter = new MockCircleMessageTransmitterV2();
        coordinator = new CircleSettlementTargetSpy();
        receiver = new CircleObservationReceiver(_config());
    }

    function test_constructorRejectsInvalidConfiguration() public {
        CircleReceiverConfig memory config = _config();
        config.messageTransmitter = address(0);
        vm.expectRevert(CircleObservationReceiver.ZeroMessageTransmitter.selector);
        new CircleObservationReceiver(config);

        config = _config();
        config.messageTransmitter = address(0xB0B);
        vm.expectRevert(
            abi.encodeWithSelector(CircleObservationReceiver.MessageTransmitterHasNoCode.selector, address(0xB0B))
        );
        new CircleObservationReceiver(config);

        config = _config();
        config.sourcePublisher = address(0);
        vm.expectRevert(CircleObservationReceiver.ZeroSourcePublisher.selector);
        new CircleObservationReceiver(config);

        config = _config();
        config.marketId = bytes32(0);
        vm.expectRevert(CircleObservationReceiver.ZeroMarketId.selector);
        new CircleObservationReceiver(config);

        config = _config();
        config.settlementCoordinator = IMarkoutSettlementTarget(address(0));
        vm.expectRevert(CircleObservationReceiver.ZeroSettlementCoordinator.selector);
        new CircleObservationReceiver(config);

        config = _config();
        config.settlementCoordinator = IMarkoutSettlementTarget(address(0xB0B));
        vm.expectRevert(
            abi.encodeWithSelector(CircleObservationReceiver.SettlementCoordinatorHasNoCode.selector, address(0xB0B))
        );
        new CircleObservationReceiver(config);
    }

    function test_finalizedMessageAuthenticatesAndForwardsExactObservation() public {
        ReferenceObservation memory observation = _observation();
        bytes memory body = abi.encode(uint8(1), MARKET_ID, TRADE_ID, observation);

        vm.prank(address(transmitter));
        vm.expectEmit(true, true, false, true, address(receiver));
        emit CircleObservationReceiver.CircleObservationReceived(
            TRADE_ID, MARKET_ID, observation.priceX18, observation.observedAt, observation.confidenceBps, 2000
        );
        bool success =
            receiver.handleReceiveFinalizedMessage(SEPOLIA_DOMAIN, _addressToBytes32(SOURCE_PUBLISHER), 2000, body);

        assertTrue(success);
        assertEq(coordinator.calls(), 1);
        assertEq(coordinator.lastTradeId(), TRADE_ID);
        (uint192 priceX18, uint64 observedAt, uint16 confidenceBps) = coordinator.lastObservation();
        assertEq(priceX18, observation.priceX18);
        assertEq(observedAt, observation.observedAt);
        assertEq(confidenceBps, observation.confidenceBps);
    }

    function test_onlyConfiguredTransmitterCanDeliver() public {
        vm.prank(STRANGER);
        vm.expectRevert(
            abi.encodeWithSelector(CircleObservationReceiver.UnauthorizedMessageTransmitter.selector, STRANGER)
        );
        receiver.handleReceiveFinalizedMessage(
            SEPOLIA_DOMAIN, _addressToBytes32(SOURCE_PUBLISHER), 2000, _message(1, MARKET_ID, TRADE_ID)
        );
    }

    function test_wrongEnvelopeFieldsAreRejected() public {
        vm.startPrank(address(transmitter));

        vm.expectRevert(
            abi.encodeWithSelector(CircleObservationReceiver.UnexpectedSourceDomain.selector, uint32(6), SEPOLIA_DOMAIN)
        );
        receiver.handleReceiveFinalizedMessage(
            6, _addressToBytes32(SOURCE_PUBLISHER), 2000, _message(1, MARKET_ID, TRADE_ID)
        );

        bytes32 wrongPublisher = _addressToBytes32(address(0x5151));
        vm.expectRevert(
            abi.encodeWithSelector(
                CircleObservationReceiver.UnexpectedSourcePublisher.selector,
                wrongPublisher,
                _addressToBytes32(SOURCE_PUBLISHER)
            )
        );
        receiver.handleReceiveFinalizedMessage(SEPOLIA_DOMAIN, wrongPublisher, 2000, _message(1, MARKET_ID, TRADE_ID));

        vm.expectRevert(
            abi.encodeWithSelector(CircleObservationReceiver.InsufficientFinality.selector, uint32(1999), uint32(2000))
        );
        receiver.handleReceiveFinalizedMessage(
            SEPOLIA_DOMAIN, _addressToBytes32(SOURCE_PUBLISHER), 1999, _message(1, MARKET_ID, TRADE_ID)
        );

        vm.stopPrank();
        assertEq(coordinator.calls(), 0);
    }

    function test_wrongApplicationFieldsAreRejected() public {
        vm.startPrank(address(transmitter));

        vm.expectRevert(
            abi.encodeWithSelector(CircleObservationReceiver.UnsupportedMessageVersion.selector, uint8(2), uint8(1))
        );
        receiver.handleReceiveFinalizedMessage(
            SEPOLIA_DOMAIN, _addressToBytes32(SOURCE_PUBLISHER), 2000, _message(2, MARKET_ID, TRADE_ID)
        );

        vm.expectRevert(
            abi.encodeWithSelector(CircleObservationReceiver.UnexpectedMarket.selector, OTHER_MARKET_ID, MARKET_ID)
        );
        receiver.handleReceiveFinalizedMessage(
            SEPOLIA_DOMAIN, _addressToBytes32(SOURCE_PUBLISHER), 2000, _message(1, OTHER_MARKET_ID, TRADE_ID)
        );

        vm.expectRevert(CircleObservationReceiver.ZeroTradeId.selector);
        receiver.handleReceiveFinalizedMessage(
            SEPOLIA_DOMAIN, _addressToBytes32(SOURCE_PUBLISHER), 2000, _message(1, MARKET_ID, bytes32(0))
        );

        vm.expectRevert();
        receiver.handleReceiveFinalizedMessage(SEPOLIA_DOMAIN, _addressToBytes32(SOURCE_PUBLISHER), 2000, hex"1234");

        vm.stopPrank();
        assertEq(coordinator.calls(), 0);
    }

    function test_fastConfirmedMessageAuthenticatesAndForwardsExactObservation() public {
        ReferenceObservation memory observation = _observation();

        vm.prank(address(transmitter));
        vm.expectEmit(true, true, false, true, address(receiver));
        emit CircleObservationReceiver.CircleObservationReceived(
            TRADE_ID, MARKET_ID, observation.priceX18, observation.observedAt, observation.confidenceBps, 1000
        );
        bool success = receiver.handleReceiveUnfinalizedMessage(
            SEPOLIA_DOMAIN, _addressToBytes32(SOURCE_PUBLISHER), 1000, _message(1, MARKET_ID, TRADE_ID)
        );

        assertTrue(success);
        assertEq(coordinator.calls(), 1);
    }

    function test_unfinalizedHandlerEnforcesDisjointFastFinalityRange() public {
        vm.startPrank(address(transmitter));

        vm.expectRevert(
            abi.encodeWithSelector(CircleObservationReceiver.InsufficientFinality.selector, uint32(999), uint32(1000))
        );
        receiver.handleReceiveUnfinalizedMessage(
            SEPOLIA_DOMAIN, _addressToBytes32(SOURCE_PUBLISHER), 999, _message(1, MARKET_ID, TRADE_ID)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                CircleObservationReceiver.FinalizedMessageInUnfinalizedHandler.selector, uint32(2000)
            )
        );
        receiver.handleReceiveUnfinalizedMessage(
            SEPOLIA_DOMAIN, _addressToBytes32(SOURCE_PUBLISHER), 2000, _message(1, MARKET_ID, TRADE_ID)
        );

        vm.stopPrank();
        assertEq(coordinator.calls(), 0);
    }

    function test_coordinatorRevertPropagatesWithoutSuccessEvent() public {
        coordinator.setRejectSettlement(true);
        vm.prank(address(transmitter));
        vm.expectRevert(bytes("coordinator rejected"));
        receiver.handleReceiveFinalizedMessage(
            SEPOLIA_DOMAIN, _addressToBytes32(SOURCE_PUBLISHER), 2000, _message(1, MARKET_ID, TRADE_ID)
        );
        assertEq(coordinator.calls(), 0);
    }

    function _config() private view returns (CircleReceiverConfig memory config) {
        config = CircleReceiverConfig({
            messageTransmitter: address(transmitter),
            sourceDomain: SEPOLIA_DOMAIN,
            sourcePublisher: SOURCE_PUBLISHER,
            marketId: MARKET_ID,
            settlementCoordinator: coordinator
        });
    }

    function _message(uint8 version, bytes32 marketId, bytes32 tradeId) private pure returns (bytes memory) {
        return abi.encode(version, marketId, tradeId, _observation());
    }

    function _observation() private pure returns (ReferenceObservation memory) {
        return ReferenceObservation({ priceX18: 2000e18, observedAt: 1234, confidenceBps: 9995 });
    }

    function _addressToBytes32(address account) private pure returns (bytes32) {
        return bytes32(uint256(uint160(account)));
    }
}
