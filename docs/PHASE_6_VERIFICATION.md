# Phase 6 Verification Guide

Phase 6 turns MARKOUT's research claim into a reproducible controlled comparison. It evaluates a fixed fee, a
volatility-linked fee, and MARKOUT against one common seeded tape spanning benign, informed, inventory-improving,
mixed-volatility, stale-reference, and manipulated-reference cases.

Phase 5's public settlement gate remains independently open while Reactive destination delivery is unresolved. No
live evidence is fabricated or substituted by this experiment.

## Focused reproducibility gate

```bash
./experiments/run.sh
```

Expected result:

```text
Ran 10 tests ... OK
Generated 768 trades and 2304 policy outcomes for 6 scenarios.
Phase 6 experiment is reproducible: committed artifacts match a fresh seeded run.
```

The script generates into a temporary directory and recursively compares the new artifacts with the committed files.
A changed seed, model, configuration, row order, numeric result, report, chart, or manifest fails the command.

## Cumulative gate

```bash
./scripts/verify-phase-6.sh
```

This runs the complete Phase 1–5 deployment-independent Solidity gate, the Phase 6 experiment tests and artifact
comparison, and whitespace validation. It requires no RPC, private key, package download, or public-chain transaction.

## Manual review

```bash
column -s, -t experiments/results/flow_summary.csv
sed -n '1,240p' experiments/results/report.md
```

Review the three SVG files in `experiments/charts/` and confirm that the report says all of the following:

- MARKOUT improves aggregate LP net-after-proxy versus the fixed fee on this tape.
- MARKOUT underperforms the volatility baseline in aggregate retained value.
- MARKOUT charges benign and inventory-improving flow less than the volatility baseline.
- The fixed fee remains cheapest for benign flow.
- Invalid references expire with a full provisional-surcharge rebate and reduced LP protection.
- Reactive callback overhead, isolated-trade assumptions, and all model limitations are explicit.

## Observed deterministic result

Across 768 trades and 1,999,280 USDC of identical modeled volume per policy:

| Policy | LP net after proxy (USDC) | Avg effective fee | Rebate (USDC) | Protection reserve (USDC) |
| --- | ---: | ---: | ---: | ---: |
| Fixed | 3,888.993116 | 30.0000 bps | 0 | 0 |
| Volatility | 7,593.537628 | 48.5294 bps | 0 | 0 |
| MARKOUT | 7,138.784402 | 46.2548 bps | 6,746.608714 | 3,249.791286 |

The result supports outcome-based flow discrimination and an improvement over the fixed baseline. It does not support
a claim that MARKOUT maximizes aggregate LP fee protection: the configured volatility baseline retains 454.753226 USDC
more on this tape by charging benign and inventory-improving flow more heavily.

## Integrity evidence

`experiments/results/manifest.json` records SHA-256 hashes of:

- the experiment configuration;
- every generator source module; and
- every raw, aggregate, report, and chart artifact.

The generator uses integer quote micro-units, integer centibasis-point inputs, explicit floor rounding, and a frozen
SplitMix64 implementation. Floating-point arithmetic is limited to SVG coordinates and never affects economic output.
