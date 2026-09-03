# MARKOUT Build Roadmap

Final UHI10 submission deadline: **September 3, 2026 at 11:59 PM Pacific Time**.

The project uses gated phases. At the end of every phase, work stops for a verification handoff. A phase passes only when its automated checks, manual demonstration, and documentation checklist all pass. Passing phases receive an annotated Git tag such as `phase-1-pass` so the last known-good state is always recoverable.

> **Current submission architecture (September 3, 2026):** Reactive Network is MARKOUT's primary event-to-action
> rail. It observes the canonical Pyth-backed event, executes in ReactVM, and requests the authenticated Unichain
> callback. Legacy Reactive has a public 11-second callback; a separate pending-first run proves safe full-refund
> expiry after a relayer timeout. Earlier Circle phases and transactions remain below as historical build evidence,
> not as the final architecture narrative.

## Phase overview

| Phase | Target | Outcome | Verification gate |
| --- | --- | --- | --- |
| 0 | Aug 13 | Repository bootstrap and agreed scope | Recoverable remote and roadmap visible |
| 1 | Aug 14 | Uniswap v4 accounting proof | Surcharge escrow works for all swap modes |
| 2 | Aug 15 | Markout mathematics | Unit, fuzz, and invariant tests pass |
| 3 | Aug 16–18 | Local MARKOUT hook MVP | Two trades settle with different rebates |
| 4 | Aug 19–21 | Reactive lifecycle | Event → maturity → callback works locally |
| 5 | Aug 22–24 | Live testnet deployment | End-to-end Reactive settlement on testnet |
| 6 | Aug 25–27 | Research experiment | Reproducible baseline comparison produced |
| 7 | Aug 28–29 | Security and hardening | Invariants, static analysis, and failure tests pass |
| 8 | Aug 30–31 | Demo application | Complete judge flow runs without manual intervention |
| 9 | Sep 1–3 | Submission package | Final links, video, deck, and form are complete |
| 10 | Aug 21 | Resilience architecture pivot | Multiple authenticated delivery boundaries are frozen |
| 11 | Aug 21–22 | Shared settlement coordinator | Multiple authenticated transports race safely without changing hook accounting |
| 12 | Aug 22–24 | Historical CCTP recovery path | An independently attested observation proves MARKOUT's economic branches |
| 13 | Aug 24–25 | Primary Reactive event rail | A stateless Maestro-style RSC requests authenticated Unichain settlement |
| 14 | Aug 25–Sep 3 | Reactive-first testnet and final package | Public Reactive transport, fail-open recovery, and final judge materials |

## Current status and resilience pivot

Phases 1–4 and 6–15 passed their local gates. Early Phase 5 canaries proved origin-event ingestion and scheduling but
did not receive destination callbacks. A later Legacy Reactive deployment superseded that transport status by
completing an authenticated Ethereum Sepolia → ReactVM → Unichain callback in 11 seconds. Because the target trade was
already terminal, MARKOUT claims live transport and replay safety, not Reactive-first economics.

Phases 10–15 converged on a Reactive-first topology without weakening MARKOUT's accounting:

- A small legacy-compatible Reactive Contract observes the canonical publisher event and supplies the primary
  autonomous event-to-action path presented to judges.
- The Reactive receiver and immutable settlement coordinator form the normal callback path.
- The earlier Circle CCTP V2 adapter produced four public economic lifecycles and remains historical resilience
  evidence rather than the submission's primary architecture.
- Duplicate delivery is a successful no-op, and permissionless expiry continues to return the complete provisional
  surcharge when no valid observation arrives.
- The existing Omni scheduler remains reproducible research and outage evidence, not the active deployment path.

This pivot is specified in [Reactive-First Settlement Architecture](docs/HYBRID_SETTLEMENT.md).

Phase 14's required economic gate is complete. The dated
[public deployment manifest](deployments/hybrid-2026-08-21.json) records the Sepolia publication, Circle attestation,
two opposite Unichain settlement outcomes, the rebate claim, exact LP-reserve reconciliation, and 38/67-second
source-to-destination latencies. The
[Legacy Reactive manifest](deployments/reactive-legacy-2026-08-26.json) separately records the exact subscription,
ReactVM processing, 11-second authenticated destination callback, and the honest pending-first relayer timeout.

## Phase 0 - Repository bootstrap

### Goal

Create a recoverable home for the project and freeze the initial MVP boundary. The repository began privately and is
now public for final judging.

### Deliverables

- GitHub repository under `RudraBhaskar9439`, initially private and now public
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

- Visibility prints `PUBLIC` for the final submission state.
- The main branch is clean and tracks `origin/main`.
- The remote points to `RudraBhaskar9439/markout-hook`.

### Exit decision

Confirm the name, scope, schedule, and phase order before installing protocol dependencies.

## Phase 1 - Uniswap v4 accounting proof

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

## Phase 2 - Markout mathematics and economic specification

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

## Phase 3 - Local MARKOUT hook MVP

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

## Phase 4 - Reactive Network lifecycle

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

## Phase 5 - Live Unichain and Reactive testnets

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

## Phase 6 - Reproducible research experiment

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

## Phase 7 - Security and failure hardening

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

## Phase 8 - Judge-ready application and demo

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

## Phase 9 - Submission and presentation

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
- Repository and dashboard are publicly readable for final judging.
- The presentation is rehearsed under the official time limit.
- Final form is submitted before September 3, 2026 at 11:59 PM Pacific Time.

## Phase 10 - Settlement resilience pivot

### Goal

Freeze a smaller production path in which MARKOUT remains safe if either callback transport is delayed or unavailable.

### Deliverables

- Shared coordinator and authenticated multi-transport architecture specification
- Explicit trust boundaries for Circle, Pyth, Reactive, relayers, and the hook
- First-valid-delivery and duplicate-delivery policy
- Migration plan that preserves all earlier phase evidence

### Verification gate

- No transport can bypass the hook's existing maturity, freshness, confidence, or solvency checks.
- Failure of Circle or Reactive cannot trap a provisional surcharge beyond the existing expiry window.
- The active architecture has exactly one settlement authority contract and no mutable production operator.

## Phase 11 - Shared settlement coordinator

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

## Phase 12 - Historical Circle CCTP V2 recovery transport

### Goal

Historical phase goal: carry a Pyth-verified delayed observation from Ethereum Sepolia to Unichain Sepolia through
Circle's generic message path. This phase proved transport redundancy and both economic branches before the final
Reactive-first architecture was frozen.

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

## Phase 13 - Reactive event-to-action pulse

### Goal

Establish a minimal Maestro-style Reactive event-to-action path without giving Reactive custody or fee authority.

### Deliverables

- Legacy-compatible RSC subscribed to the canonical Pyth-backed publisher event
- Authenticated Unichain destination receiver
- Stateless observation forwarding only
- Replay tests proving duplicate authenticated delivery cannot change a terminal result

### Verification gate

```bash
./scripts/verify-phase-13.sh
```

Required results:

- The RSC contains no trade registry, cron scheduler, sampler callback, or retry database.
- Its callback can only submit the same normalized observation emitted by the source publisher.
- Reactive delivery and later duplicates cannot change accounting after terminal settlement.
- Reactive failure cannot disable permissionless expiry or trap the provisional amount.

## Phase 14 - Reactive-first live deployment and final submission

### Goal

Produce explorer-backed economic settlement evidence and independently verify the Reactive event-to-action rail.

### Local deliverables

- Chain-locked deployment scripts for the Sepolia publisher, Unichain destination, publisher binding, and
  legacy Reactive pulse
- Signed Pyth update, Circle attestation, and Circle relay helpers
- Read-only three-network dependency and immutable-wiring preflight
- Secret-safe environment template and evidence-manifest template
- Judge dashboard, demo script, submission checklist, and rendered deck revised around the Reactive-first boundary

Local automation and the Reactive adapter are complete. The Reactive manifest records an exact subscription, ReactVM
processing, an 11-second authenticated destination callback, and an honest pending-first relayer timeout followed by
full-refund expiry. The earlier dated CCTP manifest remains the mechanism proof for both economic extremes. Repository
and dashboard access are public. Owner identity, video, and final-form submission remain owner-controlled gates.

### Verification gate

1. Execute a MARKOUT trade on Unichain Sepolia.
2. Publish its matured Pyth observation on Ethereum Sepolia.
3. Observe the publisher event in ReactVM and request the authenticated Unichain callback.
4. Claim the resulting rebate and link every transaction.
5. Execute the Reactive pulse with a bounded acceptance window.
6. Label Reactive transport as live only when its destination callback transaction exists publicly; distinguish that
   from Reactive-first economic settlement.
7. Regenerate the demo and submission package around the verified Reactive-first path.

## Phase 15 - Fair-Flow trader economics

### Goal

Make MARKOUT preferable for good traders at equal execution quality without giving up the modeled LP advantage over a
fixed 30 bps pool.

### Deliverables

- Deterministic 10–30 bps base-fee sweep with declared selection constraints
- An 18 bps base + refundable 50 bps Fair-Flow release candidate
- Fee-only savings and routing thresholds by flow class
- Permissionless gas sponsorship that can only pay the recorded rebate beneficiary
- Dashboard, evidence ledger, threat model, and submission draft synchronized to the generated artifacts

The release candidate is now deployed as a separate Unichain Sepolia pool. Its dated manifest records an 18 bps pool
initialization, real swap, 55-second Circle settlement, complete provisional-surcharge rebate, sponsored-claim
entrypoint execution, and zero residual liabilities. The original 30 + 50 bps deployment remains unchanged.

### Verification gate

```bash
./experiments/run.sh
forge test -q
cd web && npm run verify
```

Required results:

- Eighteen bps is the lowest tested base producing at least 20% modeled LP-net improvement versus fixed while keeping
  benign and inventory-improving effective fees at or below 30 bps.
- At equal execution, benign flow pays 27.4262 bps and inventory-improving flow pays 18 bps.
- A sponsor cannot redirect a rebate, replay a claim, break solvency, or bypass reentrancy protection.
- The dashboard clearly separates the original 30 + 50 bps evidence from the separately deployed 18 + 50 bps pool.

## Phase-gate handoff format

At every checkpoint, the handoff will contain:

1. What changed
2. The exact verification command
3. Expected and actual results
4. Manual demo steps
5. Known limitations
6. A clear **GO / NO-GO** decision for the next phase
