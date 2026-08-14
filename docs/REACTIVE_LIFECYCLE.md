# Reactive Lifecycle Specification

Status: Phase 4 implemented and covered by local end-to-end simulation.

## Scope and network model

`MarkoutReactive` is the autonomous scheduler between the origin hook, a normalized reference-price event, and the
destination callback adapter. It targets Reactive Network's current Omni architecture: one standard-EVM Reactive
deployment, with no application state split across an origin contract and ReactVM copy. It deliberately emits the
legacy-compatible `Callback(uint256,address,uint64,bytes)` event because Reactive Network states that this callback
delivery format remains supported during the Omni transition.

The implementation uses the official pinned `reactive-lib`. Local integration tests use the official pinned
`reactive-test-lib`, a real Uniswap v4 `PoolManager`, real swaps, the real MARKOUT hook, and callback-proxy simulation.

## Subscriptions

One scheduler registers exactly five narrow subscriptions during construction:

1. `MarkoutRequested` from the configured hook on the origin chain;
2. `MarkoutSettled` from that hook for delivery acknowledgement;
3. `MarkoutExpired` from that hook for delivery acknowledgement;
4. `NormalizedReferencePricePublished` from one configured feed and indexed market ID; and
5. one configured Reactive cron topic from the configured system service.

Chain IDs, contract addresses, market ID, and cron topic are immutable. A log that does not match those boundaries has
no state effect.

## End-to-end sequence

```text
Uniswap swap
    -> MarkoutHook emits MarkoutRequested
    -> MarkoutReactive records only maturity, expiry, and delivery state

Reference source
    -> normalization adapter emits a price, observation time, and confidence
    -> MarkoutReactive accepts it only if it is newer, nonzero, and sufficiently confident

Reactive cron
    -> scans at most eight records using a persistent circular cursor
    -> waits before maturity
    -> requests settlement when the latest observation is eligible
    -> requests full-rebate expiry only after the grace period

Reactive callback proxy
    -> injects the authorized Reactive identity into the callback payload
    -> ReactiveMarkoutSettlementAdapter checks both proxy sender and injected identity
    -> MarkoutHook settles or expires the trade

Hook terminal event
    -> MarkoutReactive acknowledges delivery and finalizes its local record
```

## Delivery states and retries

```text
None -> Pending -> SettlementPendingAcknowledgement -> Finalized
                \-> ExpiryPendingAcknowledgement ----/
```

The callback is at-least-once, not assumed to be exactly-once. Until a trusted hook terminal event is observed, each
eligible cron can emit the same callback again. The destination adapter reads the hook's state before forwarding:

- a pending trade is forwarded once;
- an already settled or expired trade returns successfully without changing accounting; and
- an unknown trade reverts.

This separates transport retry from economic finality. A delivered callback cannot settle twice, and a callback lost
after emission is retried.

## Price and expiry rules

The scheduler accepts only a monotonically newer normalized observation whose:

- price and observation timestamp are nonzero;
- confidence is between 9,000 and 10,000 basis points; and
- indexed market ID matches the configured market.

At cron evaluation the observation must be at or after trade maturity, not in the future, and no more than two minutes
old. The exact expiry timestamp remains settleable. Beginning one second after expiry, the scheduler requests expiry;
the hook then credits the entire provisional surcharge as a trader rebate. A stale or missing source therefore cannot
create LP-owned value.

## Bounded processing

Each cron processes at most eight array positions and advances a persistent cursor. Work is bounded even if many
trades exist; every position is revisited over subsequent crons. Phase 4 tests create nine live trades and prove that
the first cron emits eight callbacks while the next cursor pass handles the ninth.

This is the safe MVP policy, not a final throughput claim. Phase 6 measures event and callback cost, while Phase 7 can
introduce a more advanced queue only if evidence shows it is required.

## Authentication boundary

The hook authorizes only its immutable settlement adapter. The adapter in turn requires both:

- `msg.sender` equals the configured Reactive callback proxy; and
- the proxy-injected first argument equals the configured Reactive identity.

Direct calls, a real proxy carrying the wrong identity, an unbound target, and rebinding all fail. The adapter has no
withdrawal, upgrade, arbitrary-call, or owner-settlement path.

## Deliberate Phase 4 boundary

- The reference event is represented by a stable normalized interface and a local mock. Selecting and implementing
  the live source-specific adapter is part of Phase 5.
- Callback gas, service address, callback proxy, cron topic, chain IDs, and Reactive identity must be confirmed against
  the current testnet configuration immediately before deployment.
- Phase 4 proves behavior locally. It does not claim that a live cross-network callback has succeeded.
- Callback funding, explorer evidence, monitoring, and deployment manifests are Phase 5 deliverables.

## Upstream compatibility references

- [Reactive Network roadmap and Omni technical details](https://blog.reactive.network/reactive-network-roadmap-a-closer-look-at-the-technical-details/)
- [Reactive testnet transition announcement](https://blog.reactive.network/reactives-next-chapter-starts-testnet-launch-team-news/)
- [Official reactive-lib](https://github.com/Reactive-Network/reactive-lib)
- [Official reactive-test-lib](https://github.com/Reactive-Network/reactive-test-lib)
