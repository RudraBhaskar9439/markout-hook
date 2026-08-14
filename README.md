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
- [Dependency policy](docs/DEPENDENCIES.md)
- [Verification protocol](docs/VERIFICATION.md)
- [Project decisions](docs/DECISIONS.md)

## Current status

**Phase 2 — automated gate passed; reviewer approval pending.** Phase 1 proves bounded provisional-surcharge custody
across all four v4 swap modes. Phase 2 freezes the deterministic markout, price-normalization,
observation-validation, and rebate-allocation rules before they are connected to persistent hook state.

## Architecture

```text
src/
├── base/        reusable PoolManager custody and accounting
├── hooks/       replaceable surcharge policies
├── interfaces/  stable external errors, events, and read API
├── libraries/   accounting, price, observation, and markout primitives
└── types/       shared domain types
```

`BaseProvisionalSurcharge` isolates v4 custody. `MarkoutSettlementEngine` isolates pure economic evaluation. Phase 3
will connect these boundaries with pending-trade state, authenticated settlement, and pull-based rebate claims.

## Local verification

Prerequisites: Git, Foundry `v1.7.1`, and recursive submodules.

```bash
git submodule update --init --recursive
./scripts/verify-phase-2.sh
```

The cumulative gate checks formatting, compilation and bytecode size, lint, Phase 1 accounting, Phase 2 mathematics,
stateful invariants, and the committed gas snapshot. See the
[Phase 2 verification guide](docs/PHASE_2_VERIFICATION.md) for expected evidence and targeted commands.

## Security status

This repository is production-shaped, not production-certified. Its implemented surfaces have defensive parsing,
explicit bounds, conservation checks, and stateful invariants, but the complete system has not yet reached the
dedicated threat-model, static-analysis, and external-review phase. Do not deploy it with real funds.
