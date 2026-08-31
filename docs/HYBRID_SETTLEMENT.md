# Hybrid Settlement Architecture

Status: Phase 10 architecture freeze

## 1. Objective

MARKOUT must settle delayed post-trade outcomes without a protocol-owned keeper and without making user funds depend
on one callback network. Reactive Network is the intended autonomous control plane for observation, maturity, retry,
acknowledgement, and expiry orchestration. Circle CCTP V2 is the publicly proven redundant observation-delivery rail.
The current public testnet evidence uses Circle because a Reactive destination callback has not been observed; that
evidence gap is disclosed rather than used to erase Reactive's architectural role. The Uniswap v4 hook remains the
sole owner of custody, economic validation, and terminal accounting.

## 2. End-to-end flow

```mermaid
flowchart TB
    SWAP["Uniswap v4 swap<br/>18 bps base + 50 bps provisional"] --> HOOK["MarkoutHook<br/>custody + immutable trade record"]
    HOOK --> WAIT["Five-minute markout maturity"]

    PYTH["Signed Pyth update"] --> PUB["Ethereum Sepolia publisher<br/>one normalized observation"]
    WAIT -. "trade becomes eligible" .-> PUB

    PUB --> CIRCLE["Circle CCTP V2 fallback<br/>attested generic message"]
    HOOK -. "MarkoutRequested" .-> REACTIVE["Reactive lifecycle engine<br/>events + cron + retries"]
    PUB --> REACTIVE

    CIRCLE --> CRECV["Circle receiver<br/>domain + sender + market checks"]
    REACTIVE --> RRECV["Reactive callback receiver<br/>proxy + RVM identity checks"]

    CRECV --> COORD["SettlementCoordinator<br/>first valid delivery wins"]
    RRECV --> COORD
    COORD --> HOOK

    HOOK --> REBATE["Good flow<br/>surcharge returned"]
    HOOK --> PROTECT["Adverse flow<br/>LP protection retained"]
    WAIT -. "neither path delivers" .-> EXPIRE["Permissionless expiry<br/>full surcharge rebate"]

    classDef reactive fill:#173c24,stroke:#8affad,color:#eef6f0,stroke-width:3px;
    classDef core fill:#121815,stroke:#66736b,color:#eef6f0;
    classDef proven fill:#101925,stroke:#82b9ff,color:#eef6f0;
    class REACTIVE,RRECV reactive;
    class CIRCLE,CRECV proven;
    class SWAP,HOOK,WAIT,PYTH,PUB,COORD,REBATE,PROTECT,EXPIRE core;
```

The diagram gives Reactive visual prominence because it is the no-keeper automation layer, while preserving the
evidence boundary: the full lifecycle engine is implemented and tested; the legacy pulse deployment, exact
subscription, ReactVM execution, and an 11-second authenticated destination callback are public. That callback reached
an already-terminal trade, so Circle remains the publicly proven economic-settlement path and Reactive-first economics
remain unclaimed.

```text
Unichain swap
    -> MarkoutHook escrows a bounded provisional surcharge
    -> trade remains Pending until its immutable maturity

Permissionless publisher on Ethereum Sepolia
    -> submits a signed Pyth update and a Unichain trade id
    -> publisher normalizes price, time, and confidence
    -> emits one canonical observation event
    -> sends the same payload through Circle MessageTransmitterV2

Publicly proven redundant rail: Circle
    -> Circle attests the generic message
    -> any relayer submits message + attestation on Unichain
    -> CircleObservationReceiver authenticates transmitter, source domain, source publisher, threshold, version, market
    -> SettlementCoordinator forwards the observation to MarkoutHook

Autonomous control plane: Reactive
    -> MarkoutReactive observes hook requests, terminal acknowledgements, reference evidence, and cron
    -> it tracks immutable maturity/expiry, requests sampling, and processes bounded batches
    -> it retries an authenticated settlement or expiry callback until acknowledgement
    -> the legacy-compatible pulse is a narrower deployed proof of the exact publisher-event subscription
    -> SettlementCoordinator forwards an observation only if the trade is still Pending

Failure path
    -> after the existing grace period, anyone calls MarkoutHook.expireTrade
    -> the entire provisional surcharge becomes claimable by the trader
```

## 3. Responsibility boundaries

### MarkoutHook

- Custodies every provisional surcharge.
- Stores execution price, direction, maturity, expiry, and beneficiary.
- Re-validates observation maturity, freshness, confidence, and settlement window.
- Computes markout and divides escrow into rebate plus LP protection.
- Enforces solvency and permissionless full-rebate expiry.

Neither Circle nor Reactive can select a recipient, change a trade's execution data, bypass validation, withdraw hook
funds, or settle a terminal trade twice.

### SettlementCoordinator

- Is the hook's only settlement authority.
- Is bound once to the hook and a finite source set.
- Has no owner action after topology binding.
- Treats delivery as at-least-once: the first valid observation settles, later authorized deliveries are no-ops.

### Circle path

- The source publisher accepts no trusted reporter price; it obtains a fresh price from a configured Pyth contract and
  feed id.
- The testnet ETH/USDC configuration uses Pyth ETH/USD as a proxy and assumes USDC remains close to one dollar. This
  basis risk is explicit; production must use a direct pair source or separately validate the quote asset.
- Circle authenticates the application message between its Sepolia and Unichain transmitters.
- Destination delivery is permissionless. A relayer has no application authority because it cannot forge Circle's
  attestation or alter the attested body.
- The publisher requests Circle threshold `1000`, whose confirmed Ethereum path fits the ten-minute MARKOUT window.
- The receiver accepts threshold `1000–1999` only through Circle's unfinalized handler and threshold `2000+` only
  through its finalized handler. It permanently pins the source domain, publisher, market, and coordinator.
- Fast confirmation introduces bounded source-reorganization risk. The hook still enforces maturity, freshness,
  confidence, and its immutable settlement outcome; deployments requiring hard finality must widen the settlement
  window rather than pretending a 15–19 minute Ethereum message fits the current ten-minute grace period.

### Reactive path

- **Event-native lifecycle:** the full engine subscribes to trade requests, settlement and expiry acknowledgements,
  normalized reference evidence, and cron rather than relying on a MARKOUT operator or polling service.
- **Maturity orchestration:** records only maturity, expiry, status, cursor, and retry timestamps needed to wake the
  delayed lifecycle and process at most eight trades per cron event.
- **Autonomous action:** eligible evidence is sufficient to request settlement; missing evidence requests sampling;
  an elapsed grace period requests permissionless-equivalent expiry.
- **Minimal payload:** the destination receives only `(marketId, tradeId, priceX18, observedAt, confidenceBps)`.
- **Least authority:** holds no custody, fee policy, rebate-recipient choice, price discretion, or upgrade role.
- **Authenticated destination:** uses both callback-proxy and injected RVM-identity checks before the coordinator can
  see the observation.
- **Order-independent redundancy:** the coordinator makes Circle-first and Reactive-first delivery economically
  identical, while only Reactive supplies the broader no-keeper orchestration.
- **Graceful degradation:** an unavailable callback cannot trap funds or change fees; Circle or permissionless expiry
  continues independently.

### Reactive public evidence

| Evidence | Status |
| --- | --- |
| Full Reactive lifecycle engine and 17 dedicated lifecycle tests | Verified locally |
| Five narrow subscriptions and bounded cron processing | Verified in source and tests |
| Legacy Lasna pulse deployed and funded | Verified |
| Exact publisher subscription created by the constructor | Verified |
| Stateless payload and authenticated destination receiver | Verified in source and tests |
| Circle-first / Reactive-first race equivalence | Verified in tests |
| Public Unichain callback transaction | Not observed; not claimed live |

The sponsor-facing contribution is the architecture pattern: Reactive turns a delayed hook obligation into an
event-driven lifecycle without becoming a custodian or trusted fee controller. The unobserved relayer outcome is
reported as infrastructure evidence, not hidden or promoted as a successful callback.

## 4. Race and replay policy

Circle and Reactive may deliver the same observation in either order. The coordinator reads the hook's current trade
status before forwarding:

- `Pending`: forward and let the hook perform full economic validation.
- `Settled` or `Expired`: emit a duplicate-delivery event and return successfully without changing accounting.
- `None`: reject the unknown trade.

Circle's transmitter provides nonce replay protection for the message itself. MARKOUT's terminal state provides the
application-level replay boundary across different transports.

## 5. Liveness policy

Reactive is the target no-keeper orchestration path; Circle is the currently proven redundant delivery path. Neither
availability assumption becomes a custody assumption. If no valid observation settles before the grace period ends,
`expireTrade` is permissionless and credits the complete provisional surcharge as a rebate. An unavailable transport
can reduce recorded LP protection; it cannot manufacture LP value or trap the trader's escrow indefinitely.

## 6. Active and research implementations

The Circle/coordinator contracts are the active public testnet topology. `MarkoutReactive`, callback canaries, and
deployment manifests remain the implemented autonomous architecture and reproducible outage evidence. They must not
be described as the live settlement authority unless a public destination callback proves that claim.

## 7. Public-proof boundary

The complete contract and deployment logic can be verified locally. A generic EVM fork cannot reproduce Reactive's
chain-specific subscription precompile, so the deployed pulse's constructor subscription must be proven by a live
legacy Lasna receipt. That limitation does not affect the Circle fallback, coordinator, hook, or full-rebate expiry.
