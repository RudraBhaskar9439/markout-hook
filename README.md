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
- [Dependency policy](docs/DEPENDENCIES.md)
- [Verification protocol](docs/VERIFICATION.md)
- [Project decisions](docs/DECISIONS.md)

## Current status

**Phase 1 — automated gate passed; reviewer approval pending.** The branch proves bounded provisional-surcharge custody
across all four v4 swap modes. It is intentionally not the complete MARKOUT lifecycle yet.

## Phase 1 architecture

```text
src/
├── base/        reusable PoolManager custody and accounting
├── hooks/       replaceable surcharge policies
├── interfaces/  stable external errors, events, and read API
├── libraries/   hook-data, arithmetic, and swap-delta primitives
└── types/       shared domain types
```

`FixedBpsProvisionalSurchargeHook` is the Phase 1 proof policy. Later phases can replace its quote function without
duplicating the v4 accounting path in `BaseProvisionalSurcharge`.

## Local verification

Prerequisites: Git, Foundry `v1.7.1`, and recursive submodules.

```bash
git submodule update --init --recursive
./scripts/verify-phase-1.sh
```

The gate checks formatting, compilation and bytecode size, lint, unit tests, real PoolManager integration tests,
stateful invariants, and the committed gas snapshot. See the
[verification guide](docs/PHASE_1_VERIFICATION.md) for expected evidence and targeted commands.

## Security status

This repository is production-shaped, not production-certified. The Phase 1 surface has defensive parsing, explicit
user limits, full-balance conservation checks, and stateful invariants, but the complete system has not yet reached
the dedicated threat-model, static-analysis, and external-review phase. Do not deploy it with real funds.
