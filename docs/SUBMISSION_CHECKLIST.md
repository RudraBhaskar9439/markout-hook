# UHI10 Final Submission Checklist

The Circle-primary, Reactive-optional implementation is complete locally. The final release remains blocked until the
public transactions below exist and every submitted claim links to real evidence.

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

- [ ] Deploy and verify the Ethereum Sepolia publisher
- [ ] Deploy and freeze the Unichain coordinator, receivers, permission-mined hook, and pool
- [ ] Permanently bind the publisher only after confirming the destination receiver
- [ ] Execute a real testnet swap and record its trade id
- [ ] After maturity, publish a signed Pyth observation
- [ ] Fetch and relay Circle's completed attestation on Unichain
- [ ] Confirm the trade settled and claim the rebate
- [ ] Record publication, Circle relay, settlement, and claim explorer links in a dated manifest
- [ ] Measure end-to-end attestation latency against the ten-minute settlement window

## Optional Reactive sponsor evidence

- [ ] Deploy the funded pulse on legacy Lasna and verify its exact subscription publicly
- [ ] Observe the publisher event being processed on Reactive
- [ ] Record a successful Unichain callback transaction if the relayer delivers
- [ ] Set `reactiveLive` to `true` only when that destination transaction is public

Reactive evidence can strengthen the sponsor story, but its failure does not invalidate MARKOUT settlement. Circle is
the primary path, and permissionless expiry returns the complete provisional surcharge if neither transport settles.

## Submission details requiring the project owner

- [ ] Confirm the MARKOUT Project ID from the UHI idea-submission email
- [ ] Confirm preferred name, UHI email, Discord handle, and final team list
- [ ] Confirm the official presentation time limit
- [ ] Decide whether the private GitHub repository must become public for judging
- [ ] Decide whether the hosted dashboard may become public or needs a judge allowlist
- [ ] Record and upload the final hybrid demo after public evidence exists
- [ ] Update the deck and dashboard with verified links only
- [ ] Submit the final form before September 3, 2026 at 11:59 PM Pacific Time

Repository or site access must never be broadened automatically. Visibility changes require explicit owner approval.

## Final release gate

Run the local release candidate gate first:

```bash
./scripts/verify-hybrid-release-candidate.sh
```

Create the `uhi10-final` tag only after the dated manifest contains the required Circle evidence, all submitted links
work in a logged-out browser, and the project owner confirms the final form and visibility decisions.
