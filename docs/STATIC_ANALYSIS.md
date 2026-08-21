# Release Static-Analysis Report

Status: reviewed with Slither `0.11.6`. This is an internal automated review, not an independent audit.

## Reproduction

```bash
./scripts/run-slither.sh
```

The script uses Python `3.12`, uv `0.12.5`, `security/pyproject.toml`, and the hash-bearing `security/uv.lock`. Slither
analyzes application contracts under `src/`, excludes dependency-only and test/script paths, and fails on any medium or
high result.

## Result

Slither analyzed 67 compiled contracts with 102 detectors. The Circle publisher converts Pyth's raw confidence interval
to normalized confidence basis points and rejects any observation below the protocol-wide 9,000-bps minimum before
sending a message. Slither does not trace that library conversion, so its `pyth-unchecked-confidence` warning is locally
suppressed with the validation documented at the call site and exercised in the publisher test. One intentional unused
v3 `slot0` tuple is likewise locally suppressed and explained. The final run reports:

| Severity | Count | Gate result |
| --- | ---: | --- |
| High | 0 | Pass |
| Medium | 0 | Pass |
| Low | 21 | Reviewed below |
| Informational | 2 | Reviewed below |

## Reviewed lower-severity findings

| Detector | Count | Triage and control |
| --- | ---: | --- |
| External calls in a loop | 4 | All loops are statically bounded to exactly three configured pools. Constructor calls only validate immutable pool pairs. Sampling failures revert the callback and the scheduler later retries or expires the trade with a full rebate. |
| Benign reentrancy | 1 | `PoolManager.take` must precede final return-delta accounting in the v4 callback. Only the immutable PoolManager can enter the hook callback; the supported asset set is curated, and transient deltas plus full-balance invariants are tested. |
| Event after external call | 7 | Settlement and adapter events intentionally describe successful downstream calls and therefore follow them. Circle publication is stateless and forwards only the exact Pyth fee to immutable dependencies. Receivers are immutable-authenticated, the coordinator accepts only bound transports, and terminal hook operations are replay-safe. A downstream revert unwinds the event and entire transaction. |
| Block timestamp | 9 | Maturity, observation age, retry cooldown, and expiry are explicitly wall-clock policies. Timestamp variation can delay or advance eligibility within consensus bounds but cannot change the beneficiary, exceed escrow, bypass authentication, or prevent later full-rebate expiry. Exact boundaries are tested. |
| Cyclomatic complexity | 1 informational | The coordinator's one-time topology binding validates the target and both authorized routes, rejects duplicates, and then freezes all three values. Keeping those deployment invariants together makes the irreversible transition explicit; every branch is unit tested. |
| Low-level native call | 1 informational | Native rebates use checks-effects-interactions under `nonReentrant`. A failed transfer reverts the zeroing of credit, the beneficiary can retry to another recipient, and the reentrant-recipient test proves one payout only. |

## Gas review

The deterministic snapshot covers the full release suite, including Circle, coordinator, and optional Reactive pulse
paths. `forge snapshot --check` is part of the cumulative gate.

## Conclusion

No unresolved automated high- or medium-severity finding remains. The threat model's oracle, liveness, configuration,
asset-compatibility, reserve-distribution, and external-audit limitations remain outside what static analysis can prove.
