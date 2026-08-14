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

## Phase-gate handoff format

At every checkpoint, the handoff will contain:

1. What changed
2. The exact verification command
3. Expected and actual results
4. Manual demo steps
5. Known limitations
6. A clear **GO / NO-GO** decision for the next phase
