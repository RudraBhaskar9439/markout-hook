# UHI10 Final Submission Checklist

The Circle-primary, Reactive-optional implementation is complete locally, and the required Circle lifecycle is proven
on public testnets. The final release remains blocked only on the owner-controlled submission details below.

## Complete and verified locally

- [x] Uniswap v4 surcharge accounting across every swap quadrant
- [x] Deterministic markout mathematics and bounded settlement curve
- [x] Reproducible 768-trade comparison against fixed and volatility baselines
- [x] Threat model, adversarial tests, 12 invariants, and zero medium/high Slither findings
- [x] Immutable two-transport settlement coordinator with first-valid-delivery semantics
- [x] Pyth-verified Circle CCTP V2 publisher and authenticated Unichain receiver
- [x] Stateless legacy Reactive pulse and authenticated Unichain receiver
- [x] Chain-locked deployment, binding, publication, attestation-relay, and preflight tools
- [x] Judge dashboard updated to the honest hybrid architecture

## Required Circle public evidence

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

## Optional Reactive sponsor evidence

- [x] Deploy the funded pulse on legacy Lasna and verify its exact subscription publicly
- [ ] Observe the publisher event being processed on Reactive
- [ ] Record a successful Unichain callback transaction if the relayer delivers
- [ ] Set `reactiveLive` to `true` only when that destination transaction is public

Reactive evidence can strengthen the sponsor story, but its failure does not invalidate MARKOUT settlement. Circle is
the primary path, and permissionless expiry returns the complete provisional surcharge if neither transport settles.

## Submission details requiring the project owner

- [ ] Confirm the MARKOUT Project ID from the UHI idea-submission email
- [ ] Confirm UHI email, every team member's X handle, original cohort, and final team list
- [ ] Confirm the official presentation time limit through UHI email or Discord; it is not stated on the public form
- [ ] Explicitly authorize making the private GitHub repository public; the final form requires a public repository
- [ ] Decide whether the hosted dashboard may become public or needs a judge allowlist
- [ ] Record and upload the required final hybrid demo
- [x] Update the deck and dashboard with verified links only
- [x] Prepare a copy-ready final submission draft with public evidence and honest limitations
- [x] Prepare the required 1200 × 630 project thumbnail at `web/public/og-evidence-v2.png`
- [x] Verify the required explorer URLs return successfully without authentication
- [ ] Verify the repository, dashboard, deck, and video links from a logged-out browser after access is configured
- [ ] Submit the final form before September 3, 2026 at 11:59 PM Pacific Time

Repository or site access must never be broadened automatically. Visibility changes require explicit owner approval.

## Final release gate

Run the local release candidate gate first:

```bash
./scripts/verify-hybrid-release-candidate.sh
```

Create the `uhi10-final` tag only after the dated manifest contains the required Circle evidence, all submitted links
work in a logged-out browser, and the project owner confirms the final form and visibility decisions.
