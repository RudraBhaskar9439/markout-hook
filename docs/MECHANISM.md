# MARKOUT Mechanism Specification

Status: Reactive Network is the primary event-to-action architecture. A Legacy Reactive cross-chain callback is
verified publicly, and the pending-first acceptance run proves ReactVM execution plus safe full-refund expiry. A
complete pending-first economic allocation through Reactive remains unproven because that acceptance run did not
reach the destination relayer before expiry. Earlier Circle lifecycles are retained only as historical accounting and
recovery-path evidence.

## 1. Problem

Most dynamic-fee hooks price a swap using information available before execution, such as volatility or pool imbalance. Those signals cannot directly reveal whether the individual trade was informed. MARKOUT instead escrows a bounded provisional hook surcharge and settles it after observing a future reference price.

## 2. Trade lifecycle

1. The pool charges its ordinary Uniswap LP fee.
2. MARKOUT collects a separately disclosed provisional hook surcharge.
3. The hook records the execution price, trade direction, surcharge, and maturity configuration.
4. The hook emits `MarkoutRequested` with a unique trade ID.
5. After maturity, a publisher submits a signed Pyth update for the configured ETH/USD feed on Ethereum Sepolia.
6. The publisher normalizes the observation and emits one canonical event bound to the market and trade ID.
7. A stateless Legacy Reactive Contract observes that exact event, executes in ReactVM, and requests an authenticated
   callback on Unichain.
8. The Reactive receiver and immutable settlement coordinator authenticate and forward the observation.
9. MARKOUT revalidates the evidence and calculates the final retained surcharge exactly once.
10. The trader receives a pull-based rebate credit. The retained portion is credited to the LP protection reserve.

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
- Maximum Pyth price age when verified by the source publisher: two minutes.
- Maximum already-verified observation age at destination evaluation: five minutes.
- Minimum adapter-normalized confidence: 9,000 out of 10,000.
- Observations before maturity, from the future, after the grace period, stale, missing, zero, or below confidence fail.

If no valid settlement completes before expiry, the complete escrow becomes claimable as a trader rebate.
Oracle or Reactive delivery failure cannot create LP protection value.

## 6. Reactive-first automation boundary

Reactive Network is MARKOUT's event-driven observation and action transport. The live Legacy pulse subscribes to the
canonical publisher event, executes in ReactVM, and requests an authenticated callback to Unichain. A v4 hook cannot
wake itself at the five-minute horizon or listen to Ethereum Sepolia, so this Reactive layer advances the normal
lifecycle without a MARKOUT-owned watcher. It owns no oracle, custody, or fee authority; the destination hook
independently validates every economic input.

The canonical source publisher:

- verifies a fresh update against the configured Pyth contract and feed;
- emits one canonical normalized observation;
- binds the observation to the configured market and trade ID; and
- exposes one narrow event that the Reactive subscription can filter exactly.

The Reactive receiver requires both the system callback proxy and the injected ReactVM identity. The coordinator and
hook then provide the replay boundary: the first valid callback can settle a pending trade, while a later duplicate is
a successful no-op. No ordinary EOA receives settlement authority. A public Legacy callback proves the live transport
boundary; the separate pending-first acceptance run records the relayer timeout and full-refund expiry rather than
treating a ReactVM event as a completed economic settlement.

The repository also preserves an earlier Circle CCTP recovery adapter and four public economic lifecycles. Those
contracts prove accounting branches and transport redundancy, but they are not the primary architecture of the final
Reactive-first project.

For the ETH/USDC testnet MVP, the configured Pyth ETH/USD price is used as an ETH/USDC proxy and therefore assumes
USDC remains close to one US dollar. A production design must use a direct ETH/USDC source or explicitly model USDC
basis risk.

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

## 10. Remaining release decisions

1. Improve and monitor Reactive destination relaying before placing the testnet design in a production-critical path.
2. Decide how the LP protection reserve becomes pool liquidity or LP-owned value.
3. Replace the ETH/USD-as-ETH/USDC testnet proxy before any production use.
