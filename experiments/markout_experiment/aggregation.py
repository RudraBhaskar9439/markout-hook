"""Integer-first aggregation for reproducible policy comparisons."""

from __future__ import annotations

from collections.abc import Iterable, Mapping, Sequence
from decimal import Decimal, ROUND_HALF_UP
from typing import Any

from .model import FlowClass, Policy, PolicyOutcome

MICRO_PER_QUOTE = 10**6


def quote_decimal(micro_amount: int) -> str:
    sign = "-" if micro_amount < 0 else ""
    absolute = abs(micro_amount)
    return f"{sign}{absolute // MICRO_PER_QUOTE}.{absolute % MICRO_PER_QUOTE:06d}"


def summarize_by_scenario(
    outcomes: Sequence[PolicyOutcome], config: Mapping[str, Any]
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for scenario in config["scenarios"]:
        for policy in Policy:
            selected = (
                outcome
                for outcome in outcomes
                if outcome.trade.scenario_id == scenario["id"] and outcome.policy is policy
            )
            rows.append(
                _summarize(
                    selected,
                    scenario_id=scenario["id"],
                    scenario_label=scenario["label"],
                    policy=policy,
                )
            )
    return rows


def summarize_by_flow(outcomes: Sequence[PolicyOutcome]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for flow_class in FlowClass:
        for policy in Policy:
            selected = (
                outcome
                for outcome in outcomes
                if outcome.trade.flow_class is flow_class and outcome.policy is policy
            )
            rows.append(_summarize(selected, flow_class=flow_class.value, policy=policy))
    return rows


def summarize_all(outcomes: Sequence[PolicyOutcome]) -> list[dict[str, Any]]:
    return [
        _summarize(
            (outcome for outcome in outcomes if outcome.policy is policy),
            policy=policy,
        )
        for policy in Policy
    ]


def build_adoption_evidence(
    flow_summary: Sequence[Mapping[str, Any]], aggregate_summary: Sequence[Mapping[str, Any]]
) -> dict[str, Any]:
    """Derive routing break-evens without assuming that fees create liquidity or volume."""

    aggregate = {row["policy"]: row for row in aggregate_summary}
    by_flow = {(row["policy"], row["flow_class"]): row for row in flow_summary}
    fixed = aggregate[Policy.FIXED.value]
    volatility = aggregate[Policy.VOLATILITY.value]
    markout = aggregate[Policy.MARKOUT.value]

    flow_rows: list[dict[str, Any]] = []
    for flow_class in FlowClass:
        fixed_fee = by_flow[(Policy.FIXED.value, flow_class.value)]["average_effective_trader_fee_bps"]
        volatility_fee = by_flow[(Policy.VOLATILITY.value, flow_class.value)][
            "average_effective_trader_fee_bps"
        ]
        markout_fee = by_flow[(Policy.MARKOUT.value, flow_class.value)][
            "average_effective_trader_fee_bps"
        ]
        premium_vs_fixed = markout_fee - fixed_fee
        saving_vs_volatility = volatility_fee - markout_fee
        flow_rows.append(
            {
                "flow_class": flow_class.value,
                "fixed_fee_bps": fixed_fee,
                "volatility_fee_bps": volatility_fee,
                "markout_fee_bps": markout_fee,
                "fee_premium_vs_fixed_bps": premium_vs_fixed,
                "execution_advantage_needed_vs_fixed_bps": max(premium_vs_fixed, Decimal(0)),
                "fee_saving_vs_volatility_bps": saving_vs_volatility,
                "fee_saving_vs_volatility_percent": _percent(saving_vs_volatility, volatility_fee),
                "fee_saving_vs_volatility_per_10000_quote": saving_vs_volatility,
            }
        )

    return {
        "metricBoundary": (
            "fee-only route break-even: MARKOUT beats a comparator when its execution-price and slippage advantage "
            "exceeds any effective-fee premium; this does not assume or prove additional liquidity"
        ),
        "aggregate": {
            "lp_net_improvement_vs_fixed_quote_micro": (
                markout["lp_net_after_proxy_quote_micro"] - fixed["lp_net_after_proxy_quote_micro"]
            ),
            "lp_net_improvement_vs_fixed_percent": _percent(
                markout["lp_net_after_proxy_quote_micro"] - fixed["lp_net_after_proxy_quote_micro"],
                fixed["lp_net_after_proxy_quote_micro"],
            ),
            "lp_net_gap_vs_volatility_quote_micro": (
                markout["lp_net_after_proxy_quote_micro"] - volatility["lp_net_after_proxy_quote_micro"]
            ),
            "lp_net_gap_vs_volatility_percent": _percent(
                markout["lp_net_after_proxy_quote_micro"]
                - volatility["lp_net_after_proxy_quote_micro"],
                volatility["lp_net_after_proxy_quote_micro"],
            ),
            "average_fee_saving_vs_volatility_bps": (
                volatility["average_effective_trader_fee_bps"]
                - markout["average_effective_trader_fee_bps"]
            ),
            "total_trader_rebates_quote_micro": markout["rebate_quote_micro"],
            "total_lp_protection_quote_micro": markout["lp_protection_quote_micro"],
        },
        "byFlowClass": flow_rows,
    }


def _percent(numerator: int | Decimal, denominator: int | Decimal) -> Decimal:
    if denominator == 0:
        raise ValueError("percentage denominator must be non-zero")
    return (Decimal(numerator) * Decimal(100) / Decimal(denominator)).quantize(
        Decimal("0.0001"), rounding=ROUND_HALF_UP
    )


def csv_ready(summary: Mapping[str, Any]) -> dict[str, Any]:
    rendered = dict(summary)
    for key in (
        "volume_quote_micro",
        "upfront_fee_quote_micro",
        "retained_fee_quote_micro",
        "rebate_quote_micro",
        "lp_protection_quote_micro",
        "adverse_selection_proxy_quote_micro",
        "lp_net_after_proxy_quote_micro",
    ):
        rendered[key.removesuffix("_micro")] = quote_decimal(rendered.pop(key))
    rendered["average_effective_trader_fee_bps"] = format(
        rendered["average_effective_trader_fee_bps"], ".4f"
    )
    return rendered


def _summarize(
    selected: Iterable[PolicyOutcome],
    *,
    policy: Policy,
    scenario_id: str | None = None,
    scenario_label: str | None = None,
    flow_class: str | None = None,
) -> dict[str, Any]:
    rows = list(selected)
    if not rows:
        raise ValueError("cannot summarize an empty policy slice")
    volume = sum(row.trade.notional_quote_micro for row in rows)
    retained = sum(row.retained_fee_quote_micro for row in rows)
    average_fee_bps = (Decimal(retained) * Decimal(10_000) / Decimal(volume)).quantize(
        Decimal("0.0001"), rounding=ROUND_HALF_UP
    )
    summary: dict[str, Any] = {
        "policy": policy.value,
        "trades": len(rows),
        "volume_quote_micro": volume,
        "upfront_fee_quote_micro": sum(row.upfront_fee_quote_micro for row in rows),
        "retained_fee_quote_micro": retained,
        "rebate_quote_micro": sum(row.rebate_quote_micro for row in rows),
        "lp_protection_quote_micro": sum(row.lp_protection_quote_micro for row in rows),
        "adverse_selection_proxy_quote_micro": sum(row.adverse_selection_proxy_quote_micro for row in rows),
        "lp_net_after_proxy_quote_micro": sum(row.lp_net_after_proxy_quote_micro for row in rows),
        "average_effective_trader_fee_bps": average_fee_bps,
        "rejected_reference_attempts": sum(row.rejected_reference_attempts for row in rows),
        "expired_settlements": sum(row.expired_settlements for row in rows),
        "reactive_callbacks": sum(row.reactive_callbacks for row in rows),
        "modeled_callback_gas_budget": sum(row.modeled_callback_gas_budget for row in rows),
    }
    if scenario_id is not None:
        summary = {"scenario_id": scenario_id, "scenario_label": scenario_label, **summary}
    if flow_class is not None:
        summary = {"flow_class": flow_class, **summary}
    return summary
