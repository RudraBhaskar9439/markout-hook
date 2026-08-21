# MARKOUT Build Roadmap

Final UHI10 submission deadline: **September 3, 2026 at 11:59 PM Pacific Time**.

The project uses gated phases. At the end of every phase, work stops for a verification handoff. A phase passes only when its automated checks, manual demonstration, and documentation checklist all pass. Passing phases receive an annotated Git tag such as `phase-1-pass` so the last known-good state is always recoverable.

## Phase overview

| Phase | Target | Outcome | Verification gate |
| --- | --- | --- | --- |
| 0 | Aug 13 | Private repository and agreed scope | Private remote and roadmap visible |
| 1 | Aug 14 | Uniswap v4 accounting proof | Surcharge escrow works for all swap modes |
| 2 | Aug 15 | Markout mathematics | Unit, fuzz, and invariant tests pass |
| 3 | Aug 16–18 | Local MARKOUT hook MVP | Two trades settle with different rebates |
| 4 | Aug 19–21 | Reactive lifecycle | Event → maturity → callback works locally |
| 5 | Aug 22–24 | Live testnet deployment | End-to-end Reactive settlement on testnet |
| 6 | Aug 25–27 | Research experiment | Reproducible baseline comparison produced |
| 7 | Aug 28–29 | Security and hardening | Invariants, static analysis, and failure tests pass |
| 8 | Aug 30–31 | Demo application | Complete judge flow runs without manual intervention |
| 9 | Sep 1–3 | Submission package | Final links, video, deck, and form are complete |
| 10 | Aug 21 | Resilience architecture pivot | Circle-primary and Reactive-optional boundaries are frozen |
| 11 | Aug 21–22 | Shared settlement coordinator | Multiple authenticated transports race safely without changing hook accounting |
| 12 | Aug 22–24 | Circle CCTP primary path | A Circle-attested observation settles a MARKOUT trade on Unichain |
| 13 | Aug 24–25 | Minimal Reactive pulse | A stateless Maestro-style RSC can settle through the same coordinator |
| 14 | Aug 25–Sep 3 | Hybrid testnet and final package | Public Circle evidence, optional Reactive evidence, and final judge materials |

## Current status and resilience pivot

Phases 1–4 and 6–9 passed their local gates. Phase 5 proved origin-event ingestion and callback scheduling on Reactive
Lasna, but two bounded public canaries also proved that destination callbacks were not delivered to either Unichain
Sepolia or Ethereum Sepolia during the acceptance windows. Phase 5 therefore remains **NO-GO** for claims of a live
Reactive settlement.

The forward plan does not discard that work or weaken MARKOUT's accounting. It removes Reactive Network from the
protocol's critical path:

- Circle CCTP V2 becomes the primary authenticated cross-chain observation transport.
- A small legacy-compatible Reactive Contract observes the same source event and may deliver the same observation as
  an optional accelerator.
- Both transports terminate at one immutable settlement coordinator and the first valid delivery wins.
- Duplicate delivery is a successful no-op, and permissionless expiry continues to return the complete provisional
  surcharge when no valid observation arrives.
- The existing Omni scheduler remains reproducible research and outage evidence, not the active deployment path.

This pivot is specified in [Hybrid Settlement Architecture](docs/HYBRID_SETTLEMENT.md).

## Phase 0 — Repository bootstrap

### Goal

Create a private, recoverable home for the project and freeze the initial MVP boundary.

### Deliverables

- Private GitHub repository under `RudraBhaskar9439`
- README, mechanism specification, decision log, and gated roadmap
- Secret-safe `.gitignore`
- Main branch pushed to GitHub

### Verification

```bash
gh repo view RudraBhaskar9439/markout-hook --json visibility --jq .visibility
git status --short --branch
git remote -v
```

Expected result:

- Visibility prints `PRIVATE`.
- The main branch is clean and tracks `origin/main`.
- The remote points to `RudraBhaskar9439/markout-hook`.

### Exit decision

Confirm the name, scope, schedule, and phase order before installing protocol dependencies.

## Phase 1 — Uniswap v4 accounting proof

### Goal

Prove the riskiest protocol assumption first: a v4 hook can collect a bounded provisional surcharge into escrow without breaking swap accounting.

### Deliverables

- Foundry project with pinned `v4-core`, `v4-periphery`, and test dependencies
- Minimal accounting-spike hook
- Accounting matrix covering:
  - exact input and exact output
  - zero-for-one and one-for-zero
  - surcharge asset and rounding behavior
- Balance-conservation and maximum-surcharge tests
- Continuous integration for build and test

### Automated gate

```bash
forge fmt --check
forge build
forge test --match-path 'test/accounting/**' -vv
```

Required results:

- All four swap quadrants pass.
- PoolManager deltas settle to zero after every swap.
- Escrow receives exactly the expected surcharge within documented rounding tolerance.
- A surcharge can never exceed the user's declared maximum.

### Manual gate

Run one local exact-input swap and one exact-output swap, then compare trader, PoolManager, and escrow balances before and after.

### Stop condition

If v4 return-delta accounting cannot safely implement the escrow, do not continue. Choose the documented fallback design before Phase 2.

## Phase 2 — Markout mathematics and economic specification

### Goal

Make the economic rule deterministic, bounded, and independently testable before embedding it in the hook.

### Deliverables

- `MarkoutMath` pure Solidity library
- Canonical price normalization and trade-direction convention
- Piecewise bounded surcharge/rebate curve
- Reference-price freshness and confidence rules
- Unit, fuzz, and property tests
- Small deterministic scenario dataset

### Automated gate

```bash
./scripts/verify-phase-2.sh
```

Required properties:

- Final retained surcharge is always between zero and the escrowed amount.
- Rebate plus retained amount always equals the escrowed amount.
- Increasing positive markout never decreases the retained amount.
- Direction symmetry holds for equivalent buys and sells.
- Stale, missing, zero, and overflow-prone prices fail safely.

### Manual gate

Review a table containing benign, toxic, and inventory-improving trades and confirm that each result matches the written mechanism.

## Phase 3 — Local MARKOUT hook MVP

### Goal

Complete the local trade lifecycle without Reactive Network: swap, escrow, pending record, authorized mock settlement, rebate claim, and LP reserve credit.

### Deliverables

- `MarkoutHook`
- Trade state machine: pending, settled, expired
- Unique trade IDs and replay protection
- Authorized settlement adapter
- Pull-based rebate claims
- LP protection reserve accounting
- Local deployment and demo scripts
- Tests for every swap direction and amount mode

### Automated gate

```bash
forge build
forge test -vv
forge snapshot --check
```

Required results:

- An unauthorized address cannot settle a trade.
- A trade cannot be settled twice.
- Refund liabilities are always fully collateralized.
- Failed rebate transfers cannot block other settlements.
- Exact-output and small-amount rounding cases behave as specified.

### Manual gate

Execute two otherwise identical swaps. Settle one with a neutral future price and the other with a toxic markout. The first trader must receive a larger rebate and the accounting totals must reconcile exactly.

## Phase 4 — Reactive Network lifecycle

### Goal

Replace the mock settler with an event-driven Reactive Contract and prove the full lifecycle locally.

### Deliverables

- `MarkoutReactive` contract using current Reactive libraries
- Subscription to `MarkoutRequested`
- Subscription to the selected reference-market price event
- Cron-driven maturity processing
- Authenticated settlement callback
- Local tests using `reactive-test-lib`
- Handling for duplicate, stale, missing, and out-of-order observations

### Automated gate

```bash
forge test --match-path 'test/reactive/**' -vv
forge test --match-test 'testFuzz*' -vv
```

Required results:

- A request before maturity does not settle.
- A matured request with a fresh reference price settles once.
- Callback authentication is enforced.
- Duplicate events and callbacks are idempotent.
- Missing or stale prices follow the documented expiry path.

### Manual gate

Run the Reactive simulator and inspect a single trace showing:

`MarkoutRequested → reference update → cron maturity → Callback → rebate credit`.

## Phase 5 — Live Unichain and Reactive testnets

### Goal

Demonstrate a real cross-network event and callback lifecycle.

### Deliverables

- MARKOUT contracts deployed on Unichain Sepolia
- Reactive Contract deployed on the currently supported Reactive testnet
- Verified source code where explorer support exists
- Deployment manifest with chain IDs, addresses, block numbers, and transaction hashes
- Callback funding and monitoring runbook
- At least two successful live settlements

### Verification gate

- One transaction creates a pending benign trade.
- Reactive Network observes and settles it after maturity.
- The user claims a rebate on Unichain Sepolia.
- A second trade retains more for LP protection.
- Explorer links prove every stage.
- No developer EOA manually calls the settlement function.

Do not begin the frontend until this gate passes.

## Phase 6 — Reproducible research experiment

### Goal

Produce evidence for the project claim instead of relying on narrative.

### Baselines

1. Fixed fee
2. Volatility-linked dynamic fee
3. MARKOUT

### Scenarios

- Benign random flow
- Informed flow before reference-price moves
- Inventory-improving flow
- Mixed flow under low and high volatility
- Stale and manipulated reference-price attempts

### Metrics

- LP LVR or post-trade adverse-selection loss
- Effective trader fee by flow class
- Total rebate amount
- LP protection reserve growth
- Trading volume and rejected/expired settlements
- Gas and callback cost

### Verification gate

```bash
./experiments/run.sh
```

Required results:

- A clean checkout reproduces the same seeded result files.
- Raw data, assumptions, and chart-generation steps are committed.
- Results report both improvements and regressions.
- No claim is made beyond what the experiment supports.

## Phase 7 — Security and failure hardening

### Goal

Prove escrow solvency and safe behavior under adversarial conditions.

### Deliverables

- Stateful invariant suite
- Static-analysis configuration and report
- Gas snapshot
- Threat model
- Emergency and expiry behavior
- Review of callback authorization, replay, reentrancy, stale prices, rounding, griefing, denial of service, and reserve insolvency

### Verification gate

```bash
forge test -vv
forge test --match-path 'test/invariants/**' -vv
slither .
forge snapshot --check
```

Required results:

- Zero high-severity unresolved findings.
- Escrow assets always cover pending and claimable liabilities.
- No untrusted caller can create value, settle twice, or redirect another trader's rebate.
- Callback or oracle failure cannot permanently trap all users.

## Phase 8 — Judge-ready application and demo

### Goal

Turn the protocol evidence into one simple, reliable story.

### Deliverables

- Minimal dashboard showing trade, maturity, markout, rebate, and LP protection
- Guided benign-versus-toxic comparison
- Reactive event timeline with explorer links
- One-command demo reset
- Recorded fallback demo

### Verification gate

From a clean state, a first-time tester must be able to:

1. Submit two test swaps.
2. See both become pending.
3. See Reactive settle them without manual intervention.
4. Claim the larger benign-flow rebate.
5. Understand the result from the dashboard without reading the architecture.

The complete demo must remain comfortably inside the official presentation limit.

## Phase 9 — Submission and presentation

### Goal

Submit a reproducible project and a concise research story.

### Deliverables

- Final README and architecture diagram
- Public deployment manifest and test instructions
- Demo video and backup recording
- Short slide deck centered on problem, mechanism, evidence, and live demo
- Final Hookathon form using the correct MARKOUT Project ID
- Tagged release `uhi10-final`

### Final gate

- All prior phase scripts pass from a clean clone.
- All submitted links work in a logged-out browser.
- Repository visibility is changed only if required for final judging and only with explicit approval.
- The presentation is rehearsed under the official time limit.
- Final form is submitted before September 3, 2026 at 11:59 PM Pacific Time.

## Phase 10 — Hybrid settlement architecture pivot

### Goal

Freeze a smaller production path in which MARKOUT is safe and demonstrable without Reactive callback delivery.

### Deliverables

- Circle-primary, Reactive-optional architecture specification
- Explicit trust boundaries for Circle, Pyth, Reactive, relayers, and the hook
- First-valid-delivery and duplicate-delivery policy
- Migration plan that preserves all earlier phase evidence

### Verification gate

- No transport can bypass the hook's existing maturity, freshness, confidence, or solvency checks.
- Failure of Circle or Reactive cannot trap a provisional surcharge beyond the existing expiry window.
- The active architecture has exactly one settlement authority contract and no mutable production operator.

## Phase 11 — Shared settlement coordinator

### Goal

Put one immutable, replay-safe boundary between every observation transport and `MarkoutHook`.

### Deliverables

- One-time-bound `SettlementCoordinator`
- Immutable source authorization after topology freeze
- Idempotent first-valid-delivery behavior
- Unit, fuzz, and adversarial tests

### Verification gate

```bash
./scripts/verify-phase-11.sh
```

Required results:

- An unauthorized source cannot settle.
- An authorized source can settle exactly once.
- A second authorized delivery for a terminal trade is a successful no-op.
- Invalid observations still revert inside the unchanged hook validation engine.
- Permissionless expiry remains available without the coordinator.

## Phase 12 — Circle CCTP V2 primary transport

### Goal

Carry a Pyth-verified delayed observation from Ethereum Sepolia to Unichain Sepolia through Circle's generic message
path. Request threshold `1000` so delivery fits MARKOUT's ten-minute settlement window; retain a disjoint handler for
later hard-finalized messages at threshold `2000` or greater.

### Deliverables

- Source-side Pyth observation publisher
- Circle `MessageTransmitterV2` sender interface
- Destination `CircleObservationReceiver`
- Strict source domain, source sender, market, finality, and message-version validation
- Attestation relay and deployment scripts
- Local end-to-end tests with a Circle transmitter simulator

### Verification gate

```bash
./scripts/verify-phase-12.sh
```

Required results:

- Only the configured Circle transmitter can enter the receiver.
- Only confirmed or finalized messages from the configured Sepolia publisher and market are accepted.
- A valid Circle message settles one mature trade through the shared coordinator.
- Replays, malformed messages, wrong domains, wrong senders, and messages below threshold `1000` fail safely.

## Phase 13 — Optional Reactive pulse

### Goal

Add a minimal Maestro-style Reactive path without reintroducing Reactive-owned scheduling or protocol state.

### Deliverables

- Legacy-compatible RSC subscribed to the Circle publisher's observation event
- Authenticated Unichain destination receiver
- Stateless observation forwarding only
- Race tests proving Circle-first and Reactive-first delivery produce the same terminal result

### Verification gate

```bash
./scripts/verify-phase-13.sh
```

Required results:

- The RSC contains no trade registry, cron scheduler, sampler callback, or retry database.
- Its callback can only submit the same normalized observation emitted by the source publisher.
- Circle and Reactive delivery order cannot change accounting.
- Reactive failure has no effect on Circle settlement or permissionless expiry.

## Phase 14 — Hybrid live deployment and final submission

### Goal

Produce explorer-backed Circle evidence first, then add Reactive evidence only if the public callback network delivers.

### Verification gate

1. Execute a MARKOUT trade on Unichain Sepolia.
2. Publish its matured Pyth observation on Ethereum Sepolia.
3. Relay the Circle attestation and settle the trade on Unichain.
4. Claim the resulting rebate and link every transaction.
5. Attempt the optional Reactive pulse with a bounded acceptance window.
6. Label Reactive as live only if its destination callback transaction exists publicly.
7. Regenerate the demo and submission package around the verified hybrid path.

## Phase-gate handoff format

At every checkpoint, the handoff will contain:

1. What changed
2. The exact verification command
3. Expected and actual results
4. Manual demo steps
5. Known limitations
6. A clear **GO / NO-GO** decision for the next phase
