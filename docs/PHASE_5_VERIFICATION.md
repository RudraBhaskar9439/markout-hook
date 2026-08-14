# Phase 5 Verification Guide

Phase 5 moves MARKOUT from a pre-published mock feed to an autonomous live-source path. At maturity, Reactive Network
requests a destination-chain sample; the sampler reads three Uniswap v3 WETH/USDC fee-tier pools, emits their median
as a normalized observation, and that event causes Reactive to settle the pending v4 trade.

## Current gate status

The deployment-independent portion of Phase 5 is complete. The code, public-network configuration, deployment
scripts, and complete local transport simulation pass. The live gate remains open until a funded testnet signer
deploys the contracts and two public settlement traces are recorded in a deployment manifest.

All operator scripts were also exercised against local forks of current public state: adapter/hook deployment,
sampler deployment and live three-pool sampling, v4 initialization and liquidity, swap/trade creation, Lasna scheduler
deployment with five subscriptions, and rebate claiming. These fork transactions are disposable verification, not
public deployment evidence.

This distinction is deliberate: local success is not represented as a live deployment.

## One-command local and public-network preflight

```bash
./scripts/verify-phase-5-local.sh
```

The command runs the cumulative Phase 1–5 local suite and performs read-only checks against Unichain Sepolia and
Reactive Lasna Omni. It requires internet access but no private key and broadcasts no transaction.

## Focused autonomous acceptance trace

```bash
./scripts/run-phase-5-demo.sh
```

The test executes a real local v4 swap and proves this causal chain:

```text
MarkoutRequested
  -> Cron10
  -> authenticated callback to three-pool sampler
  -> NormalizedReferencePricePublished
  -> authenticated callback to settlement adapter
  -> MarkoutSettled
  -> Reactive terminal acknowledgement
```

Exactly two callbacks are emitted after maturity: one for sampling and one for settlement. A later cron emits no
callback because the record is final.

## Properties covered

- WETH/USDC prices are normalized to quote-per-base X18 despite reverse token ordering and different decimals.
- Three configured pools must be unique and must contain exactly the configured token pair.
- Each pool must satisfy an immutable minimum-liquidity floor.
- The median limits the effect of one deviating pool; excessive dispersion rejects the entire sample.
- Confidence is deterministically `10,000 - dispersionBps` and can never fall below MARKOUT's minimum.
- Direct callers and callbacks with a different injected Reactive identity are rejected.
- Callback contracts can hold destination gas funds and pay only the configured callback proxy.
- No sample is requested before maturity, after expiry, or more than once within the retry cooldown.
- The canonical live `Cron10` topic is tested directly rather than relying on a library constant.

## Honest oracle boundary

This source is a testnet transport proof, not a production oracle. Medianing three fee tiers makes a one-pool outlier
insufficient, but all three inputs are spot pools on one chain and currently have one-slot observation histories.
They do not provide a robust TWAP, independent venue diversity, or manipulation resistance suitable for real funds.
Phase 6 measures manipulated-source behavior, and a production deployment would replace this module behind the same
normalized-feed interface.

## Live acceptance evidence still required

- destination adapter, hook, sampler, pool, and Reactive scheduler addresses;
- transaction hashes and block numbers for every deployment;
- two swaps that both settle through Reactive without an EOA calling settlement;
- different terminal retention outcomes and at least one claimed rebate;
- callback and scheduler funding/debt evidence; and
- explorer links recorded in a copy of `deployments/phase-5.example.json`.

The exact broadcast and monitoring procedure is in [TESTNET_DEPLOYMENT.md](TESTNET_DEPLOYMENT.md).
