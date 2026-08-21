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
7. Confirm that the live-evidence card contrasts the measured public outcomes: a 38-second Circle settlement with a
   100% good-flow rebate and a 67-second Circle settlement with 100% retained for LP protection.

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

Passing this script means the judge application is reproducible and presentation-ready. The public Circle evidence is
recorded in `deployments/hybrid-2026-08-21.json`; Reactive remains explicitly optional and receives no live-delivery
claim until a destination callback is public.

## GO / NO-GO

**GO** for hosted/local judge review and for claiming the three linked public Circle settlements. **NO-GO** for claiming
a public Reactive callback until the corresponding Unichain transaction is observed and recorded.
