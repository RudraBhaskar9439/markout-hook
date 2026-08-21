# MARKOUT

MARKOUT is a research-oriented Uniswap v4 hook that settles a provisional hook surcharge after observing a trade's post-execution markout.

Ordinary or inventory-improving flow receives a rebate. Flow that is followed by a favorable market move for the
trader retains more of the surcharge for LP protection. Circle CCTP V2 is the primary authenticated cross-chain
observation transport. A minimal Reactive Contract may deliver the same observation as an optional accelerator, while
permissionless expiry prevents either transport from becoming a custody dependency.

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
- Pyth-verified observations transported primarily through fast-confirmed Circle CCTP V2 messages
- An optional stateless Reactive delivery path racing the same observation safely
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
- [Phase 6 research experiment](experiments/README.md)
- [Phase 6 verification guide](docs/PHASE_6_VERIFICATION.md)
- [Phase 7 threat model](docs/THREAT_MODEL.md)
- [Phase 7 static-analysis report](docs/STATIC_ANALYSIS.md)
- [Phase 7 verification guide](docs/PHASE_7_VERIFICATION.md)
- [Phase 8 judge application](web/README.md)
- [Phase 8 verification guide](docs/PHASE_8_VERIFICATION.md)
- [Judge demo script](docs/DEMO_SCRIPT.md)
- [Final submission checklist](docs/SUBMISSION_CHECKLIST.md)
- [Phase 9 draft verification guide](docs/PHASE_9_DRAFT_VERIFICATION.md)
- [Hybrid settlement architecture](docs/HYBRID_SETTLEMENT.md)
- [Phase 11 coordinator verification](docs/PHASE_11_VERIFICATION.md)
- [Phase 12 Circle verification](docs/PHASE_12_VERIFICATION.md)
- [Phase 13 Reactive pulse verification](docs/PHASE_13_VERIFICATION.md)
- [Phase 14 hybrid deployment verification](docs/PHASE_14_VERIFICATION.md)
- [UHI10 presentation deck](presentation/MARKOUT-UHI10.pptx)
- [Active hybrid testnet deployment runbook](docs/HYBRID_TESTNET_DEPLOYMENT.md)
- [Archived Omni deployment runbook](docs/TESTNET_DEPLOYMENT.md)
- [Dependency policy](docs/DEPENDENCIES.md)
- [Verification protocol](docs/VERIFICATION.md)
- [Project decisions](docs/DECISIONS.md)

## Current status

**Phase 14 public Circle gate complete; optional Reactive delivery remains under observation.** The previous Omni
scheduler remains committed as reproducible research and outage evidence. The active topology now uses a one-time-bound
settlement coordinator, a Pyth-backed Ethereum Sepolia publisher, an authenticated Circle receiver, and an optional
stateless Reactive pulse. After a real Uniswap v4 swap matured, its Pyth observation was attested through Circle,
settled on Unichain, and claimed; the dated deployment manifest records the public evidence and measured latency. Reactive
receives live credit only if its callback is independently visible.

## Architecture

```mermaid
flowchart LR
    subgraph S[Ethereum Sepolia]
        P[Pyth update] --> PUB[Circle observation publisher]
    end

    subgraph C[Circle CCTP V2]
        PUB -->|fast-confirmed generic message| TX[Circle attestation]
    end

    subgraph RN[Reactive Network optional]
        PUB -. same observation event .-> RP[Stateless Reactive pulse]
    end

    subgraph U[Unichain Sepolia]
        T[Trader] --> PM[Uniswap v4 PoolManager]
        PM --> H[MARKOUT Hook]
        H -->|escrow| Q[Pending trade]
        TX --> CR[Circle receiver]
        RP -. authenticated callback .-> RR[Reactive receiver]
        CR --> SC[Settlement coordinator]
        RR --> SC
        SC -->|first valid delivery| H
        H --> R[Trader rebate]
        H --> L[LP protection reserve]
    end
```

The hook alone owns custody and economic validation. Circle and Reactive cannot select beneficiaries or bypass
maturity, freshness, confidence, solvency, or terminal-state checks. Circle is the primary transport. Reactive is
useful when available but cannot block Circle delivery or the full-rebate expiry path.

```text
src/
├── adapters/    authenticated settlement boundary
├── base/        reusable PoolManager custody and accounting
├── circle/      Pyth publisher and authenticated CCTP V2 receiver
├── hooks/       surcharge policy and complete MARKOUT lifecycle
├── interfaces/  stable external errors, events, and read API
├── libraries/   accounting, price, observation, and markout primitives
├── reactive/    research scheduler and optional stateless pulse
├── reference/   authenticated, source-specific price sampling
├── settlement/  immutable multi-transport coordinator
└── types/       shared domain types
```

`BaseProvisionalSurcharge` isolates v4 custody. `MarkoutSettlementEngine` isolates pure economic evaluation.
`MarkoutHook` composes them into a replay-protected state machine. `SettlementCoordinator` makes Circle and Reactive
delivery at-least-once across transports. `CirclePythObservationPublisher` verifies and normalizes Pyth data before
requesting a fast-confirmed Circle message; `CircleObservationReceiver` authenticates its destination envelope.

## Local verification

Prerequisites: Git, Foundry `v1.7.1`, Python `3.12`, uv `0.12.5`, and recursive submodules.

```bash
git submodule update --init --recursive
./scripts/verify-phase-5-local.sh
./scripts/verify-phase-6.sh
./scripts/verify-phase-7.sh
./scripts/verify-phase-8.sh
./scripts/verify-phase-9-draft.sh
./scripts/verify-phase-11.sh
./scripts/verify-phase-12.sh
./scripts/verify-phase-13.sh
./scripts/verify-phase-14-local.sh
./scripts/verify-hybrid-release-candidate.sh
```

The cumulative local gate checks formatting, compilation and bytecode size, lint, all earlier accounting and lifecycle
properties, autonomous sampling through the official Reactive simulator, stateful invariants, readable demos, the
committed gas snapshot, hybrid transport races, and deployment-tool syntax. See the
[Phase 5 verification guide](docs/PHASE_5_VERIFICATION.md) for the local/live boundary.

The Phase 6 command repeats the deployment-independent Solidity gate, then regenerates the seeded research artifacts
in a temporary directory and byte-compares them with the committed results. See the
[Phase 6 verification guide](docs/PHASE_6_VERIFICATION.md) for the metric boundary and observed regressions.

The Phase 7 command additionally verifies the locked Python security environment and runs Slither with a gate that
rejects every medium- or high-severity result. See the [Phase 7 verification guide](docs/PHASE_7_VERIFICATION.md) for
the adversarial cases, reviewed low-severity findings, and residual risks.

The Phase 8 command adds the Cloudflare-compatible judge application: lint, production build, server-rendered product
tests, exact social-card dimensions, and a production-dependency audit. Run `./scripts/run-phase-8-demo.sh` for the
one-command local demo, then open `http://localhost:3000`.

The Phase 9 command validates the submission package and the nine-slide PowerPoint archive. The final deck records the
explorer-backed Circle settlement and claim while keeping the unobserved Reactive callback explicitly optional.

## Security status

This repository is production-shaped, not production-certified. Its implemented surfaces have defensive parsing,
explicit bounds, conservation checks, adversarial tests, stateful invariants, and zero medium/high Slither findings.
Phase 7 is an internal engineering review, not an independent audit. The ETH/USD-as-ETH/USDC testnet proxy, fast
Circle confirmation, immutable configuration, unsupported exotic tokens, and undistributed LP reserve remain explicit
prototype limitations. Do not deploy it with real funds.
