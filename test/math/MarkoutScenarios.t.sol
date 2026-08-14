// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { MarkoutSettlement, TradeDirection } from "../../src/types/MarkoutTypes.sol";
import { MarkoutMathHarness } from "../harness/MarkoutMathHarness.sol";

contract MarkoutScenariosTest is Test {
    struct Scenario {
        TradeDirection direction;
        uint192 referencePriceX18;
        int256 expectedMarkoutWad;
        uint16 expectedRetentionBps;
        uint128 expectedRetained;
        uint128 expectedRebate;
    }

    uint192 private constant EXECUTION_PRICE_X18 = 2000e18;
    uint128 private constant ESCROWED_SURCHARGE = 1000;

    MarkoutMathHarness private harness;

    function setUp() public {
        harness = new MarkoutMathHarness();
    }

    function test_deterministicScenarioDataset_matchesSpecification() public view {
        Scenario[8] memory scenarios = [
            Scenario(TradeDirection.BuyBase, 1998e18, -1e15, 0, 0, 1000),
            Scenario(TradeDirection.BuyBase, 2000e18, 0, 2000, 200, 800),
            Scenario(TradeDirection.BuyBase, 2002e18, 1e15, 5200, 520, 480),
            Scenario(TradeDirection.BuyBase, 2006e18, 3e15, 10_000, 1000, 0),
            Scenario(TradeDirection.SellBase, 2002e18, -1e15, 0, 0, 1000),
            Scenario(TradeDirection.SellBase, 2000e18, 0, 2000, 200, 800),
            Scenario(TradeDirection.SellBase, 1998e18, 1e15, 5200, 520, 480),
            Scenario(TradeDirection.SellBase, 1994e18, 3e15, 10_000, 1000, 0)
        ];

        for (uint256 i = 0; i < scenarios.length; ++i) {
            Scenario memory scenario = scenarios[i];
            MarkoutSettlement memory result = harness.settleDefault(
                ESCROWED_SURCHARGE, EXECUTION_PRICE_X18, scenario.referencePriceX18, scenario.direction
            );

            assertEq(result.markoutWad, scenario.expectedMarkoutWad);
            assertEq(result.retentionBps, scenario.expectedRetentionBps);
            assertEq(result.retainedSurcharge, scenario.expectedRetained);
            assertEq(result.rebate, scenario.expectedRebate);
        }
    }
}
