# MARKOUT Phase 6 Research Experiment

This directory contains a deterministic controlled experiment comparing three fee policies against one identical
synthetic trade tape:

1. a 30 bps fixed LP fee;
2. a volatility-linked fee with a 30 bps base, `0.75 ×` observed volatility, and a 50 bps incremental cap; and
3. MARKOUT Fair-Flow's 18 bps base plus a refundable 50 bps provisional surcharge governed by the on-chain
   retention curve.

The 18 bps base is not hand-picked after reading one output. A committed 10–30 bps sweep selects the lowest candidate
that keeps benign and inventory-improving effective fees at or below 30 bps while preserving at least 20% modeled LP
net-after-proxy improvement versus the fixed baseline. The earlier public testnet pool remains 30 + 50 bps and is
reported separately; the Fair-Flow profile is deployed in a separate 18 + 50 bps Unichain Sepolia pool.

The separate [`historical/`](historical/README.md) appendix freezes 400 canonical Ethereum mainnet USDC/WETH Swap
logs and evaluates 251 eligible trades over the same five-minute horizon. That observed-event replay is a robustness
check, not the source of the selected parameters and not a replacement for this controlled causal comparison.

The volatility policy is a declared baseline, not an assertion that those parameters are universally optimal.
Uniswap v4 supports both per-swap dynamic LP fees and hook-defined fees; its documentation also notes that an optimal
fee depends on volatility and uninformed volume. See [Uniswap's dynamic-fee documentation](https://developers.uniswap.org/docs/protocols/v4/concepts/dynamic-fees).

## Research question and hypotheses

The experiment asks whether outcome-conditioned fee retention can improve modeled LP economics over a fixed fee while
charging benign and inventory-improving flow less than a policy that raises fees for every trader during volatility.

- **H1 - discrimination:** MARKOUT charges informed flow more than benign or inventory-improving flow.
- **H2 - fixed-fee comparison:** MARKOUT improves LP net-after-proxy results relative to a 30 bps fixed fee.
- **H3 - volatility tradeoff:** MARKOUT charges benign and inventory-improving flow less than the volatility policy,
  but can provide less aggregate fee protection because it rebates more value.

These are evaluated observations, not assertions embedded into the test expectations. A policy can lose a comparison
without making the reproducibility gate fail.

## Metric boundary

For each trade, the experiment computes:

```text
post-trade adverse-selection proxy = notional × max(directional markout, 0)
LP net after proxy                  = retained fees − adverse-selection proxy
```

The first quantity approximates value captured by favorably marked informed flow at the pool level. It is **not** an
individual LP's loss and is not labeled exact loss-versus-rebalancing. Exact position impact also depends on active
liquidity, range depth, LP share, the complete price path, and rebalancing. The formal LVR benchmark compares an AMM
LP against a continuously rebalanced portfolio; see Milionis, Moallemi, Roughgarden, and Zhang,
[Automated Market Making and Loss-Versus-Rebalancing](https://arxiv.org/abs/2208.06046).

Every policy sees the same trades. Fees therefore change retained value, but do not change the gross proxy. Volume is
also identical because demand elasticity and routing are outside this controlled experiment.

## Scenarios

The committed configuration defines 128 trades in each scenario:

| Scenario | Purpose |
| --- | --- |
| Benign random flow | near-zero directional markouts in low volatility |
| Informed flow | consistently positive markouts after execution |
| Inventory-improving flow | consistently negative markouts |
| Mixed, low volatility | benign, informed, and inventory-improving flow together |
| Mixed, high volatility | the same flow classes under a wider volatility/markout regime |
| Stale/manipulated reference | valid, stale, and rejected manipulated observations |

The last scenario exercises MARKOUT's fail-open rule: an invalid observation eventually expires and returns the full
provisional surcharge. Its cost model includes one rejected sampling callback plus one expiry callback. Production
retries can cost more and batching can reduce sampling calls. The reported callback gas is therefore an isolated-trade
model using configured budgets, not measured public-chain spend.

## Reproduce

Requirements are Git and Python 3.12. The generator uses only the Python standard library and a frozen SplitMix64
implementation; it does not use Python's implementation-dependent random module.

```bash
./experiments/run.sh
```

The command:

1. runs the experiment unit and invariant tests;
2. generates a fresh artifact set in a temporary directory; and
3. byte-compares every result, report, chart, and integrity manifest with the committed outputs.

To intentionally regenerate after reviewing a configuration or model change:

```bash
./experiments/regenerate.sh
./experiments/run.sh
```

## Artifact map

| Path | Purpose |
| --- | --- |
| `config/experiment.json` | seed, policy parameters, distributions, and gas-budget assumptions |
| `results/raw_trades.csv` | policy-independent trade tape |
| `results/policy_outcomes.csv` | per-trade output under all three policies |
| `results/summary.csv` | scenario × policy metrics |
| `results/flow_summary.csv` | flow-class × policy metrics |
| `results/summary.json` | machine-readable aggregate, boundary, and limitations |
| `results/adoption_summary.json` | fee-only trader routing break-evens and LP comparison deltas |
| `results/fair_flow_sweep.json` | declared constraints, all 21 base-fee candidates, and the selected profile |
| `results/report.md` | judge-readable findings, regressions, and scenario table |
| `results/manifest.json` | SHA-256 hashes for generator inputs and every generated artifact |
| `charts/*.svg` | dependency-free deterministic visual comparisons, including the fee frontier |

The routing break-even artifact answers the trader-adoption objection without assuming its conclusion. It reports
how much better MARKOUT's execution price or slippage must be to offset any fee premium against the fixed baseline,
and the fee-only saving available against the volatility baseline. It does not claim that the hook itself has already
created more liquidity or volume.

## What this experiment cannot establish

- It is a synthetic mechanism comparison, not historical backtesting or a forecast.
- It does not model concentrated-liquidity ranges, active depth, position shares, rebalancing, or LP inventory paths.
- It does not model demand elasticity, routing changes, MEV competition, or traders adapting to the policy.
- Its spot-median failure case is not evidence that the Phase 5 sampler is a production oracle.
- Its callback gas assumes isolated trades with one sample plus one terminal callback; batching and retries are outside
  the deterministic tape.
- Configured callback gas budgets are not live Lasna or Unichain transaction costs.

The experiment is deliberately structured so later historical data or a richer AMM simulator can replace the trade
tape without changing the policy, aggregation, reporting, or reproducibility boundaries.
