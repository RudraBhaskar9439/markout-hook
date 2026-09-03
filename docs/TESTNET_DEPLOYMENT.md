# MARKOUT Archived Omni Testnet Deployment Runbook

> This runbook preserves the Phase 5 Omni deployment and outage evidence. It is not the active topology. The final
> submission architecture is Reactive-first; see [Reactive Lifecycle Specification](REACTIVE_LIFECYCLE.md) and
> [Reactive-First Settlement Architecture](HYBRID_SETTLEMENT.md). The later two-transport rollout is retained in the
> [historical hybrid runbook](HYBRID_TESTNET_DEPLOYMENT.md).

This runbook deploys the complete Phase 5 topology to Unichain Sepolia and Reactive Lasna Omni. It intentionally stops
before any broadcast unless the operator provides a dedicated funded testnet key.

## Network topology

| Component | Network | Role |
| --- | --- | --- |
| `MarkoutHook` | Unichain Sepolia (1301) | Escrows the provisional surcharge and records trades |
| settlement adapter | Unichain Sepolia (1301) | Authenticates and forwards Reactive settlement callbacks |
| median sampler | Unichain Sepolia (1301) | Samples three WETH/USDC v3 pools on demand |
| `MarkoutReactive` | Reactive Lasna Omni (5318007) | Observes, schedules, samples, retries, settles, and acknowledges |

The reviewed public addresses are versioned in `config/uhi10-testnet.json`. Re-run
`./scripts/check-phase-5-networks.sh` immediately before broadcasting because testnet infrastructure can change.

## Operator prerequisites

Use one dedicated testnet EOA for both chains. Reactive injects the Lasna deployer's address into every destination
callback, so `REACTIVE_IDENTITY` must equal that EOA even if a different EOA deploys destination contracts.

The EOA needs:

- Unichain Sepolia ETH for deployments, liquidity, callbacks, and WETH wrapping;
- Unichain Sepolia Circle test USDC for v4 bootstrap liquidity and test swaps; and
- at least 1 Lasna Omni lREACT for the Reactive deployment (currently estimated near 0.63 lREACT) plus ongoing
  scheduler execution.

Never paste the private key into documentation, chat, shell history, or a committed file. Create a local `.env` from
`.env.example`; `.env` is ignored by Git.

```bash
cp .env.example .env
set -a
source .env
set +a
```

Confirm the public identity without printing the secret:

```bash
cast wallet address --private-key "$PRIVATE_KEY"
```

Set that resulting address as `REACTIVE_IDENTITY`, then run the read-only preflight:

```bash
./scripts/check-phase-5-networks.sh
```

## Deployment order

### 1. Deploy the destination settlement boundary

```bash
forge script script/DeployReactiveMarkoutHook.s.sol:DeployReactiveMarkoutHook \
  --rpc-url "$ORIGIN_RPC_URL" \
  --broadcast \
  -vv
```

Record the adapter and hook addresses as `MARKOUT_SETTLEMENT_ADAPTER` and `MARKOUT_HOOK`. The script mines a hook
address carrying exactly the `afterSwap` and return-delta permission bits, deploys through the canonical CREATE2
deployer, and permanently binds the adapter.

### 2. Deploy the autonomous median sampler

```bash
forge script script/DeployUniswapV3MedianReferenceSampler.s.sol:DeployUniswapV3MedianReferenceSampler \
  --rpc-url "$ORIGIN_RPC_URL" \
  --broadcast \
  -vv
```

Set both `REFERENCE_FEED` and `REFERENCE_SAMPLER` to the resulting address.

### 3. Initialize the MARKOUT pool and bootstrap liquidity

The script copies its initial square-root price from `POOL_INITIAL_PRICE_REFERENCE` unless
`POOL_INITIAL_SQRT_PRICE_X96` is explicitly supplied. The reference pool must have the identical sorted currency pair.

```bash
forge script script/InitializeMarkoutPool.s.sol:InitializeMarkoutPool \
  --rpc-url "$ORIGIN_RPC_URL" \
  --broadcast \
  -vv
```

This testnet-only operator path uses Uniswap's deployed `PoolModifyLiquidityTest`. It approves the router and adds one
full-range position. Inspect the simulated token deltas before accepting the broadcast.

### 4. Deploy the Reactive scheduler and subscriptions

```bash
forge script script/DeployMarkoutReactive.s.sol:DeployMarkoutReactive \
  --rpc-url "$REACTIVE_RPC_URL" \
  --broadcast \
  -vv
```

Record the resulting address as `MARKOUT_REACTIVE`. Its constructor registers five exact subscriptions: request,
settled, expired, normalized reference price for one market, and canonical `Cron10`.

Lasna Omni separates the subscription/payment service from the cron-log emitter. Set `REACTIVE_SERVICE` to
`0x8888888888888888888888888888888888888888` and `REACTIVE_CRON_EMITTER` to
`0x0000000000000000000000000000000000fffFfF`. The deploy script rejects either value if it is wrong on chain
`5318007`.

Before funding or producing a swap, export the new address and repeat the preflight. The check reads both immutable
addresses. A scheduler authenticated to the cron emitter cannot accept Omni event delivery or pay Omni service debt;
a scheduler subscribed to cron at the payment service will ingest trade events but never receive `Cron10`.

```bash
export MARKOUT_REACTIVE=<new-scheduler-address>
./scripts/check-phase-5-networks.sh
```

### 5. Fund automation and settle any debt

Choose small testnet-only balances appropriate for current gas conditions; do not copy these examples to mainnet.

```bash
cast send "$MARKOUT_REACTIVE" --value 0.1ether --rpc-url "$REACTIVE_RPC_URL" --private-key "$PRIVATE_KEY"
cast send "$MARKOUT_SETTLEMENT_ADAPTER" --value 0.01ether --rpc-url "$ORIGIN_RPC_URL" --private-key "$PRIVATE_KEY"
cast send "$REFERENCE_SAMPLER" --value 0.01ether --rpc-url "$ORIGIN_RPC_URL" --private-key "$PRIVATE_KEY"

cast send "$MARKOUT_REACTIVE" 'coverDebt()' --rpc-url "$REACTIVE_RPC_URL" --private-key "$PRIVATE_KEY"
cast send "$MARKOUT_SETTLEMENT_ADAPTER" 'coverDebt()' --rpc-url "$ORIGIN_RPC_URL" --private-key "$PRIVATE_KEY"
cast send "$REFERENCE_SAMPLER" 'coverDebt()' --rpc-url "$ORIGIN_RPC_URL" --private-key "$PRIVATE_KEY"
```

Check all three balances and inspect Reactive debt before executing a trade.

## Execute and observe acceptance trades

Configure `SWAP_ZERO_FOR_ONE`, `SWAP_EXACT_INPUT`, and `SWAP_AMOUNT`, then run:

```bash
forge script script/ExecuteMarkoutSwap.s.sol:ExecuteMarkoutSwap \
  --rpc-url "$ORIGIN_RPC_URL" \
  --broadcast \
  -vv
```

Record the printed trade ID and swap hash. No EOA should call `settleTrade`, adapter `settle`, sampler `sample`, or
`expire`; wait for `Cron10` and Reactive callbacks. Query the destination state with:

```bash
cast call "$MARKOUT_HOOK" \
  'getTrade(bytes32)((bytes32,address,address,uint192,uint128,uint64,uint64,uint64,uint8,uint8))' \
  "$TRADE_ID" \
  --rpc-url "$ORIGIN_RPC_URL"
```

After settlement, set `CLAIM_CURRENCY` to the trade's surcharge currency and claim:

```bash
forge script script/ClaimMarkoutRebate.s.sol:ClaimMarkoutRebate \
  --rpc-url "$ORIGIN_RPC_URL" \
  --broadcast \
  -vv
```

Repeat with a materially different size or direction and preserve both public traces. Fill a copy of
`deployments/phase-5.example.json`; never edit the example itself with guessed hashes.

## Required explorer evidence

- Unichain Sepolia: `https://sepolia.uniscan.xyz/address/<address>`
- Reactive Lasna Omni: `https://lasna-omni.reactscan.net/address/<address>`
- both swap transactions and `MarkoutRequested` logs;
- both sampler callbacks and normalized median events;
- both settlement callbacks and terminal hook events;
- Reactive acknowledgement/finalized state; and
- one `RebateClaimed` transaction.

Phase 5 passes only after this evidence exists publicly and the manifest contains real values.
