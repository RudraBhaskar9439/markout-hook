"""Typed domain records shared by the experiment pipeline."""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class FlowClass(str, Enum):
    BENIGN = "benign"
    INFORMED = "informed"
    INVENTORY_IMPROVING = "inventory_improving"


class ReferenceStatus(str, Enum):
    VALID = "valid"
    STALE = "stale"
    MANIPULATED = "manipulated"


class Policy(str, Enum):
    FIXED = "fixed"
    VOLATILITY = "volatility"
    MARKOUT = "markout"


@dataclass(frozen=True, slots=True)
class Trade:
    trade_id: str
    seed: int
    scenario_id: str
    scenario_label: str
    trade_index: int
    flow_class: FlowClass
    direction: str
    notional_quote_micro: int
    execution_price_x18: int
    candidate_reference_price_x18: int
    markout_centibps: int
    volatility_centibps: int
    reference_status: ReferenceStatus


@dataclass(frozen=True, slots=True)
class PolicyOutcome:
    trade: Trade
    policy: Policy
    upfront_fee_quote_micro: int
    retained_fee_quote_micro: int
    rebate_quote_micro: int
    lp_protection_quote_micro: int
    adverse_selection_proxy_quote_micro: int
    lp_net_after_proxy_quote_micro: int
    settlement_status: str
    rejected_reference_attempts: int
    expired_settlements: int
    reactive_callbacks: int
    modeled_callback_gas_budget: int
