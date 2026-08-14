# MARKOUT

MARKOUT is a research-oriented Uniswap v4 hook that settles a provisional hook surcharge after observing a trade's post-execution markout.

Ordinary or inventory-improving flow receives a rebate. Flow that is followed by a favorable market move for the trader retains more of the surcharge for LP protection. Reactive Network is the autonomous observation and settlement layer: it watches hook and reference-market events, waits for the selected maturity horizon, and sends an authenticated callback to settle each trade.

## UHI10 alignment

- Primary UHI idea: **Fee-Rebate Systems tied to order-flow quality**
- Secondary idea: **Hybrid Routing between private orderflow and public Uniswap pools**
- Theme: **Sustainable Liquidity and MEV Protection**

## Research question

Can delayed, outcome-based fee settlement reduce LP adverse selection while charging benign traders less than a volatility-only dynamic-fee policy?

## MVP scope

- One ETH/USDC-style Uniswap v4 pool on Unichain Sepolia
- A fixed base LP fee plus a bounded provisional hook surcharge
- One deterministic markout horizon and one reference-market stream
- Reactive Network event subscriptions, maturity scheduling, and authenticated callbacks
- Pull-based trader rebates and an LP protection reserve
- A reproducible experiment comparing fixed fee, volatility fee, and MARKOUT

MARKOUT is an experimental hackathon prototype, not audited production software.

## Project documents

- [Roadmap](ROADMAP.md)
- [Mechanism specification](docs/MECHANISM.md)
- [Phase 1 accounting specification](docs/ACCOUNTING.md)
- [Phase 1 verification guide](docs/PHASE_1_VERIFICATION.md)
- [Phase 2 economic specification](docs/ECONOMICS.md)
- [Phase 2 verification guide](docs/PHASE_2_VERIFICATION.md)
- [Phase 3 lifecycle and accounting specification](docs/LIFECYCLE.md)
- [Phase 3 verification guide](docs/PHASE_3_VERIFICATION.md)
- [Reactive lifecycle specification](docs/REACTIVE_LIFECYCLE.md)
- [Phase 4 verification guide](docs/PHASE_4_VERIFICATION.md)
- [Phase 5 verification guide](docs/PHASE_5_VERIFICATION.md)
- [Testnet deployment runbook](docs/TESTNET_DEPLOYMENT.md)
- [Dependency policy](docs/DEPENDENCIES.md)
- [Verification protocol](docs/VERIFICATION.md)
- [Project decisions](docs/DECISIONS.md)

## Current status

**Phase 5 — deployment-ready, live gate open.** MARKOUT now autonomously requests a three-pool median reference sample
at maturity and completes the sample-event-to-settlement-callback chain in the full local Reactive simulator. Current
Unichain Sepolia and Lasna Omni dependencies pass a read-only public-network preflight. A funded testnet signer and two
public settlement traces are still required before Phase 5 can be marked passed.

## Architecture

```text
src/
├── adapters/    authenticated settlement boundary
├── base/        reusable PoolManager custody and accounting
├── hooks/       surcharge policy and complete MARKOUT lifecycle
├── interfaces/  stable external errors, events, and read API
├── libraries/   accounting, price, observation, and markout primitives
├── reactive/    event subscriptions, maturity scheduling, callback retries
├── reference/   authenticated, source-specific price sampling
└── types/       shared domain types
```

`BaseProvisionalSurcharge` isolates v4 custody. `MarkoutSettlementEngine` isolates pure economic evaluation.
`MarkoutHook` composes them into a replay-protected state machine. `MarkoutReactive` independently orchestrates events
and time, while `ReactiveMarkoutSettlementAdapter` is the narrow destination authentication boundary.

## Local verification

Prerequisites: Git, Foundry `v1.7.1`, and recursive submodules.

```bash
git submodule update --init --recursive
./scripts/verify-phase-5-local.sh
```

The cumulative local gate checks formatting, compilation and bytecode size, lint, all earlier accounting and lifecycle
properties, autonomous sampling through the official Reactive simulator, stateful invariants, readable demos, the
committed gas snapshot, and current public testnet dependencies. See the
[Phase 5 verification guide](docs/PHASE_5_VERIFICATION.md) for the local/live boundary.

## Security status

This repository is production-shaped, not production-certified. Its implemented surfaces have defensive parsing,
explicit bounds, conservation checks, and stateful invariants, but the complete system has not yet reached the
dedicated threat-model, static-analysis, and external-review phase. Do not deploy it with real funds.
