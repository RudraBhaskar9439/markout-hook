# MARKOUT Hybrid Testnet Deployment Runbook

Status: automation complete; broadcasts and public evidence require the project owner.

## Active topology

| Component | Network | Role |
| --- | --- | --- |
| `CirclePythObservationPublisher` | Ethereum Sepolia | Verifies a signed Pyth update and emits the canonical observation |
| `SettlementCoordinator` | Unichain Sepolia | Allows the first valid Circle or Reactive delivery to reach the hook |
| `CircleObservationReceiver` | Unichain Sepolia | Authenticates CCTP V2 source, sender, market, and confirmation threshold |
| `ReactiveObservationReceiver` | Unichain Sepolia | Authenticates callback proxy plus ReactVM identity |
| `MarkoutHook` | Unichain Sepolia | Owns custody, validation, settlement, expiry, and claims |
| `MarkoutPulseReactive` | legacy Reactive Lasna | Optionally mirrors the publisher event; owns no protocol state |

Circle is the primary path. The Reactive pulse is optional sponsor integration. If both fail, permissionless expiry
returns the complete provisional surcharge to the trader.

## Funds and secrets

The deployment EOA needs Ethereum Sepolia ETH and Unichain Sepolia ETH. The optional pulse additionally needs legacy
lREACT; Omni iREACT is not used by the active pulse. Circle generic messaging does not burn or bridge USDC.

Keep `PRIVATE_KEY` and `PYTH_API_KEY` secret in an ignored local `.env` or ephemeral shell session. Pyth update bytes,
Circle messages, and attestations are public transaction material, but keep their long values out of Git and chat to
avoid stale configuration and copy errors.

```bash
cp .env.example .env
set -a
source .env
set +a
cast wallet address --private-key "$PRIVATE_KEY"
```

Set `REACTIVE_IDENTITY` to the EOA that will deploy `MarkoutPulseReactive`. Reactive injects this identity into the
first callback argument. A different value makes every callback fail authentication.

The ETH/USDC testnet configuration uses Pyth ETH/USD as a proxy and assumes USDC remains close to one dollar. Do not
present this as a direct pair oracle. Production requires a direct ETH/USDC source or independent USDC/USD validation.

## Read-only preflight

Provide a reliable Ethereum Sepolia RPC, then verify all three networks and external contracts without broadcasting:

```bash
./scripts/check-hybrid-networks.sh
```

The checked Pyth address must be revisited at broadcast time. Pyth documents a Sepolia upgrade scheduled for August
26, 2026; change `PYTH_CONTRACT` to the then-active address instead of relying on the example forever.

## Deployment order

### 1. Deploy the unbound Sepolia publisher

```bash
forge script script/DeployCirclePublisher.s.sol:DeployCirclePublisher \
  --rpc-url "$ETHEREUM_SEPOLIA_RPC_URL" \
  --broadcast \
  -vv
```

Set the printed address as `CIRCLE_PUBLISHER`. The publisher is deliberately unbound so its address can be supplied to
the immutable Unichain receiver.

### 2. Deploy and freeze the Unichain destination

```bash
forge script script/DeployHybridDestination.s.sol:DeployHybridDestination \
  --rpc-url "$ORIGIN_RPC_URL" \
  --broadcast \
  -vv
```

Record the printed `SETTLEMENT_COORDINATOR`, `CIRCLE_RECEIVER`, `REACTIVE_RECEIVER`, `MARKOUT_HOOK`, and hook salt. This
single script deploys both transport receivers, mines the v4 permission address, deploys the hook, and permanently
binds the coordinator to exactly those two sources.

### 3. Permanently bind the Sepolia publisher

```bash
forge script script/BindCirclePublisher.s.sol:BindCirclePublisher \
  --rpc-url "$ETHEREUM_SEPOLIA_RPC_URL" \
  --broadcast \
  -vv
```

This is irreversible. Confirm `CIRCLE_RECEIVER` against the Unichain deployment receipt before broadcasting.

### 4. Deploy the optional legacy Reactive pulse

Choose a small nonzero testnet-only `REACTIVE_DEPLOYMENT_VALUE`; it is denominated in wei of legacy lREACT. The
subscription is created inside the constructor and an unfunded deployment reverts. Then run:

```bash
forge script script/DeployMarkoutPulse.s.sol:DeployMarkoutPulse \
  --rpc-url "$REACTIVE_LEGACY_RPC_URL" \
  --broadcast \
  -vv
```

Set the result as `MARKOUT_PULSE`. This deployment registers one subscription and no cron job. Re-run
`./scripts/check-hybrid-networks.sh`; when address variables are present, it also checks the immutable wiring.

Do not use a generic Anvil fork as the acceptance test for this step: it cannot emulate legacy Lasna's subscription
precompile. The only accepted registration evidence is the successful live deployment receipt plus the subscription
reported by Reactive's public RPC/explorer.

### 5. Initialize the MARKOUT pool

The existing initialization script is transport-independent:

```bash
forge script script/InitializeMarkoutPool.s.sol:InitializeMarkoutPool \
  --rpc-url "$ORIGIN_RPC_URL" \
  --broadcast \
  -vv
```

## One complete settlement

### 1. Execute a swap and record its trade id

```bash
forge script script/ExecuteMarkoutSwap.s.sol:ExecuteMarkoutSwap \
  --rpc-url "$ORIGIN_RPC_URL" \
  --broadcast \
  -vv
```

Wait until the trade's immutable five-minute maturity. Do not publish early merely to create an explorer transaction;
the destination correctly rejects an observation before maturity.

### 2. Fetch and publish the signed Pyth update

```bash
./scripts/fetch-pyth-update.sh
```

Copy the printed `export PYTH_UPDATE_DATA=...` line into the current shell, then publish:

```bash
forge script script/PublishCircleObservation.s.sol:PublishCircleObservation \
  --rpc-url "$ETHEREUM_SEPOLIA_RPC_URL" \
  --broadcast \
  -vv
```

Record the publication transaction as `PUBLISH_TX_HASH`. The same event is now available to the optional Reactive
pulse; no separate Reactive trigger exists.

### 3. Fetch and relay the Circle attestation

```bash
./scripts/fetch-circle-attestation.sh
```

Circle may initially return `404` or a pending status while it confirms the source transaction. That is expected; rerun
the command. Once complete, copy its two `export` lines and relay:

```bash
forge script script/RelayCircleMessage.s.sol:RelayCircleMessage \
  --rpc-url "$ORIGIN_RPC_URL" \
  --broadcast \
  -vv
```

The publisher requests threshold `1000` so an Ethereum observation can arrive inside MARKOUT's ten-minute settlement
window. This fast-confirmed path has bounded source-reorganization risk. A hard-finalized `2000` deployment requires a
longer hook window because Circle documents materially longer Ethereum finality.

### 4. Verify and claim

```bash
cast call "$MARKOUT_HOOK" \
  'getTrade(bytes32)((bytes32,address,address,uint192,uint128,uint64,uint64,uint64,uint8,uint8))' \
  "$TRADE_ID" \
  --rpc-url "$ORIGIN_RPC_URL"

forge script script/ClaimMarkoutRebate.s.sol:ClaimMarkoutRebate \
  --rpc-url "$ORIGIN_RPC_URL" \
  --broadcast \
  -vv
```

If neither transport settles before expiry, call `expireTrade(bytes32)` permissionlessly on the hook, then claim the
full surcharge. That fallback is an intended safety path, not an administrator rescue.

## Evidence policy

Copy `deployments/hybrid.example.json` to a dated manifest. Enter only mined addresses and successful transaction
hashes. `circleLive` requires publication, attestation relay, destination receiver, settlement, and claim evidence.
`reactiveLive` may be `true` only when a public Unichain callback transaction from the configured proxy exists.

Official operational references:

- [Circle messages and attestations API](https://developers.circle.com/api-reference/cctp/all/get-messages-v2)
- [Circle finality and block confirmations](https://developers.circle.com/cctp/concepts/finality-and-block-confirmations)
- [Pyth price update retrieval](https://docs.pyth.network/price-feeds/core/fetch-price-updates)
- [Reactive events and callbacks](https://dev.reactive.network/legacy/events-%26-callbacks)
