from __future__ import annotations

import unittest
from pathlib import Path

from markout_experiment.historical import (
    derive_historical_trades,
    evaluate_historical_trades,
    load_historical_config,
    load_historical_swaps,
    quote_price_x18,
    relative_move_centibps,
)


ROOT = Path(__file__).resolve().parents[1]


class HistoricalReplayTest(unittest.TestCase):
    def test_quote_price_is_inverse_to_pool_sqrt_price(self) -> None:
        lower_sqrt = 10**30
        higher_sqrt = 2 * lower_sqrt
        self.assertLessEqual(
            abs(quote_price_x18(lower_sqrt) - 4 * quote_price_x18(higher_sqrt)),
            1,
        )

    def test_relative_move_direction(self) -> None:
        # A smaller future sqrt price means a higher future USDC/WETH quote price.
        self.assertGreater(relative_move_centibps(2 * 10**30, 10**30), 0)
        self.assertLess(relative_move_centibps(10**30, 2 * 10**30), 0)

    def test_committed_window_produces_both_settlement_directions(self) -> None:
        config = load_historical_config(ROOT / "historical/config.json")
        swaps = load_historical_swaps(ROOT / "historical/data/swaps.csv")
        trades = derive_historical_trades(swaps, config)
        self.assertGreaterEqual(len(trades), 100)
        self.assertTrue(any(trade.markout_centibps > 0 for trade in trades))
        self.assertTrue(any(trade.markout_centibps < 0 for trade in trades))
        outcomes = evaluate_historical_trades(trades, config)
        for outcome in outcomes:
            self.assertEqual(
                outcome.upfront_fee_quote_micro,
                outcome.retained_fee_quote_micro + outcome.rebate_quote_micro,
            )


if __name__ == "__main__":
    unittest.main()
