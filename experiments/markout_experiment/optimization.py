"""Deterministic fee-frontier analysis for the trader-friendly Fair-Flow profile."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from decimal import Decimal, ROUND_HALF_UP
from typing import Any

from .model import FlowClass, Policy, PolicyOutcome, Trade
from .policies import evaluate_markout_policy


def build_fair_flow_sweep(
    trades: Sequence[Trade],
    outcomes: Sequence[PolicyOutcome],
    config: Mapping[str, Any],
) -> dict[str, Any]:
    """Sweep base fees and select the lowest candidate satisfying declared constraints."""

    sweep = config["fairFlowSweep"]
    candidates = sweep["candidateBaseFeeBps"]
    if (
        not candidates
        or any(type(candidate) is not int or candidate < 0 for candidate in candidates)
        or candidates != sorted(set(candidates))
    ):
        raise ValueError("fair-flow candidates must be non-empty, unique, and ascending")

    selected_base = sweep["selectedBaseFeeBps"]
    if selected_base not in candidates:
        raise ValueError("selected fair-flow base must be one of the declared candidates")
    surcharge_centibps = config["policies"]["markout"]["provisionalSurchargeCentibps"]
    if type(surcharge_centibps) is not int or surcharge_centibps < 0 or surcharge_centibps % 100 != 0:
        raise ValueError("fair-flow surcharge must resolve to a whole number of basis points")
    surcharge_bps = surcharge_centibps // 100
    fixed_outcomes = [row for row in outcomes if row.policy is Policy.FIXED]
    fixed_lp_net = sum(row.lp_net_after_proxy_quote_micro for row in fixed_outcomes)
    if fixed_lp_net <= 0:
        raise ValueError("fixed LP net must be positive for the declared improvement constraint")

    rows: list[dict[str, Any]] = []
    for base_fee_bps in candidates:
        policy = dict(config["policies"]["markout"])
        policy["baseFeeCentibps"] = base_fee_bps * 100
        evaluated = [evaluate_markout_policy(trade, policy) for trade in trades]
        lp_net = sum(row.lp_net_after_proxy_quote_micro for row in evaluated)
        lp_improvement = _percent(lp_net - fixed_lp_net, fixed_lp_net)
        benign_fee = _average_effective_fee(evaluated, FlowClass.BENIGN)
        inventory_fee = _average_effective_fee(evaluated, FlowClass.INVENTORY_IMPROVING)
        informed_fee = _average_effective_fee(evaluated, FlowClass.INFORMED)
        eligible = (
            benign_fee <= Decimal(sweep["maximumBenignEffectiveFeeBps"])
            and inventory_fee <= Decimal(sweep["maximumInventoryImprovingEffectiveFeeBps"])
            and lp_improvement >= Decimal(sweep["minimumLpNetImprovementVsFixedPercent"])
        )
        rows.append(
            {
                "base_fee_bps": base_fee_bps,
                "maximum_upfront_fee_bps": base_fee_bps + surcharge_bps,
                "benign_effective_fee_bps": benign_fee,
                "inventory_improving_effective_fee_bps": inventory_fee,
                "informed_effective_fee_bps": informed_fee,
                "lp_net_after_proxy_quote_micro": lp_net,
                "lp_net_improvement_vs_fixed_percent": lp_improvement,
                "eligible": eligible,
                "selected": base_fee_bps == selected_base,
            }
        )

    eligible_bases = [row["base_fee_bps"] for row in rows if row["eligible"]]
    if not eligible_bases:
        raise ValueError("no fair-flow base fee satisfies the declared constraints")
    if selected_base != min(eligible_bases):
        raise ValueError("selected fair-flow base must be the lowest eligible candidate")
    if config["policies"]["markout"]["baseFeeCentibps"] != selected_base * 100:
        raise ValueError("the primary MARKOUT policy must match the selected fair-flow base")

    selected = next(row for row in rows if row["selected"])
    return {
        "schemaVersion": 1,
        "selectionRule": (
            "choose the lowest base fee whose benign and inventory-improving effective fees remain at or below "
            "their declared caps while modeled LP net-after-proxy improves by at least the declared percentage "
            "versus fixed 30 bps"
        ),
        "constraints": {
            "maximum_benign_effective_fee_bps": sweep["maximumBenignEffectiveFeeBps"],
            "maximum_inventory_improving_effective_fee_bps": sweep[
                "maximumInventoryImprovingEffectiveFeeBps"
            ],
            "minimum_lp_net_improvement_vs_fixed_percent": sweep[
                "minimumLpNetImprovementVsFixedPercent"
            ],
        },
        "selected": selected,
        "candidates": rows,
    }


def _average_effective_fee(outcomes: Sequence[PolicyOutcome], flow_class: FlowClass) -> Decimal:
    selected = [row for row in outcomes if row.trade.flow_class is flow_class]
    volume = sum(row.trade.notional_quote_micro for row in selected)
    retained = sum(row.retained_fee_quote_micro for row in selected)
    if volume <= 0:
        raise ValueError(f"no volume for flow class {flow_class.value}")
    return (Decimal(retained) * Decimal(10_000) / Decimal(volume)).quantize(
        Decimal("0.0001"), rounding=ROUND_HALF_UP
    )


def _percent(numerator: int, denominator: int) -> Decimal:
    return (Decimal(numerator) * Decimal(100) / Decimal(denominator)).quantize(
        Decimal("0.0001"), rounding=ROUND_HALF_UP
    )
