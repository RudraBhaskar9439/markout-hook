"""Machine-readable results, judge-readable report, charts, and integrity manifest."""

from __future__ import annotations

import csv
import hashlib
import json
from collections.abc import Mapping, Sequence
from decimal import Decimal
from pathlib import Path
from typing import Any

from .aggregation import (
    build_adoption_evidence,
    csv_ready,
    quote_decimal,
    summarize_all,
    summarize_by_flow,
    summarize_by_scenario,
)
from .charts import grouped_bar_chart
from .model import Policy, PolicyOutcome, Trade


def write_artifacts(
    *,
    trades: Sequence[Trade],
    outcomes: Sequence[PolicyOutcome],
    config: Mapping[str, Any],
    config_path: Path,
    output_root: Path,
    source_root: Path,
) -> None:
    results_dir = output_root / "results"
    charts_dir = output_root / "charts"
    results_dir.mkdir(parents=True, exist_ok=True)
    charts_dir.mkdir(parents=True, exist_ok=True)

    scenario_summary = summarize_by_scenario(outcomes, config)
    flow_summary = summarize_by_flow(outcomes)
    aggregate_summary = summarize_all(outcomes)
    adoption_evidence = build_adoption_evidence(flow_summary, aggregate_summary)
    _write_raw_trades(results_dir / "raw_trades.csv", trades)
    _write_policy_outcomes(results_dir / "policy_outcomes.csv", outcomes)
    _write_summary_csv(results_dir / "summary.csv", scenario_summary)
    _write_summary_csv(results_dir / "flow_summary.csv", flow_summary)
    _write_summary_json(
        results_dir / "summary.json", config, trades, scenario_summary, flow_summary, aggregate_summary
    )
    _write_adoption_json(results_dir / "adoption_summary.json", adoption_evidence)
    _write_report(
        results_dir / "report.md",
        config,
        scenario_summary,
        flow_summary,
        aggregate_summary,
        adoption_evidence,
    )
    _write_charts(charts_dir, config, scenario_summary, flow_summary, adoption_evidence)
    _write_manifest(results_dir / "manifest.json", output_root, config_path, source_root, config)


def _write_raw_trades(destination: Path, trades: Sequence[Trade]) -> None:
    fields = [
        "trade_id",
        "seed",
        "scenario_id",
        "scenario_label",
        "trade_index",
        "flow_class",
        "direction",
        "notional_quote_micro",
        "execution_price_x18",
        "candidate_reference_price_x18",
        "markout_centibps",
        "volatility_centibps",
        "reference_status",
    ]
    with destination.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for trade in trades:
            writer.writerow(
                {
                    "trade_id": trade.trade_id,
                    "seed": trade.seed,
                    "scenario_id": trade.scenario_id,
                    "scenario_label": trade.scenario_label,
                    "trade_index": trade.trade_index,
                    "flow_class": trade.flow_class.value,
                    "direction": trade.direction,
                    "notional_quote_micro": trade.notional_quote_micro,
                    "execution_price_x18": trade.execution_price_x18,
                    "candidate_reference_price_x18": trade.candidate_reference_price_x18,
                    "markout_centibps": trade.markout_centibps,
                    "volatility_centibps": trade.volatility_centibps,
                    "reference_status": trade.reference_status.value,
                }
            )


def _write_policy_outcomes(destination: Path, outcomes: Sequence[PolicyOutcome]) -> None:
    fields = [
        "trade_id",
        "scenario_id",
        "flow_class",
        "reference_status",
        "policy",
        "notional_quote_micro",
        "upfront_fee_quote_micro",
        "retained_fee_quote_micro",
        "rebate_quote_micro",
        "lp_protection_quote_micro",
        "adverse_selection_proxy_quote_micro",
        "lp_net_after_proxy_quote_micro",
        "settlement_status",
        "rejected_reference_attempts",
        "expired_settlements",
        "reactive_callbacks",
        "modeled_callback_gas_budget",
    ]
    with destination.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for outcome in outcomes:
            writer.writerow(
                {
                    "trade_id": outcome.trade.trade_id,
                    "scenario_id": outcome.trade.scenario_id,
                    "flow_class": outcome.trade.flow_class.value,
                    "reference_status": outcome.trade.reference_status.value,
                    "policy": outcome.policy.value,
                    "notional_quote_micro": outcome.trade.notional_quote_micro,
                    "upfront_fee_quote_micro": outcome.upfront_fee_quote_micro,
                    "retained_fee_quote_micro": outcome.retained_fee_quote_micro,
                    "rebate_quote_micro": outcome.rebate_quote_micro,
                    "lp_protection_quote_micro": outcome.lp_protection_quote_micro,
                    "adverse_selection_proxy_quote_micro": outcome.adverse_selection_proxy_quote_micro,
                    "lp_net_after_proxy_quote_micro": outcome.lp_net_after_proxy_quote_micro,
                    "settlement_status": outcome.settlement_status,
                    "rejected_reference_attempts": outcome.rejected_reference_attempts,
                    "expired_settlements": outcome.expired_settlements,
                    "reactive_callbacks": outcome.reactive_callbacks,
                    "modeled_callback_gas_budget": outcome.modeled_callback_gas_budget,
                }
            )


def _write_summary_csv(destination: Path, rows: Sequence[Mapping[str, Any]]) -> None:
    rendered = [csv_ready(row) for row in rows]
    with destination.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rendered[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rendered)


def _write_summary_json(
    destination: Path,
    config: Mapping[str, Any],
    trades: Sequence[Trade],
    scenario_summary: Sequence[Mapping[str, Any]],
    flow_summary: Sequence[Mapping[str, Any]],
    aggregate_summary: Sequence[Mapping[str, Any]],
) -> None:
    payload = {
        "schemaVersion": 1,
        "experimentId": config["experimentId"],
        "generatorVersion": config["generatorVersion"],
        "seed": config["seed"],
        "tradeTapeSha256": _trade_tape_hash(trades),
        "metricBoundary": (
            "notional multiplied by positive directional markout is a pool-level adverse-selection proxy; "
            "it is not exact LVR or an individual LP loss"
        ),
        "aggregate": [_json_ready(row) for row in aggregate_summary],
        "byScenario": [_json_ready(row) for row in scenario_summary],
        "byFlowClass": [_json_ready(row) for row in flow_summary],
        "limitations": _limitations(),
    }
    destination.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _write_adoption_json(destination: Path, evidence: Mapping[str, Any]) -> None:
    destination.write_text(
        json.dumps(_json_ready_nested(evidence), indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def _write_report(
    destination: Path,
    config: Mapping[str, Any],
    scenario_summary: Sequence[Mapping[str, Any]],
    flow_summary: Sequence[Mapping[str, Any]],
    aggregate_summary: Sequence[Mapping[str, Any]],
    adoption_evidence: Mapping[str, Any],
) -> None:
    aggregate = {row["policy"]: row for row in aggregate_summary}
    flow = {(row["policy"], row["flow_class"]): row for row in flow_summary}
    markout = aggregate[Policy.MARKOUT.value]
    fixed = aggregate[Policy.FIXED.value]
    volatility = aggregate[Policy.VOLATILITY.value]
    fixed_benign = flow[(Policy.FIXED.value, "benign")]["average_effective_trader_fee_bps"]
    markout_benign = flow[(Policy.MARKOUT.value, "benign")]["average_effective_trader_fee_bps"]
    volatility_benign = flow[(Policy.VOLATILITY.value, "benign")]["average_effective_trader_fee_bps"]
    markout_inventory = flow[(Policy.MARKOUT.value, "inventory_improving")][
        "average_effective_trader_fee_bps"
    ]
    volatility_inventory = flow[(Policy.VOLATILITY.value, "inventory_improving")][
        "average_effective_trader_fee_bps"
    ]
    fixed_delta = _signed_quote(
        markout["lp_net_after_proxy_quote_micro"] - fixed["lp_net_after_proxy_quote_micro"]
    )
    volatility_delta = _signed_quote(
        markout["lp_net_after_proxy_quote_micro"] - volatility["lp_net_after_proxy_quote_micro"]
    )
    lines = [
        "# MARKOUT Phase 6 Experiment Report",
        "",
        f"Experiment `{config['experimentId']}` uses deterministic SplitMix64 seed `{config['seed']}` and "
        f"{config['tradesPerScenario']} trades per scenario.",
        "",
        "## Metric boundary",
        "",
        "The experiment reports `notional × max(directional markout, 0)` as a pool-level "
        "post-trade adverse-selection proxy. It does **not** call that number exact LVR or an individual LP's loss. "
        "Concentrated-liquidity depth, range occupancy, LP share, price path, and rebalancing are outside this model.",
        "",
        "Fees do not change the gross proxy because every policy receives the same committed trade tape. The "
        "comparison therefore asks how much of that proxy is offset by retained fees, not whether a fee prevents "
        "the underlying price move.",
        "",
        "## Aggregate result",
        "",
        (
            "| Policy | Volume (USDC) | Gross proxy | Retained fees | LP net after proxy | Rebates | "
            "Protection reserve | Avg effective fee (bps) |"
        ),
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in aggregate_summary:
        lines.append(_report_row(row))
    lines.extend(
        [
            "",
            "## Supported observations",
            "",
            (
                f"- MARKOUT changes aggregate LP net-after-proxy by {fixed_delta} USDC versus the fixed-fee "
                "baseline on this tape."
            ),
            (
                f"- MARKOUT changes aggregate LP net-after-proxy by {volatility_delta} USDC versus the "
                "volatility baseline."
            ),
            (
                f"- Benign flow pays {markout_benign:.4f} bps under MARKOUT versus "
                f"{volatility_benign:.4f} bps under the volatility policy."
            ),
            (
                f"- Inventory-improving flow pays {markout_inventory:.4f} bps under MARKOUT versus "
                f"{volatility_inventory:.4f} bps under the volatility policy."
            ),
            (
                f"- MARKOUT returns {quote_decimal(markout['rebate_quote_micro'])} USDC and credits "
                f"{quote_decimal(markout['lp_protection_quote_micro'])} USDC to the modeled protection reserve."
            ),
            (
                f"- The invalid-reference scenario produces {markout['rejected_reference_attempts']} rejected "
                f"observations and {markout['expired_settlements']} full-surcharge expiries."
            ),
            "",
            "## Regressions and costs",
            "",
            (
                f"- The fixed baseline remains cheaper for benign flow: {fixed_benign:.4f} bps versus "
                f"{markout_benign:.4f} bps for MARKOUT."
            ),
            (
                f"- Under the isolated-trade callback assumption, MARKOUT requires "
                f"{markout['reactive_callbacks']} modeled Reactive callbacks with a combined configured gas "
                f"budget of {markout['modeled_callback_gas_budget']:,} units. Fixed and volatility baselines "
                "have no Reactive callback cost in this model."
            ),
            (
                "- Invalid observations fail safely with a full provisional-surcharge rebate, but that also "
                "removes incremental LP protection for those trades."
            ),
            (
                "- All policies receive identical volume because demand elasticity, routing, and fee-sensitive "
                "order flow are deliberately excluded. This experiment cannot claim volume growth."
            ),
            "",
            "## Trader routing break-even",
            "",
            (
                "A trader chooses the best all-in quote, not a fee mechanism in isolation. The table below states "
                "the exact execution-price or slippage advantage MARKOUT would need to offset its fee premium "
                "against a same-liquidity 30 bps pool. It also reports the fee-only saving against the declared "
                "volatility baseline. This is a break-even condition, not a claim that MARKOUT already creates "
                "deeper liquidity."
            ),
            "",
            (
                "| Flow class | Fixed fee | Volatility fee | MARKOUT fee | Execution advantage needed vs fixed | "
                "MARKOUT saving vs volatility per $10k |"
            ),
            "| --- | ---: | ---: | ---: | ---: | ---: |",
        ]
    )
    for row in adoption_evidence["byFlowClass"]:
        saving = row["fee_saving_vs_volatility_per_10000_quote"]
        lines.append(
            f"| {row['flow_class'].replace('_', ' ').title()} | {row['fixed_fee_bps']:.4f} bps | "
            f"{row['volatility_fee_bps']:.4f} bps | {row['markout_fee_bps']:.4f} bps | "
            f"{row['execution_advantage_needed_vs_fixed_bps']:.4f} bps | {saving:+.4f} USDC |"
        )
    adoption_aggregate = adoption_evidence["aggregate"]
    lines.extend(
        [
            "",
            (
                "- On this tape, MARKOUT improves LP net-after-proxy versus fixed by "
                f"{adoption_aggregate['lp_net_improvement_vs_fixed_percent']:.4f}% while requiring benign routes "
                "to recover a 9.4262 bps fee premium through better execution to beat the fixed pool."
            ),
            (
                "- Against volatility pricing at equal execution quality, benign flow saves 10.0528 USDC and "
                "inventory-improving flow saves 17.4403 USDC per 10,000 USDC of notional."
            ),
            (
                "- Informed flow pays more by design. Its negative saving is the mechanism's discrimination result, "
                "not a trader-acquisition claim."
            ),
            "",
            "## Scenario detail",
            "",
            (
                "| Scenario | Policy | Gross proxy | Retained fees | LP net after proxy | "
                "Avg effective fee (bps) | Expired |"
            ),
            "| --- | --- | ---: | ---: | ---: | ---: | ---: |",
        ]
    )
    for row in scenario_summary:
        lines.append(
            f"| {row['scenario_label']} | {row['policy']} | "
            f"{quote_decimal(row['adverse_selection_proxy_quote_micro'])} | "
            f"{quote_decimal(row['retained_fee_quote_micro'])} | "
            f"{quote_decimal(row['lp_net_after_proxy_quote_micro'])} | "
            f"{row['average_effective_trader_fee_bps']:.4f} | {row['expired_settlements']} |"
        )
    lines.extend(["", "## Limitations", ""] + [f"- {limitation}" for limitation in _limitations()])
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_charts(
    charts_dir: Path,
    config: Mapping[str, Any],
    scenario_summary: Sequence[Mapping[str, Any]],
    flow_summary: Sequence[Mapping[str, Any]],
    adoption_evidence: Mapping[str, Any],
) -> None:
    labels = [scenario["label"] for scenario in config["scenarios"]]
    scenario_lookup = {(row["scenario_id"], row["policy"]): row for row in scenario_summary}
    grouped_bar_chart(
        charts_dir / "lp_net_after_proxy.svg",
        title="LP net outcome after adverse-selection proxy",
        subtitle="Same seeded trade tape for every policy; higher is better",
        groups=labels,
        series={
            policy.value: [
                scenario_lookup[(scenario["id"], policy.value)]["lp_net_after_proxy_quote_micro"] / 10**6
                for scenario in config["scenarios"]
            ]
            for policy in Policy
        },
        y_axis_label="USDC",
    )
    flow_lookup = {(row["flow_class"], row["policy"]): row for row in flow_summary}
    flow_classes = ["benign", "informed", "inventory_improving"]
    grouped_bar_chart(
        charts_dir / "effective_fee_by_flow.svg",
        title="Effective trader fee by flow class",
        subtitle="MARKOUT effective fee is measured after rebate",
        groups=[flow.replace("_", " ").title() for flow in flow_classes],
        series={
            policy.value: [
                float(flow_lookup[(flow, policy.value)]["average_effective_trader_fee_bps"])
                for flow in flow_classes
            ]
            for policy in Policy
        },
        y_axis_label="Basis points",
    )
    markout_rows = [row for row in scenario_summary if row["policy"] == Policy.MARKOUT.value]
    grouped_bar_chart(
        charts_dir / "markout_rebate_and_protection.svg",
        title="MARKOUT surcharge allocation",
        subtitle="Rebates plus LP protection conserve every provisional surcharge",
        groups=labels,
        series={
            "rebate": [row["rebate_quote_micro"] / 10**6 for row in markout_rows],
            "protection": [row["lp_protection_quote_micro"] / 10**6 for row in markout_rows],
        },
        y_axis_label="USDC",
    )
    adoption_rows = adoption_evidence["byFlowClass"]
    grouped_bar_chart(
        charts_dir / "trader_routing_break_even.svg",
        title="Trader routing break-even by flow class",
        subtitle="Fee-only threshold; positive savings favor MARKOUT versus volatility",
        groups=[row["flow_class"].replace("_", " ").title() for row in adoption_rows],
        series={
            "needed_vs_fixed": [
                float(row["execution_advantage_needed_vs_fixed_bps"]) for row in adoption_rows
            ],
            "saved_vs_volatility": [
                float(row["fee_saving_vs_volatility_bps"]) for row in adoption_rows
            ],
        },
        y_axis_label="Basis points",
    )


def _write_manifest(
    destination: Path,
    output_root: Path,
    config_path: Path,
    source_root: Path,
    config: Mapping[str, Any],
) -> None:
    source_files = sorted(source_root.glob("*.py"))
    artifact_files = sorted(
        path
        for directory in (output_root / "results", output_root / "charts")
        for path in directory.rglob("*")
        if path.is_file() and path.resolve() != destination.resolve()
    )
    payload = {
        "schemaVersion": 1,
        "experimentId": config["experimentId"],
        "generatorVersion": config["generatorVersion"],
        "seed": config["seed"],
        "inputs": {
            str(config_path.name): _sha256(config_path),
            **{f"markout_experiment/{path.name}": _sha256(path) for path in source_files},
        },
        "artifacts": {str(path.relative_to(output_root)): _sha256(path) for path in artifact_files},
    }
    destination.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _json_ready(row: Mapping[str, Any]) -> dict[str, Any]:
    return {key: format(value, "f") if isinstance(value, Decimal) else value for key, value in row.items()}


def _json_ready_nested(value: Any) -> Any:
    if isinstance(value, Decimal):
        return format(value, "f")
    if isinstance(value, Mapping):
        return {key: _json_ready_nested(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_json_ready_nested(item) for item in value]
    return value


def _trade_tape_hash(trades: Sequence[Trade]) -> str:
    digest = hashlib.sha256()
    for trade in trades:
        digest.update(
            (
                f"{trade.trade_id}|{trade.scenario_id}|{trade.trade_index}|{trade.flow_class.value}|"
                f"{trade.direction}|{trade.notional_quote_micro}|{trade.execution_price_x18}|"
                f"{trade.candidate_reference_price_x18}|{trade.markout_centibps}|"
                f"{trade.volatility_centibps}|{trade.reference_status.value}\n"
            ).encode()
        )
    return digest.hexdigest()


def _report_row(row: Mapping[str, Any]) -> str:
    return (
        f"| {row['policy']} | {quote_decimal(row['volume_quote_micro'])} | "
        f"{quote_decimal(row['adverse_selection_proxy_quote_micro'])} | "
        f"{quote_decimal(row['retained_fee_quote_micro'])} | "
        f"{quote_decimal(row['lp_net_after_proxy_quote_micro'])} | "
        f"{quote_decimal(row['rebate_quote_micro'])} | "
        f"{quote_decimal(row['lp_protection_quote_micro'])} | "
        f"{row['average_effective_trader_fee_bps']:.4f} |"
    )


def _signed_quote(value: int) -> str:
    return f"{value / 10**6:+.6f}"


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _limitations() -> list[str]:
    return [
        "Synthetic seeded flow is a controlled mechanism comparison, not historical backtesting or a forecast.",
        (
            "The adverse-selection proxy approximates value transfer to informed flow; it is not exact LVR or "
            "position-level LP PnL."
        ),
        (
            "No concentrated-liquidity ranges, depth, LP shares, inventory path, rebalancing, routing, or demand "
            "elasticity are modeled."
        ),
        "The volatility policy is a declared deterministic baseline, not a claim that its parameters are optimal.",
        (
            "Callback gas assumes isolated trades with one sample plus one terminal callback; batching can reduce "
            "sampling calls and retries can increase them."
        ),
        "Configured callback gas budgets are not measured public-chain gas spend or lREACT cost.",
        "A three-pool spot median limits one outlier but is not a manipulation-resistant production oracle.",
    ]
