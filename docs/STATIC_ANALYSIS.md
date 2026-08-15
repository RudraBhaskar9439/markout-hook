# Phase 7 Static-Analysis Report

Status: reviewed with Slither `0.11.6`. This is an internal automated review, not an independent audit.

## Reproduction

```bash
./scripts/run-slither.sh
```

The script uses Python `3.12`, uv `0.12.5`, `security/pyproject.toml`, and the hash-bearing `security/uv.lock`. Slither
analyzes application contracts under `src/`, excludes dependency-only and test/script paths, and fails on any medium or
high result.

## Result

Slither analyzed 51 compiled contracts with 102 detectors after two false-positive medium findings were removed by
explicitly initializing Solidity memory locals. One intentional unused v3 `slot0` tuple is locally suppressed and
explained at the call site. The final run reports:

| Severity | Count | Gate result |
| --- | ---: | --- |
| High | 0 | Pass |
| Medium | 0 | Pass |
| Low | 16 | Reviewed below |
| Informational | 1 | Reviewed below |

## Reviewed lower-severity findings

| Detector | Count | Triage and control |
| --- | ---: | --- |
| External calls in a loop | 4 | All loops are statically bounded to exactly three configured pools. Constructor calls only validate immutable pool pairs. Sampling failures revert the callback and the scheduler later retries or expires the trade with a full rebate. |
| Benign reentrancy | 1 | `PoolManager.take` must precede final return-delta accounting in the v4 callback. Only the immutable PoolManager can enter the hook callback; the supported asset set is curated, and transient deltas plus full-balance invariants are tested. |
| Event after external call | 3 | Adapter events intentionally describe the destination call's outcome and therefore follow it. The adapters own no rebate accounting, targets are one-time bound, callbacks require both proxy and Reactive identity, and destination terminal operations are replay-safe. |
| Block timestamp | 8 | Maturity, observation age, retry cooldown, and expiry are explicitly wall-clock policies. Timestamp variation can delay or advance eligibility within consensus bounds but cannot change the beneficiary, exceed escrow, bypass authentication, or prevent later full-rebate expiry. Exact boundaries are tested. |
| Low-level native call | 1 informational | Native rebates use checks-effects-interactions under `nonReentrant`. A failed transfer reverts the zeroing of credit, the beneficiary can retry to another recipient, and the reentrant-recipient test proves one payout only. |

## Gas review

The deterministic snapshot adds five Phase 7 adversarial tests. Explicit local initialization reduced the affected
Reactive/sampler test measurements by 4–28 gas; no application path regressed. `forge snapshot --check` is part of the
cumulative gate.

## Conclusion

No unresolved automated high- or medium-severity finding remains. The threat model's oracle, liveness, configuration,
asset-compatibility, reserve-distribution, and external-audit limitations remain outside what static analysis can prove.
