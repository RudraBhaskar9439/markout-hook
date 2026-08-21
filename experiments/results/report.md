# MARKOUT Phase 6 Experiment Report

Experiment `markout-phase-6-v1` uses deterministic SplitMix64 seed `20260825` and 128 trades per scenario.

The evaluated MARKOUT profile is the Fair-Flow release candidate: 18 bps base plus a refundable 50 bps surcharge, for a maximum upfront fee of 68 bps. The existing public testnet evidence remains the earlier 30 + 50 bps deployment and is not relabeled as this candidate.

## Metric boundary

The experiment reports `notional × max(directional markout, 0)` as a pool-level post-trade adverse-selection proxy. It does **not** call that number exact LVR or an individual LP's loss. Concentrated-liquidity depth, range occupancy, LP share, price path, and rebalancing are outside this model.

Fees do not change the gross proxy because every policy receives the same committed trade tape. The comparison therefore asks how much of that proxy is offset by retained fees, not whether a fee prevents the underlying price move.

## Aggregate result

| Policy | Volume (USDC) | Gross proxy | Retained fees | LP net after proxy | Rebates | Protection reserve | Avg effective fee (bps) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| fixed | 1999280.000000 | 2108.846884 | 5997.840000 | 3888.993116 | 0.000000 | 0.000000 | 30.0000 |
| volatility | 1999280.000000 | 2108.846884 | 9702.384512 | 7593.537628 | 0.000000 | 0.000000 | 48.5294 |
| markout | 1999280.000000 | 2108.846884 | 6848.495286 | 4739.648402 | 6746.608714 | 3249.791286 | 34.2548 |

## Supported observations

- MARKOUT changes aggregate LP net-after-proxy by +850.655286 USDC versus the fixed-fee baseline on this tape.
- MARKOUT changes aggregate LP net-after-proxy by -2853.889226 USDC versus the volatility baseline.
- Benign flow pays 27.4262 bps under MARKOUT versus 49.4790 bps under the volatility policy.
- Inventory-improving flow pays 18.0000 bps under MARKOUT versus 47.4403 bps under the volatility policy.
- MARKOUT returns 6746.608714 USDC and credits 3249.791286 USDC to the modeled protection reserve.
- The invalid-reference scenario produces 63 rejected observations and 63 full-surcharge expiries.

## Regressions and costs

- The Fair-Flow candidate is cheaper for benign flow at identical execution: 27.4262 bps versus 30.0000 bps for the fixed baseline.
- Under the isolated-trade callback assumption, MARKOUT requires 1536 modeled Reactive callbacks with a combined configured gas budget of 614,400,000 units. Fixed and volatility baselines have no Reactive callback cost in this model.
- Invalid observations fail safely with a full provisional-surcharge rebate, but that also removes incremental LP protection for those trades.
- All policies receive identical volume because demand elasticity, routing, and fee-sensitive order flow are deliberately excluded. This experiment cannot claim volume growth.

## Trader routing break-even

A trader chooses the best all-in quote, not a fee mechanism in isolation. The table below states the exact execution-price or slippage advantage MARKOUT would need to offset any fee premium against a same-liquidity 30 bps pool. It also reports the fee-only saving against the declared volatility baseline. This is a break-even condition, not a claim that MARKOUT already creates deeper liquidity.

| Flow class | Fixed fee | Volatility fee | MARKOUT fee | Execution advantage needed vs fixed | MARKOUT saving vs volatility per $10k |
| --- | ---: | ---: | ---: | ---: | ---: |
| Benign | 30.0000 bps | 49.4790 bps | 27.4262 bps | 0.0000 bps | +22.0528 USDC |
| Informed | 30.0000 bps | 48.0374 bps | 61.0552 bps | 31.0552 bps | -13.0178 USDC |
| Inventory Improving | 30.0000 bps | 47.4403 bps | 18.0000 bps | 0.0000 bps | +29.4403 USDC |

- On this tape, MARKOUT improves LP net-after-proxy versus fixed by 21.8734% while benign routes save 2.5738 bps versus the fixed pool at equal execution.
- Against volatility pricing at equal execution quality, benign flow saves 22.0528 USDC and inventory-improving flow saves 29.4403 USDC per 10,000 USDC of notional.
- Informed flow pays more by design. Its negative saving is the mechanism's discrimination result, not a trader-acquisition claim.

## Fair-Flow parameter selection

The committed sweep evaluates 21 integer base fees from 10 to 30 bps. The declared rule chooses the lowest candidate that keeps benign and inventory-improving effective fees at or below 30 bps while preserving at least 20% modeled LP-net improvement versus fixed.

That candidate is **18 bps**: benign flow pays 27.4262 bps, inventory-improving flow pays 18.0000 bps, and LP net-after-proxy improves 21.8734% versus fixed.

## Scenario detail

| Scenario | Policy | Gross proxy | Retained fees | LP net after proxy | Avg effective fee (bps) | Expired |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Benign random flow | fixed | 55.326541 | 1008.801000 | 953.474459 | 30.0000 | 0 |
| Benign random flow | volatility | 55.326541 | 1260.767323 | 1205.440782 | 37.4930 | 0 |
| Benign random flow | markout | 55.326541 | 901.168316 | 845.841775 | 26.7992 | 0 |
| Informed flow | fixed | 945.343024 | 974.679000 | 29.335976 | 30.0000 | 0 |
| Informed flow | volatility | 945.343024 | 1456.858735 | 511.515711 | 44.8412 | 0 |
| Informed flow | markout | 945.343024 | 2106.045209 | 1160.702185 | 64.8227 | 0 |
| Inventory-improving flow | fixed | 0.000000 | 979.668000 | 979.668000 | 30.0000 | 0 |
| Inventory-improving flow | volatility | 0.000000 | 1332.213538 | 1332.213538 | 40.7959 | 0 |
| Inventory-improving flow | markout | 0.000000 | 587.800800 | 587.800800 | 18.0000 | 0 |
| Mixed, low volatility | fixed | 284.572311 | 955.047000 | 670.474689 | 30.0000 | 0 |
| Mixed, low volatility | volatility | 284.572311 | 1193.305133 | 908.732822 | 37.4842 | 0 |
| Mixed, low volatility | markout | 284.572311 | 1156.930031 | 872.357720 | 36.3416 | 0 |
| Mixed, high volatility | fixed | 481.287725 | 1079.853000 | 598.565275 | 30.0000 | 0 |
| Mixed, high volatility | volatility | 481.287725 | 2672.411334 | 2191.123609 | 74.2438 | 0 |
| Mixed, high volatility | markout | 481.287725 | 1290.937090 | 809.649365 | 35.8642 | 0 |
| Stale/manipulated reference | fixed | 342.317283 | 999.792000 | 657.474717 | 30.0000 | 0 |
| Stale/manipulated reference | volatility | 342.317283 | 1786.828449 | 1444.511166 | 53.6160 | 0 |
| Stale/manipulated reference | markout | 342.317283 | 805.613840 | 463.296557 | 24.1734 | 63 |

## Limitations

- Synthetic seeded flow is a controlled mechanism comparison, not historical backtesting or a forecast.
- The adverse-selection proxy approximates value transfer to informed flow; it is not exact LVR or position-level LP PnL.
- No concentrated-liquidity ranges, depth, LP shares, inventory path, rebalancing, routing, or demand elasticity are modeled.
- The volatility policy is a declared deterministic baseline, not a claim that its parameters are optimal.
- Callback gas assumes isolated trades with one sample plus one terminal callback; batching can reduce sampling calls and retries can increase them.
- Configured callback gas budgets are not measured public-chain gas spend or lREACT cost.
- A three-pool spot median limits one outlier but is not a manipulation-resistant production oracle.
