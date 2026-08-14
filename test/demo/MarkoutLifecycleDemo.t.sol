// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console2 } from "forge-std/console2.sol";

import { TradeRecord, TradeSettlementRecord } from "../../src/types/MarkoutLifecycleTypes.sol";
import { MarkoutTestFixture } from "../fixtures/MarkoutTestFixture.sol";

/// @notice Human-readable Phase 3 acceptance scenario used by `scripts/run-phase-3-demo.sh`.
contract MarkoutLifecycleDemoTest is MarkoutTestFixture {
    function setUp() public {
        _setUpMarkout();
    }

    function test_demo_twoTradesReceiveDifferentOutcomeBasedRebates() public {
        (bytes32 neutralId, TradeRecord memory neutralTrade) = _executeSwap(false, true, 1e15);
        (bytes32 toxicId, TradeRecord memory toxicTrade) = _executeSwap(false, true, 1e15);

        _settleNeutral(neutralId);
        uint192 toxicReferencePriceX18 = _settleToxic(toxicId);

        TradeSettlementRecord memory neutral = hook.getTradeSettlement(neutralId);
        TradeSettlementRecord memory toxic = hook.getTradeSettlement(toxicId);

        console2.log("Neutral trade");
        console2.logBytes32(neutralId);
        console2.log("  escrow", neutralTrade.escrowedSurcharge);
        console2.log("  execution price X18", neutralTrade.executionPriceX18);
        console2.log("  reference price X18", neutral.referencePriceX18);
        console2.log("  retained", neutral.retainedSurcharge);
        console2.log("  rebate", neutral.rebate);

        console2.log("Toxic trade");
        console2.logBytes32(toxicId);
        console2.log("  escrow", toxicTrade.escrowedSurcharge);
        console2.log("  execution price X18", toxicTrade.executionPriceX18);
        console2.log("  reference price X18", toxicReferencePriceX18);
        console2.log("  retained", toxic.retainedSurcharge);
        console2.log("  rebate", toxic.rebate);

        console2.log("Hook balance", hook.actualBalance(neutralTrade.currency));
        console2.log("Pending", hook.totalPendingSurcharge(neutralTrade.currency));
        console2.log("Claimable", hook.totalClaimableRebate(neutralTrade.currency));
        console2.log("LP protection reserve", hook.totalLpProtectionReserve(neutralTrade.currency));

        assertGt(neutral.rebate, toxic.rebate, "neutral flow must receive the larger rebate");
        assertEq(hook.actualBalance(neutralTrade.currency), hook.accountedBalance(neutralTrade.currency));
    }
}
