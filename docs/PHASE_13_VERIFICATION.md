# Phase 13 Verification - Primary Stateless Reactive Pulse

## Automated gate

```bash
./scripts/verify-phase-13.sh
```

The gate verifies:

1. The RSC registers exactly one Ethereum Sepolia subscription for the configured publisher, event signature, and
   market.
2. One `ObservationPublished` event produces one Unichain callback carrying the exact Pyth-normalized price, time, and
   confidence.
3. The destination requires both the configured callback proxy and the injected ReactVM identity.
4. Wrong markets, zero trade ids, malformed configuration, and unauthenticated calls fail safely.
5. Reactive delivery and later authenticated duplicates preserve the first terminal MARKOUT allocation.
6. The active pulse source contains no mapping, cron, retry, maturity, or expiry logic.

## Responsibility boundary

`MarkoutPulseReactive` does only three things:

1. subscribe to the canonical publisher event;
2. encode the event's exact normalized observation as a callback;
3. target the immutable `ReactiveObservationReceiver` on Unichain Sepolia.

It does not discover trades, sample prices, schedule maturity, retry delivery, hold funds, or decide economics.
`ReactiveObservationReceiver` authenticates the callback and forwards to `SettlementCoordinator`; the hook repeats all
economic validation. If Reactive does not deliver, permissionless expiry preserves the full-refund guarantee.

## Live evidence boundary

The local simulator proves subscription filtering, RVM-id injection, callback authentication, and settlement races.
It does not prove that the public relayer delivered a callback. Phase 14 may describe Reactive as live only after all
of these are public:

- the publisher's Ethereum Sepolia `ObservationPublished` transaction;
- the corresponding ReactVM execution or `ObservationPulseRequested` trace;
- the Unichain callback transaction from the configured proxy;
- `ReactiveObservationReceived` at the destination.

Legacy lREACT funds the primary pulse. Permissionless full-rebate expiry does not require lREACT.

Official references:

- [Reactive events and callbacks](https://dev.reactive.network/legacy/events-%26-callbacks)
- [Reactive subscriptions](https://dev.reactive.network/legacy/subscriptions)
- [Reactive Foundry testing](https://dev.reactive.network/legacy/testing)
