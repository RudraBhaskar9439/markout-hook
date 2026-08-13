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

## D-007 — Use the unspecified swap currency for the provisional surcharge

Uniswap v4 applies an `afterSwap` return delta to the swap's unspecified side. MARKOUT therefore collects its
provisional surcharge from output on exact-input swaps and adds it to input on exact-output swaps. This keeps Phase 1
on v4's native custom-accounting path in all four swap quadrants.

## D-008 — Treat the user's maximum as an authorization boundary

Every swap supplies a rebate recipient and an absolute maximum surcharge in canonical hook data. The hook reverts the
entire swap if its quote exceeds that maximum. The maximum is not configuration or advisory slippage metadata; it is
the transaction-level consent boundary enforced by the hook. Integrating routers remain responsible for passing the
swapper-approved payload unchanged.

## D-009 — Separate accounting mechanics from economic policy

`BaseProvisionalSurcharge` owns PoolManager authorization, currency resolution, custody, accounting, and events.
Derived contracts implement only `_quoteSurcharge`. This allows the fixed Phase 1 proof policy to be replaced by the
Phase 2 markout policy without rewriting the custody-critical path.

## D-010 — Round the provisional surcharge down

Basis-point quotes use full-precision multiplication and floor division. Rounding down guarantees the collected value
never exceeds the mathematical percentage selected by the policy. A zero result is valid and causes no token transfer.

## D-011 — Account by pool and by currency

The hook records pool-scoped accruals while also tracking aggregate currency balances. This avoids mixing economic
ownership across pools while providing one aggregate that can be checked directly against each currency held by the
contract.
