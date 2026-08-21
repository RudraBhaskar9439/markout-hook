from __future__ import annotations

import sys
import unittest
from pathlib import Path

EXPERIMENT_ROOT = Path(__file__).resolve().parents[1]
if str(EXPERIMENT_ROOT) not in sys.path:
    sys.path.insert(0, str(EXPERIMENT_ROOT))

from markout_experiment.aggregation import build_adoption_evidence, summarize_all, summarize_by_flow
from markout_experiment.model import FlowClass, Policy, ReferenceStatus, Trade
from markout_experiment.policies import evaluate_trade, markout_retention_bps, quote_fee
from markout_experiment.prng import SplitMix64
from markout_experiment.simulation import evaluate_trade_tape, generate_trade_tape, load_config


class SplitMix64Test(unittest.TestCase):
    def test_frozen_reference_sequence(self) -> None:
        generator = SplitMix64(0)
        self.assertEqual(generator.next_u64(), 0xE220A8397B1DCDAF)
        self.assertEqual(generator.next_u64(), 0x6E789E6AA1B965F4)
        self.assertEqual(generator.next_u64(), 0x06C45D188009454F)

    def test_invalid_ranges_fail(self) -> None:
        generator = SplitMix64(1)
        with self.assertRaises(ValueError):
            generator.randbelow(0)
        with self.assertRaises(ValueError):
            generator.randint(2, 1)
        with self.assertRaises(ValueError):
            generator.weighted_index([1, 0])


class PolicyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.config = load_config(EXPERIMENT_ROOT / "config" / "experiment.json")
        cls.markout_policy = cls.config["policies"]["markout"]

    def test_markout_curve_matches_onchain_anchors(self) -> None:
        curve = self.markout_policy["curve"]
        self.assertEqual(markout_retention_bps(-500, curve), 0)
        self.assertEqual(markout_retention_bps(0, curve), 2000)
        self.assertEqual(markout_retention_bps(2500, curve), 10_000)
        self.assertEqual(markout_retention_bps(-250, curve), 1000)
        self.assertEqual(markout_retention_bps(1250, curve), 6000)

    def test_invalid_reference_expires_with_full_surcharge_rebate(self) -> None:
        outcomes = evaluate_trade(self._trade(ReferenceStatus.STALE, markout_centibps=3000), self.config)
        markout = next(outcome for outcome in outcomes if outcome.policy is Policy.MARKOUT)
        self.assertEqual(markout.upfront_fee_quote_micro, 8_000_000)
        self.assertEqual(markout.retained_fee_quote_micro, 3_000_000)
        self.assertEqual(markout.rebate_quote_micro, 5_000_000)
        self.assertEqual(markout.lp_protection_quote_micro, 0)
        self.assertEqual(markout.expired_settlements, 1)
        self.assertEqual(markout.rejected_reference_attempts, 1)
        self.assertEqual(markout.modeled_callback_gas_budget, 800_000)

    def test_adverse_valid_trade_retains_complete_surcharge(self) -> None:
        outcomes = evaluate_trade(self._trade(ReferenceStatus.VALID, markout_centibps=3000), self.config)
        markout = next(outcome for outcome in outcomes if outcome.policy is Policy.MARKOUT)
        self.assertEqual(markout.retained_fee_quote_micro, 8_000_000)
        self.assertEqual(markout.rebate_quote_micro, 0)
        self.assertEqual(markout.lp_protection_quote_micro, 5_000_000)

    def test_quote_fee_uses_integer_flooring(self) -> None:
        self.assertEqual(quote_fee(1_000_001, 3000), 3000)

    @staticmethod
    def _trade(reference_status: ReferenceStatus, *, markout_centibps: int) -> Trade:
        return Trade(
            trade_id="0x01",
            seed=1,
            scenario_id="test",
            scenario_label="Test",
            trade_index=0,
            flow_class=FlowClass.INFORMED,
            direction="buy_base",
            notional_quote_micro=1_000 * 10**6,
            execution_price_x18=2000 * 10**18,
            candidate_reference_price_x18=2006 * 10**18,
            markout_centibps=markout_centibps,
            volatility_centibps=2000,
            reference_status=reference_status,
        )


class ExperimentPipelineTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.config = load_config(EXPERIMENT_ROOT / "config" / "experiment.json")
        cls.trades = generate_trade_tape(cls.config)
        cls.outcomes = evaluate_trade_tape(cls.trades, cls.config)

    def test_trade_tape_is_deterministic_and_complete(self) -> None:
        repeated = generate_trade_tape(self.config)
        self.assertEqual(self.trades, repeated)
        self.assertEqual(len(self.trades), 6 * 128)
        self.assertEqual({trade.scenario_id for trade in self.trades}, {s["id"] for s in self.config["scenarios"]})
        self.assertEqual({trade.flow_class for trade in self.trades}, set(FlowClass))
        self.assertEqual({trade.reference_status for trade in self.trades}, set(ReferenceStatus))

    def test_every_policy_conserves_fees_and_uses_one_common_tape(self) -> None:
        self.assertEqual(len(self.outcomes), len(self.trades) * len(Policy))
        trade_ids_by_policy = {
            policy: [outcome.trade.trade_id for outcome in self.outcomes if outcome.policy is policy]
            for policy in Policy
        }
        self.assertEqual(trade_ids_by_policy[Policy.FIXED], trade_ids_by_policy[Policy.VOLATILITY])
        self.assertEqual(trade_ids_by_policy[Policy.FIXED], trade_ids_by_policy[Policy.MARKOUT])
        for outcome in self.outcomes:
            self.assertEqual(
                outcome.upfront_fee_quote_micro,
                outcome.retained_fee_quote_micro + outcome.rebate_quote_micro,
            )
            self.assertLessEqual(outcome.lp_protection_quote_micro, outcome.retained_fee_quote_micro)
            self.assertGreaterEqual(outcome.adverse_selection_proxy_quote_micro, 0)

    def test_flow_summary_reports_all_policy_flow_pairs(self) -> None:
        rows = summarize_by_flow(self.outcomes)
        self.assertEqual(len(rows), len(Policy) * len(FlowClass))
        self.assertTrue(all(row["trades"] > 0 for row in rows))

    def test_only_markout_uses_rebates_callbacks_and_expiry(self) -> None:
        for outcome in self.outcomes:
            if outcome.policy is not Policy.MARKOUT:
                self.assertEqual(outcome.rebate_quote_micro, 0)
                self.assertEqual(outcome.reactive_callbacks, 0)
                self.assertEqual(outcome.expired_settlements, 0)
            elif outcome.trade.reference_status is ReferenceStatus.VALID:
                self.assertEqual(outcome.expired_settlements, 0)
                self.assertEqual(outcome.reactive_callbacks, 2)
            else:
                self.assertEqual(outcome.rebate_quote_micro, quote_fee(outcome.trade.notional_quote_micro, 5000))
                self.assertEqual(outcome.expired_settlements, 1)

    def test_adoption_evidence_quantifies_fee_only_route_break_even(self) -> None:
        evidence = build_adoption_evidence(summarize_by_flow(self.outcomes), summarize_all(self.outcomes))
        by_flow = {row["flow_class"]: row for row in evidence["byFlowClass"]}

        self.assertEqual(
            format(by_flow["benign"]["execution_advantage_needed_vs_fixed_bps"], ".4f"),
            "9.4262",
        )
        self.assertEqual(
            format(by_flow["benign"]["fee_saving_vs_volatility_bps"], ".4f"),
            "10.0528",
        )
        self.assertEqual(
            format(by_flow["inventory_improving"]["execution_advantage_needed_vs_fixed_bps"], ".4f"),
            "0.0000",
        )
        self.assertLess(by_flow["informed"]["fee_saving_vs_volatility_bps"], 0)
        self.assertEqual(
            format(evidence["aggregate"]["lp_net_improvement_vs_fixed_percent"], ".4f"),
            "83.5638",
        )


if __name__ == "__main__":
    unittest.main()
