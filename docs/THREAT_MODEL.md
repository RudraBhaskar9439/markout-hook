# MARKOUT Threat Model

Status: Phase 13 hybrid-transport engineering threat model. MARKOUT is not audited and is not approved for real funds.

## Scope and assets

The active scope is the Uniswap v4 hook, surcharge custody, trade lifecycle, Pyth publisher, Circle and optional
Reactive receivers, immutable settlement coordinator, and trader rebate claim path. The previous Reactive scheduler
and same-chain sampler remain research artifacts rather than the active deployment topology. Protected properties are:

- pending provisional surcharges;
- claimable trader rebates;
- pool-scoped LP protection accounting;
- trade status and one-time terminal allocation;
- reference observation integrity and freshness;
- autonomous callback authenticity and liveness.

Frontend integrity, RPC availability, private-key custody, production oracle design, LP reserve distribution, and the
security of external Uniswap or Reactive deployments are not proven by this repository.

## Trust boundaries

| Actor or component | Trust assumption | Authority |
| --- | --- | --- |
| Uniswap v4 PoolManager | Immutable pinned protocol dependency and only hook-callback caller | Delivers swaps and transfers the return-delta surcharge |
| Trader/router/claim recipient | Fully untrusted | Chooses bounded maximum surcharge, beneficiary, and final claim recipient |
| Pyth Core | Trusted signed price source | Supplies price, confidence interval, exponent, and publish time to the permissionless publisher |
| Circle CCTP V2 | Primary authenticated message transport | Attests the publisher's message; cannot bypass hook validation or select a beneficiary |
| Circle publisher caller | Fully untrusted | Supplies signed Pyth update bytes, exact fee, and trade id; cannot directly choose a price |
| Reactive system and callback proxy | Optional log and callback transport | May mirror the publisher event; must also provide the immutable Reactive identity |
| Settlement coordinator | Immutable multi-transport boundary | Sole hook settlement authority; first valid authorized delivery wins |
| Any public address | Untrusted | May expire a trade only after grace and may claim only its own credit |

There is no upgrade administrator, pause administrator, escrow owner, or arbitrary reserve withdrawer.

## Safety invariants

1. Actual currency balance is never below pending plus claimable plus reserve accounting.
2. Every terminal allocation equals the exact escrow: `retained + rebate = escrow`.
3. A trade moves from pending to settled or expired at most once.
4. Only the immutable settlement authority can settle; expiry alone becomes permissionless after grace.
5. A caller can withdraw only its own claimable balance, although it may choose the receiving address.
6. Invalid observation or callback attempts leave lifecycle accounting unchanged.
7. Missing infrastructure eventually fails open to a complete trader rebate.
8. Circle and Reactive delivery order cannot change a terminal trade allocation.

## Threat review

| Threat | Control and evidence | Residual risk |
| --- | --- | --- |
| Return-delta overcharge | User maximum, 10% deployment cap, floor rounding, four-quadrant accounting tests | A user can still approve an economically undesirable maximum |
| Escrow insolvency | Balance assertion after every transition plus stateful exact-backing invariants | Exotic token behavior is unsupported |
| Unauthorized settlement | Coordinator authorizes immutable receivers; Circle pins its envelope; Reactive checks proxy plus identity | Compromise of Pyth or an authenticated transport remains an upstream risk |
| Replay or duplicate logs | Circle nonce protection plus terminal hook state and coordinator no-op semantics | Cross-transport duplicates still consume delivery gas |
| Circle fast-confirmation reorg | Threshold `1000` fits the ten-minute window; hook repeats maturity, freshness, confidence, and state checks | A confirmed Ethereum source message can be reorganized; hard-finalized deployments must widen the window |
| Malicious publisher caller | Pyth verifies the signed update and publisher forwards only its normalized result | Liveness can be spammed at the caller's own gas cost; unknown trades fail at the coordinator |
| Rebate theft or redirect | Claim mapping keyed by `msg.sender`; adversarial redirect tests | Beneficiary key compromise remains user risk |
| Claim reentrancy | State zeroed before transfer plus `nonReentrant`; malicious native recipient test | Non-standard ERC-20 behavior is outside the allowlist |
| Recipient rejects native token | Failed call restores credit; beneficiary can retry to another recipient | User must perform the retry |
| Premature expiry | Exact timestamp boundary enforced; adversarial invariant action | Validator timestamp influence can affect eligibility by ordinary consensus bounds |
| Missing/stale/invalid reference | Settlement reverts without mutation; permissionless full-rebate expiry | LP protection is reduced during oracle outages by design |
| Oracle manipulation | Pyth signature verification, bounded age, and mechanical confidence normalization | Pyth compromise, stale upstream markets, or incorrect feed selection remain external risks |
| ETH/USD quote basis | Testnet configuration documents ETH/USD as an ETH/USDC proxy | USDC depeg or basis movement can distort markout; production needs a direct pair or quote-asset validation |
| Transport denial of service | Circle is primary, Reactive is optional, and public expiry returns the full surcharge | A dual outage reduces LP protection and delays settlement until expiry |
| Callback gas griefing | Stateless one-event/one-callback pulse with a fixed callback budget | Public-network gas adequacy remains unproven until explorer-backed delivery |
| Forced token donation | Accounting ignores surplus and adversarial test proves it is not claimable | Surplus has no recovery path in the immutable MVP |
| Malicious target rebinding | Adapter target can be bound exactly once by immutable binder | Binder must bind the correct target before operational use |
| Configuration compromise | Constructor validation and immutable addresses/parameters | Misconfiguration requires a new deployment; there is no in-place repair |
| Reserve theft | No external reserve withdrawal exists | LP reserve is accounting evidence only and is not yet distributable or reinvested |

## Emergency and recovery policy

MARKOUT deliberately has no privileged global pause. A global pause could trap every pending trade and every claimant.
Recovery is local and fail-open:

1. Invalid settlement attempts revert without consuming the trade.
2. Circle delivery may be retried permissionlessly; an optional Reactive duplicate is harmless.
3. After the grace period, any address can expire the affected trade into a full rebate.
4. Claims are pull-based, so one failing recipient does not block another trade or user.
5. A compromised or misconfigured immutable deployment is deprecated and replaced; custody rules are never upgraded in
   place.

Operational monitoring should alert on aged pending trades, Circle attestation latency, rejected transport messages,
optional callback failures, and any difference between actual and accounted balances. Live thresholds remain a
Phase 14/production operations task.

## Release boundary

The repository establishes internal tests and static-analysis evidence only. Before any real-fund deployment, the
Pyth/Circle trust, quote-basis, and finality policy must receive independent review, supported tokens must be explicitly allowlisted,
LP reserve disposition must be designed, live transport gas and latency must be measured, and an independent audit
must review the final deployed bytecode.
