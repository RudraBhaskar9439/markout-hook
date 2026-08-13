# MARKOUT Mechanism Specification

Status: initial design hypothesis. Phase 1 must validate the v4 accounting path, and Phase 2 must freeze the economic formula.

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

## 3. Sign convention

Let `q = +1` for a trader buying the base asset and `q = -1` for selling it.

```text
markout = q × (referencePriceAtMaturity − executionPrice) / executionPrice
```

- Positive markout: the market moved in the trader's direction; the trade was adverse to the LP.
- Approximately zero: neutral flow.
- Negative markout: the market moved against the trader; the flow was inventory-improving or non-toxic under this proxy.

This is a flow-quality proxy, not proof of malicious behavior. MARKOUT must never label an address or block access based on the score.

## 4. Settlement constraints

The exact curve is finalized in Phase 2, but it must always satisfy:

```text
0 <= retainedSurcharge <= escrowedSurcharge
rebate = escrowedSurcharge - retainedSurcharge
```

Additional requirements:

- Bounded and monotonic for positive markout
- Deterministic integer arithmetic
- Symmetric treatment of equivalent buys and sells
- Explicit rounding direction
- Maximum reference-price age
- Defined behavior for missing, stale, zero, or invalid observations

## 5. Reactive Network's essential role

The Reactive Contract is not a convenience keeper. It is the autonomous settlement layer that:

- subscribes to `MarkoutRequested` events;
- consumes reference-market price events from the selected EVM source;
- waits for the maturity horizon using Reactive cron events;
- selects the eligible reference observation; and
- sends the authenticated settlement callback.

The destination contract accepts settlement only from the authorized Reactive callback identity. No ordinary EOA receives a privileged settlement role in the final design.

## 6. State model

Each trade has one terminal outcome:

```text
PENDING -> SETTLED
PENDING -> EXPIRED
```

- `SETTLED`: a valid reference observation produced a rebate and retained amount.
- `EXPIRED`: the reference stream or callback failed beyond a bounded grace period. The expiry refund policy will be frozen in Phase 2.

No terminal state can transition again.

## 7. Safety model

- Rebates use pull payments to isolate transfer failures.
- Settlement is replay-protected by trade ID and state.
- Pending escrow plus claimable rebates must never exceed held assets.
- Reference observations must satisfy source, maturity, and freshness rules.
- Callback authentication must be checked at the settlement boundary.
- Hook recursion and PoolManager delta settlement require explicit tests.
- Administrative actions cannot confiscate pending escrow or user rebates.

## 8. MVP non-goals

- Production deployment or audit claim
- Machine-learning toxicity classification
- Address reputation or permissioned flow
- Private intent routing or a solver auction
- Multi-asset portfolio optimization
- Supporting every pool and oracle before the ETH/USDC path works

## 9. Decisions Phase 1 and Phase 2 must resolve

1. Which v4 callback and return-delta path collects the surcharge for every swap mode?
2. In which token is the provisional surcharge held for exact-input and exact-output swaps?
3. How is the execution price normalized without overflow or avoidable precision loss?
4. Which reference-market event is reliable on the chosen testnets?
5. What are the maturity horizon, grace period, and stale-price threshold?
6. What happens on expiry: full rebate, conservative split, or another predetermined policy?
7. How and when does the LP protection reserve become pool liquidity or LP-owned value?

