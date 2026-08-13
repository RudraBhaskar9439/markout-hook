# Decision Log

## D-001 — Outcome-based settlement

MARKOUT uses post-trade markout rather than a pre-trade toxicity classifier. This keeps the mechanism deterministic and directly testable.

## D-002 — Separate surcharge from ordinary LP fee

The MVP treats the provisional MARKOUT amount as a hook-level surcharge separate from the pool's normal LP fee. This avoids promising to reverse an LP fee after Uniswap has already distributed it. Phase 1 must prove the exact v4 accounting implementation.

## D-003 — Reactive is the final settlement authority

The production-shaped MVP does not rely on a developer keeper. Reactive Network observes events, manages maturity, and originates the authenticated callback.

## D-004 — Pull-based rebates

Settlement records claimable rebates instead of pushing tokens to arbitrary trader contracts. This limits reentrancy and prevents one failed transfer from blocking unrelated settlements.

## D-005 — One pool before generalization

The first complete path targets one ETH/USDC-style pool. Generalized assets, configurable oracles, and multiple horizons are extensions after the research result works end to end.

## D-006 — Evidence before interface

The testnet callback and research comparison must pass before frontend work begins. The interface visualizes verified behavior; it does not substitute for it.

