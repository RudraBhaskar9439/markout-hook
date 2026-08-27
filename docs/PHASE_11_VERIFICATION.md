# Phase 11 Verification - Shared Settlement Coordinator

## Automated gate

```bash
./scripts/verify-phase-11.sh
```

The gate checks formatting and compilation, runs the coordinator unit and fuzz suite, and reruns the real hook's
permissionless expiry test.

## Expected behavior

- The binder can set the hook and one-to-three contract sources exactly once.
- The target must already identify the coordinator as its immutable settlement authority.
- EOAs, zero addresses, duplicate sources, oversized source sets, and rebinding all fail.
- The first authorized observation for a pending trade reaches the hook.
- Circle-first and Reactive-first delivery are economically equivalent: a later delivery sees terminal state and is a
  successful no-op.
- A target validation revert does not consume the trade or stop a different source from later submitting valid data.
- The hook's existing permissionless expiry path remains independent of the coordinator.

## Manual review

Inspect `SettlementCoordinator` and confirm that it has no withdrawal, arbitrary-call, source-update, target-update,
pause, upgrade, or post-binding owner function.

## Gate decision

Phase 11 passes only when every command exits zero and the topology is immutable after `bindTopology`.
