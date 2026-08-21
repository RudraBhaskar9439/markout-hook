// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { ICoordinatedMarkoutTarget } from "../../src/interfaces/ICoordinatedMarkoutTarget.sol";
import { SettlementCoordinator } from "../../src/settlement/SettlementCoordinator.sol";
import { TradeRecord, TradeStatus } from "../../src/types/MarkoutLifecycleTypes.sol";
import { ReferenceObservation, TradeDirection } from "../../src/types/MarkoutTypes.sol";

contract CoordinatorSource { }

contract CoordinatedMarkoutTargetSpy is ICoordinatedMarkoutTarget {
    address public immutable override settlementAuthority;
    bool public rejectSettlement;
    bytes32 public lastTradeId;
    ReferenceObservation public lastObservation;

    mapping(bytes32 tradeId => TradeRecord trade) private _trades;

    constructor(address settlementAuthority_) {
        settlementAuthority = settlementAuthority_;
    }

    function seedTrade(bytes32 tradeId, TradeStatus status) external {
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
            status: status
        });
    }

    function setRejectSettlement(bool reject) external {
        rejectSettlement = reject;
    }

    function getTrade(bytes32 tradeId) external view returns (TradeRecord memory) {
        return _trades[tradeId];
    }

    function settleTrade(bytes32 tradeId, ReferenceObservation calldata observation) external {
        require(msg.sender == settlementAuthority, "unauthorized coordinator");
        require(!rejectSettlement, "invalid observation");
        require(_trades[tradeId].status == TradeStatus.Pending, "not pending");
        _trades[tradeId].status = TradeStatus.Settled;
        lastTradeId = tradeId;
        lastObservation = observation;
    }
}

    contract SettlementCoordinatorTest is Test {
        bytes32 private constant TRADE_ID = keccak256("trade");

        SettlementCoordinator private coordinator;
        CoordinatedMarkoutTargetSpy private target;
        CoordinatorSource private circleSource;
        CoordinatorSource private reactiveSource;

        function setUp() public {
            coordinator = new SettlementCoordinator(address(this));
            target = new CoordinatedMarkoutTargetSpy(address(coordinator));
            circleSource = new CoordinatorSource();
            reactiveSource = new CoordinatorSource();
        }

        function test_constructorRejectsZeroBinder() public {
            vm.expectRevert(SettlementCoordinator.ZeroBinder.selector);
            new SettlementCoordinator(address(0));
        }

        function test_bindTopologyFreezesTargetAndSources() public {
            address[] memory sources = _sources();

            vm.expectEmit(true, false, false, true, address(coordinator));
            emit SettlementCoordinator.TopologyBound(address(target), sources);
            coordinator.bindTopology(target, sources);

            assertEq(address(coordinator.target()), address(target));
            assertEq(coordinator.sourceCount(), 2);
            assertEq(coordinator.sourceAt(0), address(circleSource));
            assertEq(coordinator.sourceAt(1), address(reactiveSource));
            assertTrue(coordinator.isSource(address(circleSource)));
            assertTrue(coordinator.isSource(address(reactiveSource)));

            vm.expectRevert(
                abi.encodeWithSelector(SettlementCoordinator.TopologyAlreadyBound.selector, address(target))
            );
            coordinator.bindTopology(target, sources);
        }

        function test_onlyBinderCanBindTopology() public {
            vm.prank(address(0xBAD));
            vm.expectRevert(abi.encodeWithSelector(SettlementCoordinator.UnauthorizedBinder.selector, address(0xBAD)));
            coordinator.bindTopology(target, _sources());
        }

        function test_bindingRejectsInvalidTopology() public {
            address[] memory empty = new address[](0);
            vm.expectRevert(SettlementCoordinator.EmptySourceSet.selector);
            coordinator.bindTopology(target, empty);

            address[] memory zeroSource = new address[](1);
            vm.expectRevert(abi.encodeWithSelector(SettlementCoordinator.ZeroSource.selector, uint256(0)));
            coordinator.bindTopology(target, zeroSource);

            address[] memory eoaSource = new address[](1);
            eoaSource[0] = address(0xB0B);
            vm.expectRevert(abi.encodeWithSelector(SettlementCoordinator.SourceHasNoCode.selector, address(0xB0B)));
            coordinator.bindTopology(target, eoaSource);

            address[] memory duplicate = new address[](2);
            duplicate[0] = address(circleSource);
            duplicate[1] = address(circleSource);
            vm.expectRevert(
                abi.encodeWithSelector(SettlementCoordinator.DuplicateSource.selector, address(circleSource))
            );
            coordinator.bindTopology(target, duplicate);

            address[] memory tooMany = new address[](coordinator.MAX_SOURCES() + 1);
            for (uint256 i = 0; i < tooMany.length; ++i) {
                tooMany[i] = address(new CoordinatorSource());
            }
            vm.expectRevert(
                abi.encodeWithSelector(
                    SettlementCoordinator.TooManySources.selector, tooMany.length, coordinator.MAX_SOURCES()
                )
            );
            coordinator.bindTopology(target, tooMany);
        }

        function test_bindingRejectsTargetWithDifferentAuthority() public {
            CoordinatedMarkoutTargetSpy wrongTarget = new CoordinatedMarkoutTargetSpy(address(0xBAD));
            vm.expectRevert(
                abi.encodeWithSelector(
                    SettlementCoordinator.TargetAuthorityMismatch.selector, address(0xBAD), address(coordinator)
                )
            );
            coordinator.bindTopology(wrongTarget, _sources());
        }

        function test_unauthorizedSourceCannotSettle() public {
            _bind();
            target.seedTrade(TRADE_ID, TradeStatus.Pending);

            vm.expectRevert(abi.encodeWithSelector(SettlementCoordinator.UnauthorizedSource.selector, address(this)));
            coordinator.settleTrade(TRADE_ID, _observation(2100e18));
        }

        function test_authorizedSourceForwardsPendingTradeExactlyOnce() public {
            _bind();
            target.seedTrade(TRADE_ID, TradeStatus.Pending);
            ReferenceObservation memory observation = _observation(2100e18);

            vm.prank(address(circleSource));
            vm.expectEmit(true, true, false, true, address(coordinator));
            emit SettlementCoordinator.ObservationDeliveryHandled(
                address(circleSource), TRADE_ID, true, TradeStatus.Pending
            );
            coordinator.settleTrade(TRADE_ID, observation);

            assertEq(target.lastTradeId(), TRADE_ID);
            (uint192 priceX18, uint64 observedAt, uint16 confidenceBps) = target.lastObservation();
            assertEq(priceX18, observation.priceX18);
            assertEq(observedAt, observation.observedAt);
            assertEq(confidenceBps, observation.confidenceBps);

            vm.prank(address(reactiveSource));
            vm.expectEmit(true, true, false, true, address(coordinator));
            emit SettlementCoordinator.ObservationDeliveryHandled(
                address(reactiveSource), TRADE_ID, false, TradeStatus.Settled
            );
            coordinator.settleTrade(TRADE_ID, _observation(1900e18));

            (priceX18,,) = target.lastObservation();
            assertEq(priceX18, observation.priceX18);
        }

        function test_expiredTradeDeliveryIsNoOp() public {
            _bind();
            target.seedTrade(TRADE_ID, TradeStatus.Expired);

            vm.prank(address(circleSource));
            vm.expectEmit(true, true, false, true, address(coordinator));
            emit SettlementCoordinator.ObservationDeliveryHandled(
                address(circleSource), TRADE_ID, false, TradeStatus.Expired
            );
            coordinator.settleTrade(TRADE_ID, _observation(2100e18));
        }

        function test_unknownTradeIsRejected() public {
            _bind();
            vm.prank(address(circleSource));
            vm.expectRevert(abi.encodeWithSelector(SettlementCoordinator.UnknownTargetTrade.selector, TRADE_ID));
            coordinator.settleTrade(TRADE_ID, _observation(2100e18));
        }

        function test_targetValidationFailureLeavesTradePendingForAnotherSource() public {
            _bind();
            target.seedTrade(TRADE_ID, TradeStatus.Pending);
            target.setRejectSettlement(true);

            vm.prank(address(circleSource));
            vm.expectRevert(bytes("invalid observation"));
            coordinator.settleTrade(TRADE_ID, _observation(2100e18));

            assertEq(uint8(target.getTrade(TRADE_ID).status), uint8(TradeStatus.Pending));
            target.setRejectSettlement(false);
            vm.prank(address(reactiveSource));
            coordinator.settleTrade(TRADE_ID, _observation(2100e18));
            assertEq(uint8(target.getTrade(TRADE_ID).status), uint8(TradeStatus.Settled));
        }

        function testFuzz_firstAuthorizedDeliveryWins(uint192 firstPriceSeed, uint192 secondPriceSeed) public {
            uint192 firstPrice = uint192(bound(firstPriceSeed, 1, type(uint192).max));
            uint192 secondPrice = uint192(bound(secondPriceSeed, 1, type(uint192).max));
            _bind();
            target.seedTrade(TRADE_ID, TradeStatus.Pending);

            vm.prank(address(circleSource));
            coordinator.settleTrade(TRADE_ID, _observation(firstPrice));
            vm.prank(address(reactiveSource));
            coordinator.settleTrade(TRADE_ID, _observation(secondPrice));

            (uint192 storedPrice,,) = target.lastObservation();
            assertEq(storedPrice, firstPrice);
        }

        function _bind() private {
            coordinator.bindTopology(target, _sources());
        }

        function _sources() private view returns (address[] memory sources) {
            sources = new address[](2);
            sources[0] = address(circleSource);
            sources[1] = address(reactiveSource);
        }

        function _observation(uint192 priceX18) private pure returns (ReferenceObservation memory observation) {
            observation = ReferenceObservation({ priceX18: priceX18, observedAt: 500, confidenceBps: 9900 });
        }
    }
