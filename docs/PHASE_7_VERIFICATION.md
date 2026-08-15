# Phase 7 Verification Guide

Phase 7 hardens MARKOUT against adversarial settlement, claim, expiry, callback, observation, donation, reentrancy, and
insolvency scenarios. It requires no wallet, RPC, faucet token, or public transaction.

## Focused gates

```bash
forge test --match-path 'test/security/**' -vv
forge test --match-path 'test/invariants/**' -vv
./scripts/run-slither.sh
forge snapshot --check --no-match-test '^(testFuzz|invariant_|test_demo_)'
```

Expected results:

- five adversarial security tests pass;
- 12 invariant properties pass with zero handler reverts under the default profile;
- the lifecycle invariant drives unauthorized settlement, unauthorized claim, and premature expiry probes without one
  accounting mutation;
- Slither reports zero medium and zero high findings;
- the committed gas snapshot matches exactly.

## Cumulative gate

```bash
./scripts/verify-phase-7.sh
```

This repeats every Phase 1–6 deployment-independent check, verifies the locked security environment, runs Slither, and
checks whitespace. The default Foundry profile uses 1,000 fuzz cases and `256 × 64` invariant calls. CI uses 10,000
fuzz cases and `1,000 × 128` invariant calls.

The first static-analysis run may download Python `3.12` and only packages whose versions and SHA-256 artifact hashes
are committed in `security/uv.lock`. Subsequent runs use uv's cache.

## Manual review

```bash
sed -n '1,260p' docs/THREAT_MODEL.md
sed -n '1,220p' docs/STATIC_ANALYSIS.md
git diff -- .gas-snapshot
```

Confirm that:

- no administrator can pause claims, seize escrow, rewrite a beneficiary, or force a settlement;
- invalid infrastructure fails open per trade after the grace period;
- all 17 lower-severity Slither results are categorized and bounded;
- same-chain spot-oracle manipulation, exotic tokens, immutable misconfiguration, reserve distribution, and external
  audit remain explicit limitations;
- the report does not describe Phase 7 as an independent audit or production certification.

## GO / NO-GO

Phase 7 passes only when the cumulative command succeeds, Slither has no medium/high result, the gas snapshot is
reviewed, and every residual risk above remains documented. Passing Phase 7 permits local judge-application work. It
does not close Phase 5's live testnet gate and does not authorize real-fund deployment.
