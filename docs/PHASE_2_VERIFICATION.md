# Phase 2 Verification Guide

## One-command cumulative gate

```bash
cd /Users/rudrabhaskar/Desktop/GitHub/MARKOUT
./scripts/verify-phase-2.sh
```

The script rechecks Phase 1 before checking Phase 2. It fails on formatting, compilation, size, lint, accounting,
mathematics, any stateful invariant, or deterministic gas drift.

## Expected evidence

| Layer | Expected minimum | Purpose |
| --- | ---: | --- |
| Phase 1 unit tests | 21 passing | Existing encoding, surcharge, and delta primitives do not regress |
| Phase 1 accounting tests | 15 passing | Real PoolManager escrow remains correct |
| Phase 2 math tests | 59 passing | Prices, observations, curve, settlement engine, and scenarios |
| Stateful invariants | 6 passing | Accounting backing plus economic bounds and conservation |
| Lint and formatting | No findings | Mechanical quality gate |
| Gas snapshot | Exact deterministic match | Unexpected execution-cost movement is review-visible |

Local fuzz tests run 1,000 cases each. The GitHub CI profile runs 10,000 cases and 1,000 × 128 calls for each stateful
invariant.

## Manual economic review

Display the scenario dataset:

```bash
column -s, -t test/fixtures/markout-scenarios.csv
```

Then execute the same table as Solidity assertions:

```bash
forge test --match-contract MarkoutScenariosTest -vv
```

Confirm:

1. Inventory-improving buy and sell cases receive a full rebate.
2. Neutral cases retain 20% and rebate 80%.
3. Equivalent ±10 bps directional moves produce the same 52% retention for buys and sells.
4. Moves at or beyond +25 bps retain the full provisional surcharge.
5. Every row satisfies `retained + rebate = escrow`.

Review invalid reference behavior:

```bash
forge test --match-contract ReferenceObservationValidatorTest -vv
```

Missing, zero, pre-maturity, future, stale, low-confidence, and post-grace inputs must all revert.

## Pass decision

Phase 2 passes only after the cumulative script succeeds and the reviewer agrees that the scenario table matches the
intended economics. Approval permits the `phase-2-pass` tag and Phase 3 work; it does not approve real-fund deployment.
