# MARKOUT

### Outcome-priced liquidity for Uniswap v4

MARKOUT is a Uniswap v4 hook that charges a trade according to its observed post-trade outcome. It combines a low
base fee with a bounded provisional surcharge, waits for a five-minute directional markout, and then allocates the
provisional amount between a trader rebate and LP protection.

[Live judge dashboard](https://markout-uhi10.rbrudra9439.chatgpt.site) ·
[Public evidence](docs/EVIDENCE.md) ·
[Mechanism specification](docs/MECHANISM.md) ·
[Presentation deck](presentation/MARKOUT-UHI10.pptx)

> **UHI10 theme:** Sustainable Liquidity and MEV Protection<br>
> **Status:** Experimental testnet prototype. Not audited and not suitable for real funds.

![MARKOUT complete architecture](docs/diagrams/MARKOUT_ARCHITECTURE_OVERVIEW.png)

[Editable Draw.io architecture](docs/diagrams/MARKOUT_ARCHITECTURE.drawio) ·
[4K video export](docs/diagrams/MARKOUT_COMPLETE_ARCHITECTURE_4K.png) ·
[PDF export](docs/diagrams/MARKOUT_COMPLETE_ARCHITECTURE.pdf)

## The problem

AMMs normally set a fee before they know whether a swap was benign, inventory-improving, or followed by a favorable
price move for the trader. A volatility-linked fee can compensate LPs, but it raises prices for every trader during a
volatile period—even when an individual trade was harmless.

MARKOUT tests a different mechanism:

- charge a low base fee at execution;
- escrow a strictly bounded provisional amount;
- observe a signed reference price after a fixed horizon;
- use **directional markout as a risk proxy**, not as a claim of exact LP loss;
- refund fair flow and retain more from adverse flow for LP protection.

The mechanism evaluates outcomes rather than wallets. It uses no allowlist, identity score, or trader blacklist.

## How it works

| Step | System | Responsibility |
| --- | --- | --- |
| 1. Execute | Uniswap v4 on Unichain Sepolia | The trader swaps at an 18 bps base fee plus a refundable 50 bps provisional amount. |
| 2. Record | `MarkoutHook` | The hook records execution price, direction, beneficiary, maturity, and expiry under a unique trade ID. |
| 3. Observe | Pyth on Ethereum Sepolia | A signed delayed ETH price is normalized with its publish time and confidence. |
| 4. Orchestrate | Reactive Network | The lifecycle engine watches trade and price events, waits for maturity, matches evidence, retries, acknowledges, and requests settlement or expiry without a privileged keeper. |
| 5. Settle | Unichain contracts | The coordinator authenticates the delivery and the hook computes the directional allocation exactly once. |

Every trade reaches one of three safe terminal outcomes:

| Outcome | Trader | Liquidity providers |
| --- | --- | --- |
| Benign or inventory-improving | Receives a rebate; the final fee can fall to 18 bps | Earn the base fee |
| Adverse or informed | Pays some or all of the provisional amount | Receive the retained amount in the protection reserve |
| Missing or invalid observation | Can receive the full provisional amount after permissionless expiry | Receive no provisional protection for that trade |

The final effective fee is bounded between **18 bps and 68 bps** in the Fair-Flow deployment.

## Why Reactive Network matters

A Uniswap hook cannot wake itself five minutes after a swap. MARKOUT therefore needs an event-driven control plane to
connect execution, delayed evidence, and terminal settlement without depending on an operator-run keeper.

`MarkoutReactive` implements that control plane with five narrow subscriptions:

- `MarkoutRequested`
- `MarkoutSettled`
- `MarkoutExpired`
- `NormalizedReferencePricePublished`
- Reactive cron events

The ReactVM state machine tracks maturity and expiry, processes at most eight trades per cron callback, selects a valid
reference observation, retries incomplete work, acknowledges terminal states, and requests a permissionless expiry
when evidence never becomes valid. Seventeen dedicated lifecycle tests cover this behavior.

Reactive Network has **no custody and no pricing authority**. The Unichain receiver authenticates the callback, while
the hook independently validates time, confidence, market, direction, solvency, and terminal state before computing
the allocation.

Circle CCTP V2 is the redundant delivery rail. Both transports meet at an immutable `SettlementCoordinator`; the first
valid delivery settles the trade and later duplicates become successful no-ops. If neither path succeeds, expiry keeps
the provisional amount refundable.

### Integration status

- Full Reactive lifecycle engine: implemented and covered by 17 focused tests.
- Legacy Reactive pulse: deployed, funded, and subscribed to the canonical publisher event.
- Reactive-to-Unichain public callback: **not yet observed** and therefore not claimed as live evidence.
- August 24 liveness recheck: two fresh source events produced no observable Reactive destination callback; see the
  [machine-readable probe](deployments/reactive-recheck-2026-08-24.json).
- Circle resilience rail: four public end-to-end Pyth → Circle → Unichain settlements completed.

This distinction is intentional: the repository demonstrates the complete autonomous design without overstating the
current public relayer result.

## Research results

The committed `markout-phase-6-v1` study replays the same deterministic tape through fixed-fee, volatility-only, and
MARKOUT policies.

| Study input | Value |
| --- | ---: |
| Trades | 768 |
| Notional per policy | 1,999,280 USDC |
| Market regimes | 6 |
| Fair-Flow base-fee candidates | 21 values from 10–30 bps |

The declared selection rule chooses the lowest base fee that keeps benign and inventory-improving fees at or below
30 bps while preserving at least 20% modeled LP-net improvement versus fixed. The first eligible candidate is **18
bps**.

| Result on the frozen synthetic tape | MARKOUT result |
| --- | ---: |
| Benign-flow average fee | 27.4262 bps — **8.58% below** fixed 30 bps |
| Inventory-improving fee | 18.0000 bps — **40% below** fixed 30 bps |
| Informed-flow average fee | 61.0552 bps |
| LP net-after-proxy versus fixed | **+21.8734%** |
| Modeled trader rebates | 6,746.608714 USDC |
| Modeled LP protection reserve | 3,249.791286 USDC |
| Invalid references | 63 full-surcharge expiries |

MARKOUT trails the declared volatility-only policy in aggregate LP net-after-proxy because that policy charges benign
and inventory-improving flow more. That trade-off is reported rather than hidden. The experiment is a controlled
synthetic mechanism comparison—not historical backtesting, a forecast, exact LVR, or position-level LP PnL.

See the [full reproducible report](experiments/results/report.md),
[parameter sweep](experiments/results/fair_flow_sweep.json), and
[evidence boundaries](docs/EVIDENCE.md).

## Public testnet evidence

Four real Uniswap v4 swaps have completed the delayed Pyth + Circle lifecycle across the original and Fair-Flow pools.

| Lifecycle | Swap | Settlement | Terminal result |
| --- | --- | --- | --- |
| Rebate branch | [Unichain transaction](https://sepolia.uniscan.xyz/tx/0x41127cb3dc8c86b115cc0547c646bee192907f9d75fdc4af6f052c5110b7b90c) | [38-second relay](https://sepolia.uniscan.xyz/tx/0xa64789b5a08ea8aae8c2b909b6a81b495334b707eaae12610bf3749902ec532f) | 100% provisional amount rebated and claimed |
| Protection branch | [Unichain transaction](https://sepolia.uniscan.xyz/tx/0xb6179eab5dcf9ff2f3563442dbf826fe5fcb86524e9d71aa913c9ba9e90a2376) | [67-second relay](https://sepolia.uniscan.xyz/tx/0xefeece5de9f78ae809652418e1fcd8fb592de950af64e6bbbf66df93bdc25eae) | 100% provisional amount retained for LP protection |
| Browser-wallet rebate | [Unichain transaction](https://sepolia.uniscan.xyz/tx/0x889ea958d19574572890a5ae5a5890c7a8d31f94ebfbe9d065b58d884c1f739a) | [67-second relay](https://sepolia.uniscan.xyz/tx/0x81f7878312b81b80ba69ad8fdc0f4e06f64f8624ed610ebd5a6ea63cca0ca610) | −266.96 bps markout and full rebate claimed |
| Fair-Flow 18 bps | [Unichain transaction](https://sepolia.uniscan.xyz/tx/0xf4873749b39300d5d19d28e3b0b0f43511ac907595b85d14e76c725f86f9c70f) | [55-second relay](https://sepolia.uniscan.xyz/tx/0xb1bd16c88d71fbb737cbaa20ed9002dd7bd7098d1c17ac11ab3c7f9ed01c0c4d) | Full rebate, 18 bps final fee, sponsored claim executed |

The browser-wallet lifecycle was initiated through the public console rather than an owner-side deployment script.
Machine-readable transaction hashes and accounting checks are stored in
[`deployments/hybrid-2026-08-21.json`](deployments/hybrid-2026-08-21.json) and
[`deployments/fair-flow-2026-08-22.json`](deployments/fair-flow-2026-08-22.json).

## Deployed Fair-Flow contracts

| Network | Contract | Address |
| --- | --- | --- |
| Unichain Sepolia | MARKOUT hook | [`0x3A17354331C21B246A9eC9BF979Af77e64f30044`](https://sepolia.uniscan.xyz/address/0x3A17354331C21B246A9eC9BF979Af77e64f30044) |
| Unichain Sepolia | Settlement coordinator | [`0x7BC38f019D5F3000c15C9E5309dFB1e7f361cb6e`](https://sepolia.uniscan.xyz/address/0x7BC38f019D5F3000c15C9E5309dFB1e7f361cb6e) |
| Unichain Sepolia | Circle receiver | [`0x24858E73A18f1A4537897DD2d04417a7a24b8f68`](https://sepolia.uniscan.xyz/address/0x24858E73A18f1A4537897DD2d04417a7a24b8f68) |
| Unichain Sepolia | Reactive receiver | [`0x35e006fc141E1798e15E4BCec4e58DE439eC9cED`](https://sepolia.uniscan.xyz/address/0x35e006fc141E1798e15E4BCec4e58DE439eC9cED) |
| Ethereum Sepolia | Pyth/Circle publisher | [`0xeeb18d96AABcec142D95Ba2b9E7E3221832Cf139`](https://sepolia.etherscan.io/address/0xeeb18d96AABcec142D95Ba2b9E7E3221832Cf139) |
| Reactive Lasna | Legacy observation pulse | `0xdd81EF6558E4D4F8403B3416c25ecD1CcB303e4e` |

Fair-Flow pool ID:
`0xee2fba8ece79cbbf20bb44f861fae605b7caf5fa12883daa34811f54e753580d`

## Security model

MARKOUT is production-shaped but not production-certified. The implementation includes:

- explicit maturity, freshness, confidence, and market-binding checks;
- replay-protected and idempotent terminal settlement;
- immutable delivery-source binding;
- pull-based rebates and beneficiary-only sponsored claims;
- conservation checks across pending escrow, rebates, and LP reserves;
- bounded Reactive work per callback;
- permissionless, full-refund expiry;
- adversarial tests and stateful invariants;
- zero medium- or high-severity findings in the committed Slither gate.

The repository currently contains **188 deterministic Solidity tests**, including **12 stateful invariants**. Phase 7
is an internal engineering review, not an independent audit. See the [threat model](docs/THREAT_MODEL.md),
[static-analysis report](docs/STATIC_ANALYSIS.md), and [verification protocol](docs/VERIFICATION.md).

## Repository structure

```text
MARKOUT/
├── src/
│   ├── base/          PoolManager custody and provisional accounting
│   ├── hooks/         Uniswap v4 hook and settlement lifecycle
│   ├── libraries/     Markout, pricing, validation, and accounting primitives
│   ├── reactive/      Autonomous lifecycle engine and callback receiver
│   ├── circle/        Pyth publisher and authenticated CCTP receiver
│   ├── settlement/    Immutable multi-transport coordinator
│   ├── reference/     Reference-price sampling
│   ├── interfaces/    Stable external interfaces, errors, and events
│   └── types/         Shared domain types
├── test/              Unit, integration, adversarial, demo, and invariant tests
├── script/            Foundry deployment and interaction scripts
├── scripts/           Reproducible verification and testnet tooling
├── experiments/       Seeded policy comparison and committed results
├── web/               Judge dashboard and wallet-safe testnet console
├── deployments/       Machine-readable deployment and lifecycle manifests
├── docs/              Specifications, evidence, runbooks, and presentation material
└── presentation/      UHI10 slide deck
```

## Local development

### Prerequisites

- Git with recursive submodule support
- Foundry `v1.7.1`
- Python `3.12`
- uv `0.12.5`
- Node.js `24–26` for the judge application

### Install and test the contracts

```bash
git clone --recurse-submodules https://github.com/RudraBhaskar9439/markout-hook.git
cd markout-hook
forge build
forge test
```

### Reproduce the research experiment

```bash
./scripts/verify-phase-6.sh
```

This regenerates the seeded artifacts in an isolated temporary directory and byte-compares them against the committed
results.

### Run the judge application

```bash
cd web
npm ci
npm run dev
```

Open `http://localhost:3000`. The guided product story requires no wallet. The live console at
`http://localhost:3000/#testnet` requires an injected wallet such as MetaMask and testnet-only funds.

### Run the release gate

```bash
./scripts/verify-hybrid-release-candidate.sh
./scripts/verify-live-testnet-console.sh
```

The gates cover formatting, compilation, bytecode size, lint, deterministic tests, stateful invariants, security
analysis, research reproducibility, hybrid delivery races, frontend production builds, and read-only testnet checks.
They do not broadcast transactions or require a private key.

## Documentation

| Topic | Document |
| --- | --- |
| Mechanism and accounting | [Mechanism](docs/MECHANISM.md) · [Accounting](docs/ACCOUNTING.md) · [Economics](docs/ECONOMICS.md) |
| Lifecycle and Reactive orchestration | [Lifecycle](docs/LIFECYCLE.md) · [Reactive lifecycle](docs/REACTIVE_LIFECYCLE.md) |
| Cross-chain settlement | [Hybrid architecture](docs/HYBRID_SETTLEMENT.md) · [Deployment runbook](docs/HYBRID_TESTNET_DEPLOYMENT.md) |
| Research and evidence | [Experiment](experiments/README.md) · [Evidence ledger](docs/EVIDENCE.md) · [Fair-Flow profile](docs/FAIR_FLOW.md) |
| Security | [Threat model](docs/THREAT_MODEL.md) · [Static analysis](docs/STATIC_ANALYSIS.md) |
| Demo and submission | [Demo script](docs/DEMO_SCRIPT.md) · [Presentation playbook](docs/PRESENTATION_PLAYBOOK.md) · [Final submission draft](docs/FINAL_SUBMISSION.md) |
| Architecture assets | [Editable Draw.io](docs/diagrams/MARKOUT_VIDEO_ARCHITECTURE.drawio) · [4K PNG](docs/diagrams/MARKOUT_VIDEO_ARCHITECTURE_4K.png) · [PDF](docs/diagrams/MARKOUT_VIDEO_ARCHITECTURE.pdf) · [Video narration](docs/VIDEO_ARCHITECTURE_NARRATION.md) |

## Limitations

- Testnet-only prototype; contracts have not received an independent audit.
- ETH/USD is used as a documented testnet proxy for ETH/USDC.
- Circle uses fast-confirmed finality to fit the bounded settlement window.
- The Reactive engine is implemented and tested, but a public Reactive-to-Unichain callback is not yet claimed.
- The study excludes concentrated-liquidity depth, LP shares, routing, demand elasticity, gas economics, and
  rebalancing.
- LP protection reserve distribution is intentionally outside the current prototype.

## Disclaimer

MARKOUT is research software built for UHI10. It is provided for testing and educational use only. Do not deploy it
with real assets.
