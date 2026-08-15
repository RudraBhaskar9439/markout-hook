# MARKOUT Threat Model

Status: Phase 7 internal engineering threat model. MARKOUT is not audited and is not approved for real funds.

## Scope and assets

The scope is the Uniswap v4 hook, surcharge custody, trade lifecycle, reference sampler, Reactive scheduler, settlement
adapters, and trader rebate claim path. The assets and properties being protected are:

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
| Reactive system service | Trusted log-delivery transport | Sole caller of `react`; cannot directly settle destination custody |
| Callback proxy | Trusted callback transport and gas-payment vendor | Must also provide the immutable Reactive identity |
| Reactive identity | Immutable application identity | Required together with callback-proxy sender |
| Three v3 reference pools | Economically untrusted inputs | Supply spot prices; median, liquidity, dispersion, time, and confidence checks bound but do not eliminate manipulation |
| Settlement adapter | Immutable, one-time-bound boundary | Sole hook settlement authority; cannot change beneficiary or escrow amount |
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
8. One cron examines at most eight trades and maintains a circular progress cursor.

## Threat review

| Threat | Control and evidence | Residual risk |
| --- | --- | --- |
| Return-delta overcharge | User maximum, 10% deployment cap, floor rounding, four-quadrant accounting tests | A user can still approve an economically undesirable maximum |
| Escrow insolvency | Balance assertion after every transition plus stateful exact-backing invariants | Exotic token behavior is unsupported |
| Unauthorized settlement | Immutable adapter authority; callback checks proxy and Reactive identity | Compromised trusted transport can submit an otherwise valid observation |
| Replay or duplicate logs | Terminal hook state and idempotent adapter; duplicate Reactive requests ignored | Reorg behavior still depends on upstream delivery guarantees |
| Rebate theft or redirect | Claim mapping keyed by `msg.sender`; adversarial redirect tests | Beneficiary key compromise remains user risk |
| Claim reentrancy | State zeroed before transfer plus `nonReentrant`; malicious native recipient test | Non-standard ERC-20 behavior is outside the allowlist |
| Recipient rejects native token | Failed call restores credit; beneficiary can retry to another recipient | User must perform the retry |
| Premature expiry | Exact timestamp boundary enforced; adversarial invariant action | Validator timestamp influence can affect eligibility by ordinary consensus bounds |
| Missing/stale/invalid reference | Settlement reverts without mutation; permissionless full-rebate expiry | LP protection is reduced during oracle outages by design |
| Single-pool price manipulation | Three-pool median, pair/liquidity checks, dispersion-derived confidence | Same-chain spot pools can be jointly manipulated; production needs TWAP/oracle hardening |
| Callback denial of service | Bounded cron scan, cooldown, retries, terminal acknowledgement, public expiry | Sustained transport failure delays settlement until anyone expires on destination |
| Callback gas griefing | Fixed callback budgets and at most eight scanned trades | Public-network gas adequacy is not proven until Phase 5 live evidence |
| Forced token donation | Accounting ignores surplus and adversarial test proves it is not claimable | Surplus has no recovery path in the immutable MVP |
| Malicious target rebinding | Adapter target can be bound exactly once by immutable binder | Binder must bind the correct target before operational use |
| Configuration compromise | Constructor validation and immutable addresses/parameters | Misconfiguration requires a new deployment; there is no in-place repair |
| Reserve theft | No external reserve withdrawal exists | LP reserve is accounting evidence only and is not yet distributable or reinvested |

## Emergency and recovery policy

MARKOUT deliberately has no privileged global pause. A global pause could trap every pending trade and every claimant.
Recovery is local and fail-open:

1. Invalid settlement attempts revert without consuming the trade.
2. The scheduler retries transport failures and awaits a terminal acknowledgement.
3. After the grace period, any address can expire the affected trade into a full rebate.
4. Claims are pull-based, so one failing recipient does not block another trade or user.
5. A compromised or misconfigured immutable deployment is deprecated and replaced; custody rules are never upgraded in
   place.

Operational monitoring should alert on aged pending trades, callback retry frequency, sampler dispersion/liquidity
failures, and a difference between actual and accounted balances. Live alert thresholds remain a Phase 5/production
operations task.

## Release boundary

Phase 7 establishes internal tests and static-analysis evidence. Before any real-fund deployment, the reference design
must move beyond three same-chain spot pools, supported tokens must be explicitly allowlisted, LP reserve disposition
must be designed, live callback gas must be measured, and an independent audit must review the final deployed bytecode.
