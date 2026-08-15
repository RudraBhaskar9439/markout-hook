"""Fee-policy implementations evaluated against one common trade tape."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

from .model import Policy, PolicyOutcome, ReferenceStatus, Trade

CENTIBPS_DENOMINATOR = 1_000_000
RETENTION_BPS_DENOMINATOR = 10_000


def quote_fee(notional_quote_micro: int, fee_centibps: int) -> int:
    if notional_quote_micro < 0 or fee_centibps < 0:
        raise ValueError("notional and fee must be non-negative")
    return notional_quote_micro * fee_centibps // CENTIBPS_DENOMINATOR


def markout_retention_bps(markout_centibps: int, curve: Mapping[str, int]) -> int:
    favorable = curve["favorableCutoffCentibps"]
    adverse = curve["adverseCutoffCentibps"]
    minimum = curve["minimumRetentionBps"]
    neutral = curve["neutralRetentionBps"]
    if favorable <= 0 or adverse <= 0:
        raise ValueError("curve cutoffs must be positive")
    if not 0 <= minimum <= neutral <= RETENTION_BPS_DENOMINATOR:
        raise ValueError("curve retention anchors are invalid")

    if markout_centibps <= -favorable:
        return minimum
    if markout_centibps < 0:
        distance = markout_centibps + favorable
        return minimum + distance * (neutral - minimum) // favorable
    if markout_centibps >= adverse:
        return RETENTION_BPS_DENOMINATOR
    return neutral + markout_centibps * (RETENTION_BPS_DENOMINATOR - neutral) // adverse


def adverse_selection_proxy(trade: Trade) -> int:
    """Return N × positive directional markout; this is not individual-LP LVR."""

    return quote_fee(trade.notional_quote_micro, max(trade.markout_centibps, 0))


def evaluate_trade(trade: Trade, config: Mapping[str, Any]) -> tuple[PolicyOutcome, ...]:
    policies = config["policies"]
    proxy = adverse_selection_proxy(trade)
    fixed = _fixed_outcome(trade, policies["fixed"], proxy)
    volatility = _volatility_outcome(trade, policies["volatility"], proxy)
    markout = _markout_outcome(trade, policies["markout"], proxy)
    return fixed, volatility, markout


def _fixed_outcome(trade: Trade, policy: Mapping[str, Any], proxy: int) -> PolicyOutcome:
    retained = quote_fee(trade.notional_quote_micro, policy["baseFeeCentibps"])
    return _outcome(trade, Policy.FIXED, retained, retained, 0, 0, proxy, "not_required")


def _volatility_outcome(trade: Trade, policy: Mapping[str, Any], proxy: int) -> PolicyOutcome:
    numerator = policy["volatilityMultiplierNumerator"]
    denominator = policy["volatilityMultiplierDenominator"]
    if numerator < 0 or denominator <= 0:
        raise ValueError("volatility multiplier must be non-negative with a positive denominator")
    extra = trade.volatility_centibps * numerator // denominator
    fee_centibps = policy["baseFeeCentibps"] + min(extra, policy["maximumExtraFeeCentibps"])
    retained = quote_fee(trade.notional_quote_micro, fee_centibps)
    return _outcome(trade, Policy.VOLATILITY, retained, retained, 0, 0, proxy, "not_required")


def _markout_outcome(trade: Trade, policy: Mapping[str, Any], proxy: int) -> PolicyOutcome:
    base_fee = quote_fee(trade.notional_quote_micro, policy["baseFeeCentibps"])
    surcharge = quote_fee(trade.notional_quote_micro, policy["provisionalSurchargeCentibps"])
    upfront = base_fee + surcharge
    gas = policy["callbackGasBudget"]

    if trade.reference_status is not ReferenceStatus.VALID:
        return _outcome(
            trade,
            Policy.MARKOUT,
            upfront,
            base_fee,
            surcharge,
            0,
            proxy,
            "expired_full_rebate",
            rejected_reference_attempts=1,
            expired_settlements=1,
            reactive_callbacks=2,
            modeled_callback_gas_budget=gas["sample"] + gas["expiry"],
        )

    retention_bps = markout_retention_bps(trade.markout_centibps, policy["curve"])
    retained_surcharge = surcharge * retention_bps // RETENTION_BPS_DENOMINATOR
    rebate = surcharge - retained_surcharge
    return _outcome(
        trade,
        Policy.MARKOUT,
        upfront,
        base_fee + retained_surcharge,
        rebate,
        retained_surcharge,
        proxy,
        "settled",
        reactive_callbacks=2,
        modeled_callback_gas_budget=gas["sample"] + gas["settlement"],
    )


def _outcome(
    trade: Trade,
    policy: Policy,
    upfront: int,
    retained: int,
    rebate: int,
    protection: int,
    proxy: int,
    settlement_status: str,
    *,
    rejected_reference_attempts: int = 0,
    expired_settlements: int = 0,
    reactive_callbacks: int = 0,
    modeled_callback_gas_budget: int = 0,
) -> PolicyOutcome:
    if upfront != retained + rebate:
        raise AssertionError("fee allocation does not conserve the upfront charge")
    if protection > retained:
        raise AssertionError("LP protection cannot exceed total retained fees")
    return PolicyOutcome(
        trade=trade,
        policy=policy,
        upfront_fee_quote_micro=upfront,
        retained_fee_quote_micro=retained,
        rebate_quote_micro=rebate,
        lp_protection_quote_micro=protection,
        adverse_selection_proxy_quote_micro=proxy,
        lp_net_after_proxy_quote_micro=retained - proxy,
        settlement_status=settlement_status,
        rejected_reference_attempts=rejected_reference_attempts,
        expired_settlements=expired_settlements,
        reactive_callbacks=reactive_callbacks,
        modeled_callback_gas_budget=modeled_callback_gas_budget,
    )
