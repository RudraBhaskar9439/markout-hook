# Phase 5 Verification Guide

Phase 5 moves MARKOUT from a pre-published mock feed to an autonomous live-source path. At maturity, Reactive Network
requests a destination-chain sample; the sampler reads three Uniswap v3 WETH/USDC fee-tier pools, emits their median
as a normalized observation, and that event causes Reactive to settle the pending v4 trade.

## Current gate status

The deployment-independent portion of Phase 5 is complete. The code, public-network configuration, deployment
scripts, and complete local transport simulation pass. The destination contracts and a funded Lasna Omni scheduler
are public. The live gate remains open until Reactive delivers two complete public settlement traces.

All operator scripts were also exercised against local forks of current public state: adapter/hook deployment,
sampler deployment and live three-pool sampling, v4 initialization and liquidity, swap/trade creation, Lasna scheduler
deployment with five subscriptions, and rebate claiming. These fork transactions are disposable verification, not
public deployment evidence.

The August 20 acceptance attempt proved request ingestion, the distinct live cron emitter, callback emission, debt
payment, expiry transition, terminal acknowledgement, and fail-open recovery. Reactive did not post or deliver a
destination callback during the maturity and grace window. The exact transactions are preserved in
[`deployments/phase-5-attempt-2026-08-20.json`](../deployments/phase-5-attempt-2026-08-20.json); that attempt is not
represented as a successful settlement.

The failed trace also showed that Omni's ten-second `Cron10` cadence can make an unacknowledged terminal callback
expensive. Repository head now rate-limits each trade's settlement and expiry retries to once per 60 seconds. The
August 20 scheduler predates that hardening and must be replaced before the next acceptance attempt.

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

- two swaps that both settle through Reactive without an EOA calling settlement;
- different terminal retention outcomes and at least one claimed rebate;
- successful sampler and settlement callback transactions on Unichain; and
- a passing deployment manifest derived from `deployments/phase-5.example.json`.

The exact broadcast and monitoring procedure is in [TESTNET_DEPLOYMENT.md](TESTNET_DEPLOYMENT.md).

## Lasna Omni service and cron-emitter invariants

The configured scheduler is accepted for live evidence only when its immutable `subscriptionService()` is
`0x8888888888888888888888888888888888888888` and its immutable `cronEmitter()` is
`0x0000000000000000000000000000000000fffFfF`. The network preflight enforces both whenever `MARKOUT_REACTIVE` is
exported. Omni uses the first address for subscription, payment, and authenticated `react` delivery, while its live
cron logs still originate from the second. The focused autonomous test keeps these roles at different addresses so a
future refactor cannot silently conflate them.
