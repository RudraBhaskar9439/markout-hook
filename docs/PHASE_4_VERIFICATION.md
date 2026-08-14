# Phase 4 Verification Guide

Phase 4 proves the autonomous local lifecycle: source event ingestion, maturity scheduling, authenticated callback,
destination settlement, retry, terminal acknowledgement, and full-rebate expiry.

## One-command cumulative gate

From the repository root:

```bash
./scripts/verify-phase-4.sh
```

The command starts with a clean build and runs every Phase 1–4 unit, accounting, mathematics, lifecycle, Reactive,
stateful-invariant, and demo suite. It also checks formatting, lint, bytecode sizes, and the committed gas snapshot.

Expected result: all suites pass, invariant output reports zero reverts, and the gas snapshot has no unexpected diff.

## Focused commands

```bash
# All Reactive integration and failure paths
forge test --match-path 'test/reactive/**' -vv

# Human-readable event-to-callback acceptance trace
./scripts/run-phase-4-demo.sh

# Inspect the complete call/event trace if needed
forge test \
  --match-test test_demo_reactiveEventMaturityCallbackAndAcknowledgement \
  -vvvv
```

## Acceptance trace

The demo uses the official Reactive simulator around a real local v4 swap:

1. `MarkoutRequested` reaches `MarkoutReactive` and creates a pending scheduler record.
2. A normalized reference update for the configured market is accepted.
3. Cron reaches maturity and emits one callback to the configured adapter.
4. The simulated callback proxy injects the configured Reactive identity.
5. The adapter authenticates delivery and the hook settles.
6. The hook's `MarkoutSettled` event is delivered back as an acknowledgement.
7. The Reactive record becomes final and later cron events emit nothing.

## Properties covered

- five constructor-time subscriptions use exact chain, emitter, event, and market boundaries;
- only the configured system service can call `react`;
- direct callbacks and callbacks with the wrong injected identity fail;
- requests and destination callbacks are idempotent;
- callbacks retry until a trusted terminal acknowledgement arrives;
- pre-maturity and future observations wait;
- stale, missing, zero, low-confidence, duplicate, out-of-order, and wrong-market data cannot settle a trade;
- exact-expiry settlement succeeds and post-expiry fallback returns the complete surcharge;
- one cron handles at most eight records, and its cursor revisits remaining work; and
- callback settlement preserves the Phase 3 hook's collateralized accounting.

## Deployment scripts prepared for Phase 5

```bash
# Destination chain: callback adapter, permission-mined hook, immutable binding
forge script script/DeployReactiveMarkoutHook.s.sol:DeployReactiveMarkoutHook \
  --rpc-url "$ORIGIN_RPC_URL" --broadcast -vv

# Reactive chain: scheduler and five subscriptions
forge script script/DeployMarkoutReactive.s.sol:DeployMarkoutReactive \
  --rpc-url "$REACTIVE_RPC_URL" --broadcast -vv
```

Do not run these against a public network until every address and chain parameter in `.env.example` has been replaced
with current official testnet configuration. `REACTIVE_IDENTITY` is the identity the destination callback proxy will
inject; it must be known before deploying the immutable destination adapter.

## Expected Phase 4 limitations

The live reference source, deployed addresses, callback funding, transaction monitoring, and explorer evidence remain
Phase 5 work. Static analysis and the final threat model remain Phase 7 work. Passing this gate is evidence of local
behavior, not an audit or production-readiness claim.
