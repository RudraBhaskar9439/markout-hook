# Decision Log

## D-001 - Outcome-based settlement

MARKOUT uses post-trade markout rather than a pre-trade toxicity classifier. This keeps the mechanism deterministic and directly testable.

## D-002 - Separate surcharge from ordinary LP fee

The MVP treats the provisional MARKOUT amount as a hook-level surcharge separate from the pool's normal LP fee. This
avoids promising to reverse an LP fee after Uniswap has already distributed it. Phase 1 proved the exact v4 accounting
implementation.

## D-003 - Reactive is the final settlement authority

The production-shaped MVP does not rely on a developer keeper. Reactive Network observes events, manages maturity, and originates the authenticated callback.

## D-004 - Pull-based rebates

Settlement records claimable rebates instead of pushing tokens to arbitrary trader contracts. This limits reentrancy and prevents one failed transfer from blocking unrelated settlements.

## D-005 - One pool before generalization

The first complete path targets one ETH/USDC-style pool. Generalized assets, configurable oracles, and multiple horizons are extensions after the research result works end to end.

## D-006 - Evidence before interface

The testnet callback and research comparison must pass before frontend work begins. The interface visualizes verified behavior; it does not substitute for it.

## D-007 - Use the unspecified swap currency for the provisional surcharge

Uniswap v4 applies an `afterSwap` return delta to the swap's unspecified side. MARKOUT therefore collects its
provisional surcharge from output on exact-input swaps and adds it to input on exact-output swaps. This keeps Phase 1
on v4's native custom-accounting path in all four swap quadrants.

## D-008 - Treat the user's maximum as an authorization boundary

Every swap supplies a rebate recipient and an absolute maximum surcharge in canonical hook data. The hook reverts the
entire swap if its quote exceeds that maximum. The maximum is not configuration or advisory slippage metadata; it is
the transaction-level consent boundary enforced by the hook. Integrating routers remain responsible for passing the
swapper-approved payload unchanged.

## D-009 - Separate accounting mechanics from economic policy

`BaseProvisionalSurcharge` owns PoolManager authorization, currency resolution, custody, accounting, and events.
Derived contracts implement only `_quoteSurcharge`, while the independent Phase 2 settlement engine allocates the
collected amount later. This lets future upfront surcharge policies and settlement curves evolve without rewriting the
custody-critical path.

## D-010 - Round the provisional surcharge down

Basis-point quotes use full-precision multiplication and floor division. Rounding down guarantees the collected value
never exceeds the mathematical percentage selected by the policy. A zero result is valid and causes no token transfer.

## D-011 - Account by pool and by currency

The hook records pool-scoped accruals while also tracking aggregate currency balances. This avoids mixing economic
ownership across pools while providing one aggregate that can be checked directly against each currency held by the
contract.

## D-012 - Normalize every price to quote per base at X18 precision

Execution and reference prices use quote-token units per one base token, scaled by `1e18`. Source decimals and inverse
feeds are normalized at the adapter boundary. Conversion and inversion round down, while a zero, precision-erased, or
`uint192`-overflowing result fails explicitly.

## D-013 - Use a continuous three-anchor retention curve

The MVP retains 0% at -5 bps markout, 20% at neutral markout, and 100% at +25 bps markout, with linear interpolation
between anchors. This produces a legible benign-versus-adverse demo without introducing a discontinuity that can be
gamed around one threshold. Interpolation and retained-amount arithmetic round down; settlement dust goes to rebate.

## D-014 - Require mature, fresh, confident observations inside a bounded window

Maturity is five minutes after execution. Settlement remains open for ten minutes after maturity. The selected
observation must be at or after maturity, not in the future, no more than two minutes old at evaluation, and at least
9,000 confidence bps. Confidence is a normalized adapter output whose source-specific derivation must be deterministic
and documented when the reference source is selected.

## D-015 - Oracle or automation failure produces a full rebate

If no valid observation settles a trade before the grace period ends, the trade expires and the complete provisional
surcharge becomes claimable by the trader. Missing infrastructure must not be interpreted as adverse flow or create
LP-owned value.

## D-016 - Keep every held unit in one explicit live accounting category

Every surcharge unit is pending, claimable by a beneficiary, or credited to a pool's LP protection reserve. Settlement
and expiry only move value between these categories; they do not transfer assets. The hook checks after every balance
transition that held currency covers the complete live accounting total.

## D-017 - Make the local settlement adapter replaceable, but its binding immutable

The Phase 3 adapter forwards observations through the same minimal target interface that Reactive will use. Its
operator and once-bound hook target cannot be changed. This preserves a narrow authenticated boundary without putting
temporary local-operator logic into the hook itself.

## D-018 - Derive execution price before applying MARKOUT's own return delta

The hook derives quote-per-base execution price and direction from the raw swap delta supplied by PoolManager. The
provisional surcharge is applied afterward as a return delta and is excluded from that price. MARKOUT therefore does
not contaminate its outcome measure with its own policy charge.

## D-019 - Use Reactive Omni's single-deployment model

`MarkoutReactive` is a standard EVM contract with one state store and no `vmOnly` or dual-deployment behavior. It uses
the current system service as the only `react` caller and retains the older `Callback` event format that Reactive has
committed to support during the Omni transition.

## D-020 - Authenticate both callback transport and Reactive identity

The destination adapter requires the configured callback proxy as `msg.sender` and the configured proxy-injected
Reactive identity as the callback's first argument. Either check alone would leave a broader trust boundary than the
protocol provides.

## D-021 - Treat callback delivery as at-least-once

The scheduler retries settlement or expiry on cron until it observes a terminal event from the immutable destination
hook. The destination adapter turns replay of an already terminal trade into a successful no-op. Economic finality is
therefore independent from whether acknowledgement delivery races or is delayed.

## D-022 - Bound cron work and preserve fair progress

One cron examines at most eight trade records and advances a circular cursor. Callback bursts and execution gas stay
bounded, while every stored position is revisited on later crons. Throughput optimization requires Phase 6 evidence
and cannot weaken the fail-open expiry policy.

## D-023 - Request the reference observation at maturity

Historical Phase 5 decision; superseded for the active topology by D-038 through D-041.

The Phase 5 source is pull-on-callback rather than a continuously pushed reporter. When a mature trade lacks an
eligible observation, one Reactive callback requests a sample and a global 60-second cooldown bounds retries. The
sampler's resulting normalized event immediately re-enters settlement processing. Reactive is therefore essential to
both observation timing and settlement; no developer EOA publishes the price.

## D-024 - Use a three-fee-tier median only as the testnet transport proof

The live testnet adapter reads three WETH/USDC Uniswap v3 pools, validates the pair and minimum liquidity, sorts their
spot prices, and publishes the median. Confidence is `10,000 - maximum adjacent dispersion in bps`; a sample above the
immutable dispersion ceiling reverts. This makes one outlying pool insufficient, but does not claim production-oracle
security: the venues share one chain, spot prices remain manipulable, and testnet observation histories are shallow.

## D-025 - Make every callback target a funded Reactive payer

Destination callback contracts inherit one shared module that accepts native gas funds, authorizes only the configured
callback proxy to collect payment, and exposes permissionless debt coverage. This payment surface is separate from
application authority: funding the adapter or sampler grants no settlement, sampling, withdrawal, upgrade, or target
selection capability.

## D-026 - Compare every policy against one deterministic trade tape

The Phase 6 fixed, volatility, and MARKOUT policies receive identical seeded trades. This isolates fee allocation from
order-flow selection and makes exact artifact reproduction possible. It also means the experiment cannot claim that a
policy increases volume, changes routing, or deters informed flow; those require an elasticity model or historical
counterfactual that is outside the MVP.

## D-027 - Call notional times positive markout an adverse-selection proxy, not exact LVR

`notional × max(directional markout, 0)` approximates value captured by favorably marked flow at the pool level. Exact
loss-versus-rebalancing compares an AMM LP with a continuously rebalanced benchmark, while position-level loss also
depends on active range depth, LP share, path, and rebalancing. Phase 6 therefore reports a post-trade
adverse-selection proxy and subtracts it from retained fees without presenting it as individual LP PnL.

## D-028 - Treat experiment failures and callback cost as first-class results

Stale or manipulated reference attempts use the implemented fail-open expiry rule and receive a full provisional-
surcharge rebate. Their lost LP protection is reported as a regression. Callback cost assumes isolated trades with one
sampling attempt plus settlement or expiry and uses configured budgets; it is not represented as measured public gas
spend. Production batching can reduce sampling calls, while retries can increase them.

## D-029 - Prefer per-trade fail-open recovery over a privileged global pause

MARKOUT has no administrator capable of seizing escrow, rewriting beneficiaries, settling trades, or pausing claims.
Invalid observations leave accounting unchanged; after the immutable grace period, anyone can expire the individual
trade into a full rebate. A global pause would create a privileged liveness dependency and could trap unrelated users.
Configuration or authority compromise therefore requires abandoning the affected immutable deployment and deploying a
new instance, not mutating live custody rules.

## D-030 - Fail static analysis on every medium or high finding and review every lower finding

Slither and its complete Python dependency graph are locked. CI rejects any medium- or high-severity result. Low and
informational results are not silently excluded: Phase 7 records each detector family, why the pattern exists, the
control that bounds it, and its residual risk. Inline suppression is limited to the v3 `slot0` tuple fields that are
intentionally unused; the consumed square-root price remains checked by the pricing library.

## D-031 - Treat the MVP deployment universe as immutable and asset-curated

PoolManager, callback transport, Reactive identity, market pair, sampler pools, confidence bounds, and surcharge curve
are constructor-fixed. The MVP supports native currency and conventional ERC-20 behavior; fee-on-transfer, rebasing,
ERC-777-style callback, or otherwise adversarial assets are outside the deployment allowlist. The hook is not
upgradeable, and Phase 7 does not add an administrator under the label of emergency control.

## D-032 - Keep the judge path deterministic until public evidence exists

The Phase 8 application reads a typed, repository-owned projection of the committed Phase 6 experiment and replays the
already-tested local Reactive lifecycle. It has no wallet, database, secret, or mutable backend. This gives every judge
the same understandable path while the application clearly labels its values as deterministic research evidence rather
than a live market feed.

## D-033 - Never manufacture the missing Lasna proof

Historical Phase 8 disclosure; the current dashboard applies the same evidence policy to the Circle-primary path.

The dashboard presents `Live cron proven · callback delivery pending` until public transactions prove complete
destination settlement. Only explorer-backed transactions may strengthen that state. A local replay or a Lasna
callback-request event may demonstrate mechanism and scheduler progress, but neither can satisfy Phase 5 or the live
portion of Phase 8 without the destination transaction.

## D-034 - Derive social metadata from the request origin

The judge application constructs canonical and preview-image URLs from validated forwarded-host and protocol headers,
with a localhost fallback. One deployable build therefore produces correct absolute sharing metadata on both local and
hosted environments without hard-coding a temporary deployment hostname.

## D-035 - Separate the Omni service from the cron emitter

Lasna Omni authenticates `react`, registers subscriptions, and accounts payment through
`0x8888888888888888888888888888888888888888`, but current on-chain `Cron10` logs originate from
`0x0000000000000000000000000000000000fffFfF`. MARKOUT configures these roles independently and validates both at
deployment and preflight. This decision came from the first public acceptance attempt: the request subscription
worked, but `lastReferenceSampleRequestedAt` remained zero because the cron filter targeted the service address.

## D-036 - Rate-limit terminal callback retries independently of cron

Omni produces `Cron10` approximately every ten seconds. Settlement and expiry retries therefore use a per-trade
60-second cooldown instead of emitting on every eligible cron. The first callback remains immediate, acknowledgement
still finalizes the record, and a lost callback remains retryable. This bound was added after a public relayer outage
showed that an unacknowledged expiry could otherwise consume lREACT every ten seconds without improving delivery.

## D-037 - Require a destination canary before migrating MARKOUT

A minimal authenticated canary must prove event ingestion and callback delivery before MARKOUT is redeployed to a new
destination. The Ethereum Sepolia canary emitted three independent requests; Lasna ingested all three and emitted
three correctly targeted callbacks, but Ethereum Sepolia received none during the bounded observation window. The
destination contract retained its full callback balance and accrued no proxy debt, so no delivery attempt was
observable. Because the same failure now exists on two supported destinations, changing chains alone is not accepted
as a liveness fix.

## D-038 - Remove Reactive from the critical settlement path

Two bounded public canaries produced correctly targeted callback instructions on Lasna but no destination delivery on
either Unichain Sepolia or Ethereum Sepolia. The active topology therefore cannot make custody or settlement depend on
Reactive liveness. Reactive remains an optional observation accelerator; the existing Omni scheduler remains research
and outage evidence.

## D-039 - Use Circle CCTP V2 as the primary authenticated message transport

A permissionless Ethereum Sepolia publisher validates a configured Pyth feed and sends the normalized observation as a
generic Circle message to Unichain Sepolia. It requests threshold `1000` because Circle documents roughly 20-second
Ethereum confirmation at that threshold, while hard finality at `2000` averages 15–19 minutes and cannot fit the
current ten-minute settlement window. The destination receiver uses disjoint confirmed and finalized handlers and
pins Circle's transmitter, source domain, publisher, market, and message version. Any account may relay the attested
message, but no relayer may alter it. The documented tradeoff is bounded source-reorganization risk on the fast path.

## D-040 - Make transport delivery at-least-once across protocols

One immutable coordinator authorizes the Circle receiver and optional Reactive receiver. The first valid delivery for
a pending trade is forwarded to the hook. Later authorized deliveries are successful no-ops. The hook's terminal state
is the cross-transport replay boundary, so delivery order cannot change economics.

## D-041 - Keep the Reactive pulse stateless

The forward Reactive Contract observes the canonical Circle-publisher event and forwards its normalized payload. It
does not own maturity scheduling, trade discovery, price sampling, retries, custody, or economic state. This narrow
role mirrors Maestro's proven architecture while ensuring Reactive failure cannot block MARKOUT.

## D-042 - Treat ETH/USD as an explicit testnet proxy, not a direct ETH/USDC oracle

The hybrid testnet publisher uses Pyth's ETH/USD feed while the destination market is ETH/USDC. This assumes USDC is
approximately one dollar and leaves quote-basis risk outside the MVP. Every judge-facing document labels that
assumption. A production deployment must use a direct ETH/USDC source or validate and combine an independent USDC/USD
feed before it may claim pair-accurate markout.

## D-043 - Do not treat an Anvil legacy fork as subscription evidence

Reactive's legacy system contract delegates subscription registration to a chain-specific precompile. A generic Anvil
fork reproduces the system bytecode but not that precompile, so constructor subscription calls revert there even when
the contract is funded. Unit tests prove filter and callback semantics; only a live legacy Lasna deployment receipt
can prove registration. Circle settlement remains independent of this optional proof.

## D-044 - Select the Fair-Flow base fee through declared constraints

The release candidate uses an 18 bps base plus the existing refundable 50 bps surcharge. A deterministic sweep of
every integer base from 10 through 30 bps chooses the lowest candidate that keeps benign and inventory-improving
effective fees at or below 30 bps while preserving at least 20% modeled LP net-after-proxy improvement versus the
fixed 30 bps baseline. The public 30 + 50 bps pool remains historical deployment evidence and is never relabeled as
the candidate.

## D-045 - Allow sponsored claims without sponsor-controlled recipients

Any address may pay gas to claim a rebate for a named beneficiary, but the hook always transfers that sponsored claim
to the beneficiary itself. Only the beneficiary-controlled pull path may select a different recipient. Both paths
share the same checks-effects-interactions accounting and reentrancy guard, so a relayer can improve trader experience
without acquiring redirect authority.

## D-046 - Separate source-price freshness from cross-chain transport latency

The signed Pyth update must be no more than 120 seconds old when the Ethereum publisher verifies it. Destination
settlement allows that already-verified observation up to five minutes to traverse an asynchronous transport, while
the independent ten-minute post-maturity grace period remains unchanged. This split was added after a live Legacy
reaction emitted a correctly targeted callback request, while destination evaluation 129 seconds after the observation
hit the previous shared 120-second bound. Source oracle freshness is not relaxed; only the delivery-latency budget is
modeled separately.

## D-047 - Restore Legacy Reactive as a live transport without overstating settlement reliability

After the Reactive team recommended Legacy, a canonical publisher event completed an authenticated Unichain callback
in 11 seconds. Reactive transport liveness may therefore be marked true. The callback reached an already-terminal
trade, and a separate pending-first run later produced two successful ReactVM reactions but no destination transaction
before expiry. MARKOUT therefore keeps Circle as an independent resilience rail and reports Reactive-first economic
settlement as unproven. Transport liveness, ReactVM execution, relayer reliability, and economic settlement remain
separate release claims.
