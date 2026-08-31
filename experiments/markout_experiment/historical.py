"""Deterministic replay of frozen Uniswap swap events through MARKOUT policies."""

from __future__ import annotations

import csv
import hashlib
import json
from bisect import bisect_left, bisect_right
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP, getcontext
from pathlib import Path
from typing import Any

from .aggregation import summarize_all, summarize_by_flow
from .model import FlowClass, Policy, PolicyOutcome, ReferenceStatus, Trade
from .policies import evaluate_trade

getcontext().prec = 80
PRICE_SCALE = 10**18
CENTIBPS_SCALE = Decimal(1_000_000)
Q192 = Decimal(2**192)
TOKEN_DECIMAL_ADJUSTMENT = Decimal(10**12)


@dataclass(frozen=True, slots=True)
class HistoricalSwap:
    block_number: int
    block_hash: str
    transaction_hash: str
    transaction_index: int
    log_index: int
    timestamp: int
    amount0_raw: int
    amount1_raw: int
    sqrt_price_x96: int
    liquidity: int
    tick: int


def load_historical_config(path: Path) -> dict[str, Any]:
    config = json.loads(path.read_text(encoding="utf-8"))
    required = {"schemaVersion", "experimentId", "chain", "capture", "markout", "policies"}
    missing = required - config.keys()
    if missing:
        raise ValueError(f"missing historical configuration keys: {sorted(missing)}")
    if config["schemaVersion"] != 1:
        raise ValueError("unsupported historical configuration schema")
    if config["chain"]["token0"] != {"symbol": "USDC", "decimals": 6}:
        raise ValueError("historical replay requires USDC as token0")
    if config["chain"]["token1"] != {"symbol": "WETH", "decimals": 18}:
        raise ValueError("historical replay requires WETH as token1")
    capture = config["capture"]
    if not (
        capture["fetchStartBlock"] < capture["analysisStartBlock"]
        <= capture["analysisEndBlock"] < capture["fetchEndBlock"]
    ):
        raise ValueError("capture window must include head and tail observations")
    return config


def load_historical_swaps(path: Path) -> list[HistoricalSwap]:
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    swaps = [
        HistoricalSwap(
            block_number=int(row["block_number"]),
            block_hash=row["block_hash"],
            transaction_hash=row["transaction_hash"],
            transaction_index=int(row["transaction_index"]),
            log_index=int(row["log_index"]),
            timestamp=int(row["timestamp"]),
            amount0_raw=int(row["amount0_raw"]),
            amount1_raw=int(row["amount1_raw"]),
            sqrt_price_x96=int(row["sqrt_price_x96"]),
            liquidity=int(row["liquidity"]),
            tick=int(row["tick"]),
        )
        for row in rows
    ]
    if not swaps:
        raise ValueError("historical swap file is empty")
    ordered = sorted(swaps, key=lambda swap: (swap.block_number, swap.transaction_index, swap.log_index))
    if swaps != ordered:
        raise ValueError("historical swaps are not canonically ordered")
    identities = {(swap.transaction_hash, swap.log_index) for swap in swaps}
    if len(identities) != len(swaps):
        raise ValueError("historical swap file contains duplicate logs")
    return swaps


def quote_price_x18(sqrt_price_x96: int) -> int:
    """Return USDC per WETH scaled by 1e18 for a USDC(token0)/WETH(token1) pool."""

    if sqrt_price_x96 <= 0:
        raise ValueError("sqrt price must be positive")
    price = TOKEN_DECIMAL_ADJUSTMENT * Q192 / Decimal(sqrt_price_x96**2)
    return int((price * PRICE_SCALE).to_integral_value(rounding=ROUND_HALF_UP))


def relative_move_centibps(start_sqrt_price_x96: int, end_sqrt_price_x96: int) -> int:
    """Return the signed USDC/WETH price move in 0.01 bps units."""

    if start_sqrt_price_x96 <= 0 or end_sqrt_price_x96 <= 0:
        raise ValueError("sqrt prices must be positive")
    # Quote/base price is inverse to sqrtPriceX96 squared for this token ordering.
    ratio = Decimal(start_sqrt_price_x96**2) / Decimal(end_sqrt_price_x96**2)
    return int(((ratio - 1) * CENTIBPS_SCALE).to_integral_value(rounding=ROUND_HALF_UP))


def derive_historical_trades(
    swaps: Sequence[HistoricalSwap], config: Mapping[str, Any]
) -> list[Trade]:
    capture = config["capture"]
    horizon = config["markout"]["horizonSeconds"]
    boundary = config["markout"]["nearZeroBoundaryCentibps"]
    timestamps = [swap.timestamp for swap in swaps]
    trades: list[Trade] = []

    for swap in swaps:
        if not capture["analysisStartBlock"] <= swap.block_number <= capture["analysisEndBlock"]:
            continue
        notional = abs(swap.amount0_raw)
        if notional < capture["minimumNotionalQuoteMicro"] or swap.amount0_raw == 0:
            continue

        prior_index = bisect_right(timestamps, swap.timestamp - horizon) - 1
        future_index = bisect_left(timestamps, swap.timestamp + horizon)
        if prior_index < 0 or future_index >= len(swaps):
            continue

        prior = swaps[prior_index]
        future = swaps[future_index]
        raw_move = relative_move_centibps(swap.sqrt_price_x96, future.sqrt_price_x96)
        direction = "buy_base" if swap.amount0_raw > 0 else "sell_base"
        markout = raw_move if direction == "buy_base" else -raw_move
        trailing_move = relative_move_centibps(prior.sqrt_price_x96, swap.sqrt_price_x96)
        volatility = abs(trailing_move)
        flow_class = _classify_outcome(markout, boundary)
        digest = hashlib.sha256(
            f"{config['experimentId']}:{swap.transaction_hash}:{swap.log_index}".encode()
        ).hexdigest()
        trades.append(
            Trade(
                trade_id=f"0x{digest}",
                seed=0,
                scenario_id="ethereum_mainnet_usdc_weth_v3",
                scenario_label="Ethereum mainnet USDC/WETH v3 historical window",
                trade_index=len(trades),
                flow_class=flow_class,
                direction=direction,
                notional_quote_micro=notional,
                execution_price_x18=quote_price_x18(swap.sqrt_price_x96),
                candidate_reference_price_x18=quote_price_x18(future.sqrt_price_x96),
                markout_centibps=markout,
                volatility_centibps=volatility,
                reference_status=ReferenceStatus.VALID,
            )
        )
        if len(trades) >= capture["maximumTrades"]:
            break

    if not trades:
        raise ValueError("capture window did not produce eligible historical trades")
    return trades


def evaluate_historical_trades(
    trades: Sequence[Trade], config: Mapping[str, Any]
) -> list[PolicyOutcome]:
    return [outcome for trade in trades for outcome in evaluate_trade(trade, config)]


def build_historical_summary(
    swaps: Sequence[HistoricalSwap], trades: Sequence[Trade], outcomes: Sequence[PolicyOutcome], config: Mapping[str, Any]
) -> dict[str, Any]:
    aggregate = summarize_all(outcomes)
    flow = summarize_by_flow(outcomes)
    by_policy = {row["policy"]: row for row in aggregate}
    fixed = by_policy[Policy.FIXED.value]
    markout = by_policy[Policy.MARKOUT.value]
    delta = markout["lp_net_after_proxy_quote_micro"] - fixed["lp_net_after_proxy_quote_micro"]
    improvement = _percent(delta, fixed["lp_net_after_proxy_quote_micro"])
    markouts = sorted(trade.markout_centibps for trade in trades)
    return {
        "schemaVersion": 1,
        "experimentId": config["experimentId"],
        "source": {
            "chainId": config["chain"]["chainId"],
            "poolAddress": config["chain"]["poolAddress"],
            "poolLabel": config["chain"]["poolLabel"],
            "poolExplorerUrl": config["chain"]["poolExplorerUrl"],
            "fetchStartBlock": config["capture"]["fetchStartBlock"],
            "analysisStartBlock": config["capture"]["analysisStartBlock"],
            "analysisEndBlock": config["capture"]["analysisEndBlock"],
            "fetchEndBlock": config["capture"]["fetchEndBlock"],
            "firstTimestamp": swaps[0].timestamp,
            "lastTimestamp": swaps[-1].timestamp,
            "firstTimestampIso": datetime.fromtimestamp(swaps[0].timestamp, timezone.utc).isoformat(),
            "lastTimestampIso": datetime.fromtimestamp(swaps[-1].timestamp, timezone.utc).isoformat(),
            "rawSwapLogs": len(swaps),
            "eligibleTrades": len(trades),
        },
        "method": {
            "horizonSeconds": config["markout"]["horizonSeconds"],
            "executionPrice": "post-swap Uniswap v3 sqrtPriceX96 converted to USDC/WETH",
            "referencePrice": "first pool swap price at or after t+5 minutes",
            "volatilityInput": "absolute pool price move over the trailing five minutes, excluding future data",
            "outcomeBuckets": "ex-post directional markout bands; they are descriptive, not predictive labels",
            "metricBoundary": (
                "notional multiplied by positive directional markout is a pool-level adverse-selection proxy; "
                "it is not exact LVR, an independent-oracle comparison, or individual LP PnL"
            ),
        },
        "observed": {
            "minimumMarkoutBps": _bps(markouts[0]),
            "medianMarkoutBps": _bps(markouts[len(markouts) // 2]),
            "maximumMarkoutBps": _bps(markouts[-1]),
            "markoutLpNetDeltaVsFixedQuoteMicro": delta,
            "markoutLpNetDeltaVsFixedPercent": improvement,
        },
        "aggregate": [_json_ready(row) for row in aggregate],
        "byOutcomeBucket": [_json_ready(row) for row in flow],
        "limitations": [
            "One fixed Ethereum mainnet pool window is a robustness replay, not a representative market sample.",
            "The future reference is the same pool's later marginal price, not an independent Pyth or CEX price.",
            "sqrtPriceX96 is the post-swap marginal price, not the trade's volume-weighted execution price.",
            "The replay holds trades and volume fixed and does not model routing, elasticity, liquidity depth, ranges, or rebalancing.",
        ],
    }


def _classify_outcome(markout_centibps: int, boundary: int) -> FlowClass:
    if markout_centibps > boundary:
        return FlowClass.INFORMED
    if markout_centibps < -boundary:
        return FlowClass.INVENTORY_IMPROVING
    return FlowClass.BENIGN


def _percent(numerator: int, denominator: int) -> str | None:
    if denominator == 0:
        return None
    value = Decimal(numerator) * Decimal(100) / Decimal(abs(denominator))
    return format(value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP), "f")


def _bps(centibps: int) -> str:
    return format((Decimal(centibps) / Decimal(100)).quantize(Decimal("0.01")), "f")


def _json_ready(row: Mapping[str, Any]) -> dict[str, Any]:
    return {key: (format(value, "f") if isinstance(value, Decimal) else value) for key, value in row.items()}
