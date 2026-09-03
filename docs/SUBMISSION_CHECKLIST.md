# UHI10 Final Submission Checklist

The Reactive-first implementation is complete locally. The primary public sponsor proof is a funded Legacy Reactive
pulse with an exact subscription, ReactVM execution, and an authenticated Unichain callback. A separate pending-first
run proves safe expiry when the destination relayer does not arrive. Four pre-pivot economic lifecycles remain
historical accounting evidence; Reactive-first economic settlement is explicitly unclaimed. The public repository,
hosted dashboard, and logged-out proof links are verified.

## Complete and verified locally

- [x] Uniswap v4 surcharge accounting across every swap quadrant
- [x] Deterministic markout mathematics and bounded settlement curve
- [x] Reproducible 768-trade comparison against fixed and volatility baselines
- [x] Reproducible 21-point fee sweep selecting the trader-friendly 18 bps Fair-Flow base
- [x] Gas-sponsored rebate claim path that cannot redirect beneficiary funds
- [x] Threat model, adversarial tests, 12 invariants, and zero medium/high Slither findings
- [x] Immutable settlement coordinator with first-valid-delivery and replay-safe terminal semantics
- [x] Stateless legacy Reactive pulse and authenticated Unichain receiver
- [x] Exact publisher, event signature, and market-topic subscription on Reactive Network
- [x] ReactVM payload validation and authenticated Unichain callback encoding
- [x] Permissionless full-refund expiry if the Reactive callback misses the grace window
- [x] Judge dashboard updated to the Reactive-first architecture and exact evidence boundaries
- [x] Deploy a separate 18 + 50 bps Fair-Flow pool and complete one public economic lifecycle
- [x] Execute the Fair-Flow sponsored-claim entrypoint and reconcile its final liabilities to zero
- [x] Dashboard clearly separates original 30 + 50 bps evidence from the Fair-Flow deployment

## Primary Reactive Network evidence

- [x] Deploy and fund the pulse on Legacy Reactive Lasna
- [x] Verify its exact publisher, event-signature, and market-topic subscription publicly
- [x] Observe the canonical publisher event being processed in ReactVM
- [x] Record a successful authenticated Unichain callback transaction
- [x] Record 11-second source-event to destination-callback latency
- [x] Confirm the already-terminal destination handled the callback as a safe no-op
- [x] Run a separate pending-first acceptance trade
- [x] Record the relayer timeout, permissionless full-refund expiry, and final zero-liability accounting

The successful callback proves Reactive transport liveness and replay safety. The separate pending-first run proves
that a relayer outage cannot trap the provisional amount. The evidence does not relabel either run as a completed
Reactive-first economic allocation.

## Historical economic lifecycle evidence

- [x] Deploy and verify the Ethereum Sepolia publisher
- [x] Deploy and freeze the Unichain coordinator, receivers, permission-mined hook, and pool
- [x] Permanently bind the publisher only after confirming the destination receiver
- [x] Execute a real testnet swap and record its trade id
- [x] After maturity, publish a signed Pyth observation
- [x] Fetch and relay Circle's completed attestation on Unichain
- [x] Confirm the trade settled and claim the rebate
- [x] Record publication, Circle relay, settlement, claim, and explorer links in a dated manifest
- [x] Measure end-to-end attestation latency against the ten-minute settlement window (38 seconds)
- [x] Execute and settle a second trade proving the opposite branch: 100% retained for LP protection in 67 seconds
- [x] Reconcile claimable rebate, LP reserve, accounted balance, and actual token balance across all public lifecycles

These transactions prove both economic terminal branches through the pre-pivot recovery adapter. They remain
reproducible historical evidence and are not presented as the normal Reactive-first lifecycle.

## Submission details requiring the project owner

- [ ] Confirm the MARKOUT Project ID from the UHI idea-submission email
- [x] Record preferred name `Rudra Bhaskar` and current cohort `UHI10` (with prior UHI9 participation noted)
- [ ] Confirm UHI email, every team member's X handle, and final team list
- [ ] Confirm the official presentation time limit through UHI email or Discord; it is not stated on the public form
- [x] Make the GitHub repository public and verify anonymous read access
- [x] Make the hosted dashboard public without a judge allowlist
- [ ] Record and upload the required final Reactive-first demo
- [x] Update the deck and dashboard with verified links only
- [x] Prepare a copy-ready final submission draft with public evidence and honest limitations
- [x] Prepare the required 1200 × 630 project thumbnail at `web/public/og-evidence-v2.png`
- [x] Verify the required explorer URLs return successfully without authentication
- [x] Verify the repository, dashboard, and explorer proof links without authentication
- [ ] Submit the final form before September 3, 2026 at 11:59 PM Pacific Time

Repository and site access are already public by owner instruction. Do not change visibility or submit the final form
without a new explicit owner instruction.

## Final release gate

Run the local release candidate gate first:

```bash
./scripts/verify-hybrid-release-candidate.sh
```

Create the `uhi10-final` tag only after the dated manifests contain the required public evidence, the final video link
works without authentication, and the project owner confirms the final form fields.
