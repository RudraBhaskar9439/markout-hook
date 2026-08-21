# Fair-Flow Release Candidate

Fair-Flow is MARKOUT's trader-adoption profile. It keeps the outcome-conditioned 50 bps surcharge unchanged and lowers
the Uniswap v4 base LP fee from 30 to 18 bps for a new pool.

```text
maximum upfront charge = 18 bps base + 50 bps provisional = 68 bps
final effective fee     = 18 bps base + retained portion of the provisional charge
```

The existing public pool remains 30 + 50 bps. Fair-Flow is verified source code and research evidence, not a relabeling
of that deployment.

## Why a trader routes here

On the common 768-trade tape and at identical execution quality:

| Flow | Fixed | Volatility | Fair-Flow | Saving vs fixed per $10k | Saving vs volatility per $10k |
| --- | ---: | ---: | ---: | ---: | ---: |
| Benign | 30.0000 bps | 49.4790 bps | 27.4262 bps | $2.5738 | $22.0528 |
| Inventory-improving | 30.0000 bps | 47.4403 bps | 18.0000 bps | $12.0000 | $29.4403 |
| Informed | 30.0000 bps | 48.0374 bps | 61.0552 bps | −$31.0552 | −$13.0178 |

The routing thesis is deliberately asymmetric: good flow is cheaper before assuming any liquidity improvement, while
realized adverse flow funds LP protection. A router still evaluates price impact, slippage, gas, settlement delay, and
rebate value alongside the fee.

## Why 18 bps

The committed sweep evaluates every integer base fee from 10 through 30 bps. Its selection rule was declared in the
experiment configuration:

1. benign effective fee must be at most 30 bps;
2. inventory-improving effective fee must be at most 30 bps; and
3. modeled LP net-after-proxy must improve by at least 20% versus fixed 30 bps.

Seventeen bps produces 16.7325% LP improvement and fails. Eighteen bps produces 21.8734% and is the lowest eligible
candidate. The complete frontier is in
[fair_flow_sweep.json](../experiments/results/fair_flow_sweep.json), with a corresponding chart in
[fair_flow_fee_frontier.svg](../experiments/charts/fair_flow_fee_frontier.svg).

## Rebate experience

The next hook version retains beneficiary-controlled claims and adds `claimRebateFor(beneficiary, currency)`. Any
relayer may sponsor the gas, but the function always transfers to the beneficiary. The sponsor cannot select a
recipient, redirect funds, or replay a completed claim. This permits a pool operator or solver to hide claim gas from
the trader without receiving custody authority.

## Evidence boundary

- The sweep is a controlled synthetic comparison, not historical backtesting or a volume forecast.
- The 21.8734% result uses a pool-level adverse-selection proxy, not exact LVR or position-level LP profit.
- The candidate does not yet model concentrated-liquidity depth, endogenous routing, fee-sensitive demand, or claim
  gas in the trader's all-in quote.
- The LP protection reserve is fully accounted but is not automatically reinvested as liquidity in this prototype.
- Deploying a separate 18 bps pool and producing a new public lifecycle require explicit owner approval.

## Verification

```bash
./experiments/run.sh
forge test -q
cd web && npm run verify
```
