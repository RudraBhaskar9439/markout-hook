# Historical Mainnet Robustness Replay

This appendix replays a frozen Ethereum mainnet event window from the canonical Uniswap v3 USDC/WETH 0.05% pool
through the same fixed, volatility, and MARKOUT policy implementations used by the primary experiment.

It answers a narrow question: can the policy pipeline ingest real signed swap deltas and pool prices, construct a
five-minute directional markout, and preserve deterministic fee accounting? It does not claim that one short window
is representative of all markets.

## Reproduce the analysis offline

```bash
./experiments/historical/run.sh
```

This reads the committed `data/swaps.csv`, regenerates the artifacts in a temporary directory, and byte-compares them
with `results/`. No RPC is used by the verification gate.

## Independently refetch the source window

```bash
PYTHONPATH=experiments python3 experiments/historical/fetch.py \
  --config experiments/historical/config.json \
  --output /tmp/markout-mainnet-swaps.csv \
  --rpc-url "$ETHEREUM_RPC_URL"

diff -u experiments/historical/data/swaps.csv /tmp/markout-mainnet-swaps.csv
```

The RPC must provide archive `eth_getLogs` and `eth_getBlockByNumber` access. The committed data includes block hashes,
transaction hashes, and log indexes so every row can be independently checked against Ethereum.

## Boundary

- The five-minute reference is the same pool's later marginal price, not an independent oracle.
- The execution proxy is post-swap `sqrtPriceX96`, not a volume-weighted fill.
- Outcome buckets are descriptive ex-post markout bands, not predictive toxicity labels.
- The adverse-selection quantity remains a pool-level proxy, not exact LVR or individual LP PnL.
- Routing, volume elasticity, concentrated-liquidity depth, range occupancy, rebalancing, and gas are not modeled.
