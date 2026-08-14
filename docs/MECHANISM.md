# MARKOUT Mechanism Specification

Status: Phase 1 accounting path validated; Phase 2 economic formula frozen for the MVP.

## 1. Problem

Most dynamic-fee hooks price a swap using information available before execution, such as volatility or pool imbalance. Those signals cannot directly reveal whether the individual trade was informed. MARKOUT instead escrows a bounded provisional hook surcharge and settles it after observing a future reference price.

## 2. Trade lifecycle

1. The pool charges its ordinary Uniswap LP fee.
2. MARKOUT collects a separately disclosed provisional hook surcharge.
3. The hook records the execution price, trade direction, surcharge, and maturity configuration.
4. The hook emits `MarkoutRequested` with a unique trade ID.
5. Reactive Network observes the request and reference-market events.
6. At maturity, Reactive sends an authenticated callback containing the selected reference observation.
7. MARKOUT calculates the final retained surcharge.
8. The trader receives a pull-based rebate credit. The retained portion is credited to the LP protection reserve.

## 3. Price and sign convention

Every execution and reference price is normalized to quote-token units per one base token, scaled by `1e18`. For the
ETH/USDC MVP, a $2,000 ETH price is represented as `2000e18`, regardless of the source feed's decimals or orientation.

Let `q = +1` for a trader buying the base asset and `q = -1` for selling it.

```text
markout = q × (referencePriceAtMaturity − executionPrice) / executionPrice
```

- Positive markout: the market moved in the trader's direction; the trade was adverse to the LP.
- Approximately zero: neutral flow.
- Negative markout: the market moved against the trader; the flow was inventory-improving or non-toxic under this proxy.

This is a flow-quality proxy, not proof of malicious behavior. MARKOUT must never label an address or block access based on the score.

## 4. Settlement curve

The Phase 2 curve has three economic anchors:

- markout at or below -5 bps: retain 0%, rebate 100%;
- zero markout: retain 20%, rebate 80%;
- markout at or above +25 bps: retain 100%, rebate 0%.

Retention is linearly interpolated between the anchors and rounded down. The rebate receives the exact subtraction
remainder, so:

```text
0 <= retainedSurcharge <= escrowedSurcharge
rebate = escrowedSurcharge - retainedSurcharge
```

The curve is monotonic over its entire domain and treats equivalent buy and sell price movements symmetrically.

## 5. Observation policy

- Maturity: five minutes after execution.
- Settlement grace period: ten minutes after maturity.
- Maximum reference-observation age at evaluation: two minutes.
- Minimum adapter-normalized confidence: 9,000 out of 10,000.
- Observations before maturity, from the future, after the grace period, stale, missing, zero, or below confidence fail.

If no valid settlement completes before expiry, Phase 3 must make the complete escrow claimable as a trader rebate.
Oracle or Reactive liveness failure cannot create LP protection value.

## 6. Reactive Network's essential role

The Reactive Contract is not a convenience keeper. It is the autonomous settlement layer that:

- subscribes to `MarkoutRequested` events;
- consumes reference-market price events from the selected EVM source;
- waits for the maturity horizon using Reactive cron events;
- selects the eligible reference observation; and
- sends the authenticated settlement callback.

The destination contract accepts settlement only from the authorized Reactive callback identity. No ordinary EOA receives a privileged settlement role in the final design.

## 7. State model

Each trade has one terminal outcome:

```text
PENDING -> SETTLED
PENDING -> EXPIRED
```

- `SETTLED`: a valid reference observation produced a rebate and retained amount.
- `EXPIRED`: the reference stream or callback failed beyond the ten-minute grace period; the full escrow becomes a
  trader rebate.

No terminal state can transition again.

## 8. Safety model

- Rebates use pull payments to isolate transfer failures.
- Settlement is replay-protected by trade ID and state.
- Pending escrow plus claimable rebates must never exceed held assets.
- Reference observations must satisfy source, maturity, and freshness rules.
- Callback authentication must be checked at the settlement boundary.
- Hook recursion and PoolManager delta settlement require explicit tests.
- Administrative actions cannot confiscate pending escrow or user rebates.

## 9. MVP non-goals

- Production deployment or audit claim
- Machine-learning toxicity classification
- Address reputation or permissioned flow
- Private intent routing or a solver auction
- Multi-asset portfolio optimization
- Supporting every pool and oracle before the ETH/USDC path works

## 10. Remaining implementation decisions

1. Which reference-market event and source-specific confidence adapter are reliable on the selected testnets?
2. How should execution-price inputs be persisted and authenticated in the Phase 3 trade record?
3. How and when does the LP protection reserve become pool liquidity or LP-owned value?
