#!/usr/bin/env python3
"""Generate deterministic MARKOUT artifacts from the frozen historical event window."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
from typing import Any

from markout_experiment.aggregation import quote_decimal
from markout_experiment.historical import (
    build_historical_summary,
    derive_historical_trades,
    evaluate_historical_trades,
    load_historical_config,
    load_historical_swaps,
)


def write_artifacts(config_path: Path, data_path: Path, output: Path) -> None:
    config = load_historical_config(config_path)
    swaps = load_historical_swaps(data_path)
    trades = derive_historical_trades(swaps, config)
    outcomes = evaluate_historical_trades(trades, config)
    summary = build_historical_summary(swaps, trades, outcomes, config)
    output.mkdir(parents=True, exist_ok=True)

    with (output / "trades.csv").open("w", encoding="utf-8", newline="") as handle:
        fields = [
            "trade_id", "trade_index", "flow_class", "direction", "notional_quote_micro",
            "execution_price_x18", "reference_price_x18", "markout_centibps", "trailing_volatility_centibps",
        ]
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for trade in trades:
            writer.writerow({
                "trade_id": trade.trade_id,
                "trade_index": trade.trade_index,
                "flow_class": trade.flow_class.value,
                "direction": trade.direction,
                "notional_quote_micro": trade.notional_quote_micro,
                "execution_price_x18": trade.execution_price_x18,
                "reference_price_x18": trade.candidate_reference_price_x18,
                "markout_centibps": trade.markout_centibps,
                "trailing_volatility_centibps": trade.volatility_centibps,
            })

    (output / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (output / "report.md").write_text(_report(summary), encoding="utf-8")
    manifest = {
        "schemaVersion": 1,
        "experimentId": config["experimentId"],
        "inputs": {
            str(config_path): _sha256(config_path),
            str(data_path): _sha256(data_path),
        },
        "outputs": {
            path.name: _sha256(path)
            for path in sorted(output.iterdir())
            if path.name != "manifest.json"
        },
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Analyzed {len(trades)} historical trades from {len(swaps)} frozen Swap logs.")


def _report(summary: dict[str, Any]) -> str:
    aggregate = {row["policy"]: row for row in summary["aggregate"]}
    observed = summary["observed"]
    source = summary["source"]
    lines = [
        "# MARKOUT Historical Mainnet Robustness Replay",
        "",
        f"This replay evaluates **{source['eligibleTrades']} real swaps** from the "
        f"[{source['poolLabel']}]({source['poolExplorerUrl']}) pool between Ethereum blocks "
        f"`{source['analysisStartBlock']}` and `{source['analysisEndBlock']}` on June 1, 2024.",
        "",
        "It is separate from the primary 768-trade controlled synthetic experiment. The historical window tests "
        "whether the implementation can ingest canonical swap events and preserve its accounting on observed data; "
        "it is not presented as a representative market backtest.",
        "",
        "## Method",
        "",
        "- Execution proxy: post-swap Uniswap v3 `sqrtPriceX96`.",
        "- Five-minute reference: first pool swap price at or after `t + 300 seconds`.",
        "- Direction: inferred from the signed USDC pool delta.",
        "- Volatility input: absolute five-minute trailing move, with no future observation in the input.",
        "- Outcome buckets: ex-post markout bands used only to describe results.",
        "",
        "## Observed result",
        "",
        "| Policy | Volume (USDC) | Average effective fee | LP net after proxy (USDC) |",
        "| --- | ---: | ---: | ---: |",
    ]
    for policy in ("fixed", "volatility", "markout"):
        row = aggregate[policy]
        lines.append(
            f"| {policy.title()} | {quote_decimal(row['volume_quote_micro'])} | "
            f"{row['average_effective_trader_fee_bps']} bps | "
            f"{quote_decimal(row['lp_net_after_proxy_quote_micro'])} |"
        )
    delta = observed["markoutLpNetDeltaVsFixedPercent"]
    delta_text = "undefined because the fixed denominator is zero" if delta is None else f"{delta}%"
    lines.extend([
        "",
        f"Observed directional markout ranged from **{observed['minimumMarkoutBps']} bps** to "
        f"**{observed['maximumMarkoutBps']} bps**, with a median of **{observed['medianMarkoutBps']} bps**.",
        "",
        f"On this one frozen window, MARKOUT's modeled LP net-after-proxy delta versus fixed was **{delta_text}**. "
        "This value is reported whether positive or negative; it is not an acceptance threshold.",
        "",
        "## Evidence boundary",
        "",
        *[f"- {limitation}" for limitation in summary["limitations"]],
        "",
    ])
    return "\n".join(lines)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    write_artifacts(args.config, args.data, args.output)


if __name__ == "__main__":
    main()
