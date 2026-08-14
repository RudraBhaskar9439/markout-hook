// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { LocalMarkoutSettlementAdapter } from "../../src/adapters/LocalMarkoutSettlementAdapter.sol";
import { IMarkoutSettlementTarget } from "../../src/interfaces/IMarkoutSettlementTarget.sol";
import { ReferenceObservation } from "../../src/types/MarkoutTypes.sol";

contract SettlementTargetSpy is IMarkoutSettlementTarget {
    bytes32 public receivedTradeId;
    ReferenceObservation public receivedObservation;
    uint256 public calls;

    function settleTrade(bytes32 tradeId, ReferenceObservation calldata observation) external {
        receivedTradeId = tradeId;
        receivedObservation = observation;
        ++calls;
    }
}

contract LocalMarkoutSettlementAdapterTest is Test {
    address private constant OPERATOR = address(0xA11CE);
    address private constant STRANGER = address(0xBAD);

    LocalMarkoutSettlementAdapter private adapter;
    SettlementTargetSpy private target;

    function setUp() public {
        adapter = new LocalMarkoutSettlementAdapter(OPERATOR);
        target = new SettlementTargetSpy();
    }

    function test_constructorRejectsZeroOperator() public {
        vm.expectRevert(LocalMarkoutSettlementAdapter.ZeroOperator.selector);
        new LocalMarkoutSettlementAdapter(address(0));
    }

    function test_onlyOperatorCanBindTarget() public {
        vm.prank(STRANGER);
        vm.expectRevert(abi.encodeWithSelector(LocalMarkoutSettlementAdapter.UnauthorizedOperator.selector, STRANGER));
        adapter.bindTarget(target);
    }

    function test_zeroTargetCannotBeBound() public {
        vm.prank(OPERATOR);
        vm.expectRevert(LocalMarkoutSettlementAdapter.ZeroTarget.selector);
        adapter.bindTarget(IMarkoutSettlementTarget(address(0)));
    }

    function test_targetCanOnlyBeBoundOnce() public {
        SettlementTargetSpy secondTarget = new SettlementTargetSpy();
        vm.startPrank(OPERATOR);
        adapter.bindTarget(target);
        vm.expectRevert(
            abi.encodeWithSelector(LocalMarkoutSettlementAdapter.TargetAlreadyBound.selector, address(target))
        );
        adapter.bindTarget(secondTarget);
        vm.stopPrank();
    }

    function test_cannotSettleBeforeTargetIsBound() public {
        vm.prank(OPERATOR);
        vm.expectRevert(LocalMarkoutSettlementAdapter.TargetNotBound.selector);
        adapter.settle(bytes32(uint256(1)), _observation());
    }

    function test_onlyOperatorCanForwardSettlement() public {
        vm.prank(OPERATOR);
        adapter.bindTarget(target);

        vm.prank(STRANGER);
        vm.expectRevert(abi.encodeWithSelector(LocalMarkoutSettlementAdapter.UnauthorizedOperator.selector, STRANGER));
        adapter.settle(bytes32(uint256(1)), _observation());
    }

    function test_forwardsTradeAndObservationExactlyOnce() public {
        vm.startPrank(OPERATOR);
        adapter.bindTarget(target);
        bytes32 tradeId = keccak256("trade");
        ReferenceObservation memory observation = _observation();
        adapter.settle(tradeId, observation);
        vm.stopPrank();

        (uint192 priceX18, uint64 observedAt, uint16 confidenceBps) = target.receivedObservation();
        assertEq(target.receivedTradeId(), tradeId);
        assertEq(target.calls(), 1);
        assertEq(priceX18, observation.priceX18);
        assertEq(observedAt, observation.observedAt);
        assertEq(confidenceBps, observation.confidenceBps);
    }

    function _observation() private pure returns (ReferenceObservation memory) {
        return ReferenceObservation({ priceX18: 2000e18, observedAt: 1234, confidenceBps: 9500 });
    }
}
