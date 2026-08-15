# UHI10 Final Submission Checklist

The repository is ready for draft review. The final release remains intentionally blocked until every public-evidence
item below is real and reproducible.

## Complete and verified

- [x] Private production-shaped repository with direct phase commits on `main`
- [x] Uniswap v4 surcharge accounting across every swap quadrant
- [x] Deterministic markout mathematics and bounded settlement curve
- [x] Complete local hook and Reactive lifecycle
- [x] Reproducible 768-trade comparison against fixed and volatility baselines
- [x] Threat model, adversarial tests, 12 invariants, and zero medium/high Slither findings
- [x] Judge dashboard with a one-command local fallback
- [x] Private hosted dashboard checkpoint
- [x] Final architecture diagram and judge-demo script
- [x] Draft presentation deck with rendered visual QA

## Public evidence still required

- [ ] Fund the Lasna scheduler and callback destinations with lREACT
- [ ] Produce one autonomous benign-flow settlement and claim
- [ ] Produce one autonomous informed-flow settlement with greater LP protection
- [ ] Record request, sample, callback, settlement, claim, and reserve explorer links
- [ ] Add only those verified links to the dashboard and deployment manifest
- [ ] Re-run the complete live Phase 5 gate
- [ ] Record the final live-integrated fallback demo

## Submission details requiring the project owner

- [ ] Confirm the MARKOUT Project ID from the UHI idea-submission email
- [ ] Confirm the preferred name, UHI email, and Discord handle for the final form
- [ ] Confirm the official presentation time limit and rehearse below it
- [ ] Decide whether the GitHub repository must become public for judging
- [ ] Decide whether the hosted dashboard may become public or needs a judge allowlist
- [ ] Review and submit the final Hookathon form before September 3, 2026 at 11:59 PM Pacific Time

Repository or site access must never be broadened automatically. Changing either from private requires explicit owner
approval after the final evidence has been reviewed.

## Final release gate

After every item above is complete:

```bash
./scripts/verify-phase-9.sh
```

The final script and `uhi10-final` tag must be created only after the live links, video, form details, and visibility
decision exist. Until then, use `phase-9-draft-pass` for the token-independent package.
