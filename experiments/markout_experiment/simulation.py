"""Seeded synthetic trade-tape construction and policy evaluation."""

from __future__ import annotations

import hashlib
import json
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Any

from .model import FlowClass, PolicyOutcome, ReferenceStatus, Trade
from .policies import evaluate_trade
from .prng import SplitMix64

PRICE_SCALE = 10**18
CENTIBPS_DENOMINATOR = 1_000_000


def load_config(path: Path) -> dict[str, Any]:
    config = json.loads(path.read_text(encoding="utf-8"))
    _validate_config(config)
    return config


def generate_trade_tape(config: Mapping[str, Any]) -> list[Trade]:
    rng = SplitMix64(config["seed"])
    minimum_notional, maximum_notional = config["notionalQuoteRange"]
    minimum_price, maximum_price = config["executionPriceUsdRange"]
    trades: list[Trade] = []

    for scenario in config["scenarios"]:
        flows = scenario["flows"]
        statuses = scenario["referenceStatuses"]
        for trade_index in range(config["tradesPerScenario"]):
            flow_config = _weighted_choice(rng, flows)
            status_config = _weighted_choice(rng, statuses)
            direction = "buy_base" if rng.randbelow(2) == 0 else "sell_base"
            notional_quote_micro = rng.randint(minimum_notional, maximum_notional) * 10**6
            execution_price_x18 = rng.randint(minimum_price, maximum_price) * PRICE_SCALE
            markout_centibps = rng.randint(*flow_config["markoutCentibpsRange"])
            volatility_centibps = rng.randint(*scenario["volatilityCentibpsRange"])
            direction_sign = 1 if direction == "buy_base" else -1
            reference_multiplier = CENTIBPS_DENOMINATOR + direction_sign * markout_centibps
            candidate_reference_price_x18 = execution_price_x18 * reference_multiplier // CENTIBPS_DENOMINATOR
            trade_id = hashlib.sha256(
                f"{config['experimentId']}:{config['seed']}:{scenario['id']}:{trade_index}".encode()
            ).hexdigest()
            trades.append(
                Trade(
                    trade_id=f"0x{trade_id}",
                    seed=config["seed"],
                    scenario_id=scenario["id"],
                    scenario_label=scenario["label"],
                    trade_index=trade_index,
                    flow_class=FlowClass(flow_config["name"]),
                    direction=direction,
                    notional_quote_micro=notional_quote_micro,
                    execution_price_x18=execution_price_x18,
                    candidate_reference_price_x18=candidate_reference_price_x18,
                    markout_centibps=markout_centibps,
                    volatility_centibps=volatility_centibps,
                    reference_status=ReferenceStatus(status_config["name"]),
                )
            )
    return trades


def evaluate_trade_tape(trades: Sequence[Trade], config: Mapping[str, Any]) -> list[PolicyOutcome]:
    return [outcome for trade in trades for outcome in evaluate_trade(trade, config)]


def _weighted_choice(rng: SplitMix64, choices: Sequence[Mapping[str, Any]]) -> Mapping[str, Any]:
    return choices[rng.weighted_index([choice["weight"] for choice in choices])]


def _validate_config(config: Mapping[str, Any]) -> None:
    required = {
        "schemaVersion",
        "experimentId",
        "generatorVersion",
        "seed",
        "tradesPerScenario",
        "currency",
        "notionalQuoteRange",
        "executionPriceUsdRange",
        "policies",
        "scenarios",
    }
    missing = required - config.keys()
    if missing:
        raise ValueError(f"missing configuration keys: {sorted(missing)}")
    if config["schemaVersion"] != 1 or config["tradesPerScenario"] <= 0:
        raise ValueError("unsupported schema or non-positive trade count")
    if config["currency"] != {"symbol": "USDC", "decimals": 6}:
        raise ValueError("version 1 requires quote-denominated USDC micro-units")
    scenario_ids = [scenario["id"] for scenario in config["scenarios"]]
    if len(scenario_ids) != len(set(scenario_ids)):
        raise ValueError("scenario IDs must be unique")
    for scenario in config["scenarios"]:
        if not scenario["flows"] or not scenario["referenceStatuses"]:
            raise ValueError(f"scenario {scenario['id']} has an empty distribution")
        for distribution in (scenario["flows"], scenario["referenceStatuses"]):
            if sum(entry["weight"] for entry in distribution) != 100:
                raise ValueError(f"scenario {scenario['id']} weights must total 100")
