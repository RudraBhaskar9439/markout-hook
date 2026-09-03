# Reactive-First Lifecycle Specification

Status: Legacy Reactive transport is deployed and publicly verified. A complete pending-first economic allocation
through that transport remains unclaimed because the acceptance callback did not reach Unichain before expiry.

## Why Reactive Network is part of the mechanism

MARKOUT cannot determine a five-minute post-trade outcome inside the original swap transaction. A Unichain hook also
cannot subscribe to a future event on Ethereum Sepolia or wake itself when that event appears. Reactive Network fills
that missing event-to-action role:

1. a trade becomes eligible after its fixed maturity;
2. a canonical publisher verifies and normalizes the delayed Pyth observation on Ethereum Sepolia;
3. the deployed Reactive pulse consumes only the configured publisher event and market topic;
4. ReactVM validates the event and encodes an authenticated callback request; and
5. the Unichain receiver and hook validate the callback before allocating the provisional amount.

Reactive is the primary automation layer. It does not custody tokens, select a price, choose a fee, or control the
beneficiary. Those economic decisions remain inside immutable Unichain contracts.

## Deployed topology

```text
Unichain Sepolia
  MarkoutHook.afterSwap
    -> stores trade ID, execution price, direction, beneficiary, maturity, and expiry
    -> escrows the bounded provisional amount

Ethereum Sepolia
  canonical Pyth observation publisher
    -> verifies signed Pyth update
    -> binds price, publish time, confidence, market ID, and trade ID
    -> emits the normalized reference event

Legacy Reactive Lasna
  MarkoutPulseReactive
    -> exact publisher subscription
    -> exact event-signature subscription
    -> exact market-topic subscription
  ReactVM reaction
    -> decodes the normalized payload
    -> requests the authenticated Unichain callback

Unichain Sepolia
  ReactiveObservationReceiver
    -> verifies callback proxy and injected ReactVM identity
  SettlementCoordinator
    -> accepts the first valid delivery and makes later deliveries no-ops
  MarkoutHook
    -> revalidates time, confidence, market, direction, solvency, and state
    -> settles once or permits full-refund expiry
```

## Exact subscription boundary

The final deployed pulse is deliberately stateless. Constructor configuration pins:

- Ethereum Sepolia as the origin chain;
- the canonical observation publisher address;
- the normalized reference-price event signature;
- the ETH/USDC market topic;
- the Unichain destination chain and receiver; and
- the callback gas limit.

Unrelated logs cannot produce a MARKOUT callback. The narrow filter also keeps the sponsor integration reviewable:
the reaction performs deterministic decoding and callback encoding rather than offchain policy selection.

## Authentication and economic authority

The destination receiver requires both the configured Reactive callback proxy and the injected ReactVM identity. It
forwards a valid observation to the immutable coordinator, which is bound to the MARKOUT hook.

The hook independently checks:

- the trade exists and is still pending;
- maturity has been reached without crossing expiry;
- market ID and trade ID match;
- price and observation time are nonzero;
- the observation is neither early, future-dated, nor stale;
- confidence satisfies the configured minimum;
- the provisional amount remains solvent; and
- the trade has not already settled or expired.

Only after those checks does the hook compute directional markout and split the provisional amount. Reactive can
initiate this transition, but it cannot alter the allocation formula or move funds directly.

## At-least-once transport, exactly-once economics

Reactive delivery is treated as at least once. The receiver, coordinator, and hook make duplicate callbacks safe:

- the first valid pending delivery may settle the trade;
- a duplicate for a settled or expired trade succeeds as a no-op; and
- malformed, unauthenticated, or mismatched payloads revert.

This separates transport retries from economic finality. No callback can allocate the provisional amount twice.

## Fail-open user recovery

If no valid Reactive callback reaches Unichain before the grace period ends, anyone may call `expireTrade`. Expiry
credits the complete provisional amount to the original beneficiary's pull-based rebate balance. It cannot redirect
the refund and does not require an administrator.

The result is a bounded failure mode: transport interruption removes LP protection for that trade, but it does not
trap the trader's provisional funds.

## Public proof and its boundary

The committed [deployment record](../deployments/reactive-legacy-2026-08-26.json) proves:

- a funded Legacy Reactive pulse with a publicly verified exact subscription;
- live event processing in ReactVM;
- an authenticated callback from Ethereum Sepolia to Unichain in 11 seconds;
- safe no-op handling when the callback targets an already-terminal trade; and
- a separate pending-first run in which two ReactVM reactions occurred, the destination relayer missed expiry, and
  permissionless recovery returned and paid the full provisional amount.

The 11-second callback proves Reactive transport and authentication, not a pending-first economic settlement. The
acceptance run proves fail-open safety under a relayer outage, not successful destination delivery. These boundaries
are retained in the README, deck, dashboard, and submission draft.

## Historical implementations

The repository also contains an earlier stateful Omni scheduler and a pre-pivot CCTP recovery adapter. They remain for
test coverage and reproducibility. Neither is presented as the current primary architecture.

## References

- [Reactive-first settlement architecture](HYBRID_SETTLEMENT.md)
- [Public Reactive verification](PHASE_13_VERIFICATION.md)
- [Threat model](THREAT_MODEL.md)
- [Evidence ledger](EVIDENCE.md)
