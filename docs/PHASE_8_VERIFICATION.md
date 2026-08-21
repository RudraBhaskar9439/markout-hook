# Phase 8 Verification Guide

Phase 8 packages MARKOUT's implemented mechanism and reproducible evidence into one judge-facing application. The
token-independent checkpoint requires no wallet, faucet balance, RPC endpoint, public transaction, or secret. It does
not claim that Phase 5's live Reactive testnet gate has passed.

## One-command demo

Prerequisites are Node.js `24.x` and npm.

```bash
./scripts/run-phase-8-demo.sh
```

Open `http://localhost:3000`. The command installs the exact locked frontend graph and starts the Cloudflare-compatible
development server. Stop it with `Ctrl+C`.

## Judge path

Complete this path without a wallet or terminal interaction after the application starts:

1. Read the fixed-fee, volatility-fee, and MARKOUT comparison.
2. Select benign flow and confirm a larger trader rebate with lower LP protection.
3. Select informed flow and confirm a smaller rebate with higher LP protection.
4. Select inventory-improving flow and confirm MARKOUT does not retain adverse-selection protection.
5. Replay the five-step hybrid timeline from execution through acknowledgement.
6. Review the aggregate evidence and the explicitly disclosed stale/manipulated-reference regression.
7. Confirm that the live-evidence card says `Public Circle settlement pending` and contains no invented
   settlement hash.

## Automated gate

```bash
./scripts/verify-phase-8.sh
```

This cumulative gate repeats every Phase 1–7 deployment-independent check and then:

- installs the exact `web/package-lock.json` dependency graph;
- lints the TypeScript application;
- builds the Cloudflare Worker-compatible artifact;
- server-renders and tests the complete judge story;
- checks that the social preview is a real `1200 × 630` PNG;
- verifies that no high-severity deployed dependency advisory exists; and
- rejects whitespace errors.

The application tests require the exact headline, comparison, timeline, regression, accessibility labels, live-proof
disclosure, and removal of starter content. CI pins Node.js `24`, Foundry `1.7.1`, Python `3.12`, and uv `0.12.5`.

## Dependency boundary

`npm audit --omit=dev --audit-level=high` reports zero deployed dependency vulnerabilities. The raw development audit
currently inherits two high-severity parser advisories through `vinext@0.0.50 → image-size@2.0.2`. No fixed
`image-size` release exists at this checkpoint. MARKOUT never accepts image uploads or processes untrusted images; the
parser only sees repository-owned build assets. Replacing or force-downgrading vinext would break the required Sites
runtime, so CI gates the production graph and this development-only residual risk remains explicit.

## Exact checkpoint boundary

Passing this script means the local judge application is reproducible and presentation-ready. It does **not** mean the
complete roadmap gate has passed. These items remain blocked on successful public Circle destination delivery:

- at least one real Circle-attested settlement;
- explorer-backed event, observation, attestation relay, claim, and LP-protection links;
- replacement of the pending-evidence card with those verified links; and
- a fallback recording of the final live-integrated application.

Use the checkpoint tag `phase-8-local-pass`, not `phase-8-pass`, until all four items exist.

## GO / NO-GO

**GO** for hosted/local judge review, Phase 9 writing, diagram, deck, and rehearsal work that uses the honest local
boundary. **NO-GO** for claiming a public Circle or Reactive settlement, or publishing the final submission package,
until the corresponding public evidence is added and reverified.
