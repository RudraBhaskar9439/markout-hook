# MARKOUT Judge Presentation Playbook

## Objective

The Maestro feedback establishes the presentation constraint: the problem explanation and technical coherence were
strong, but the architecture diagram consumed too much time and reduced the presentation score to 3.5/5. MARKOUT
should preserve the separated-system visual while explaining only one memorable flow from it.

Target: four minutes, with a hard stop at 3:55.

Use the quoted lines as rehearsal beats, not a teleprompter. Rewrite them in your normal speaking style and explain the
code in your own words; the UHI rubric explicitly marks down fully AI-produced presentations.

## The one-sentence thesis

> MARKOUT is a Uniswap v4 hook that charges a provisional fee, waits to see whether the trade actually harmed LPs,
> then rebates good flow and retains only the outcome-justified amount as LP protection.

## Four-minute run of show

### 0:00-0:25 - Why

Show the hero.

"A normal AMM fixes the fee before it knows whether the trade was harmful. A volatility fee protects LPs by charging
everyone more. MARKOUT asks a narrower question: after five minutes, did this trade actually capture value from the
pool?"

Do not mention implementation yet.

### 0:25-0:55 - What changes for the trader

Show the benign comparison.

"The trader sees an 18 bps base and a refundable 50 bps provisional charge. Benign flow finishes at 27.43 bps on our
study - below the normal 30 bps pool. Inventory-improving flow receives the full surcharge back and finishes at 18
bps. Adverse flow pays more only after the observed outcome justifies it."

Switch once to informed flow, then return to benign. Do not explain every chart label.

### 0:55-1:40 - Working product

Show a pre-completed Fair-Flow receipt in the live testnet console.

"This is not a mock swap. The wallet submitted a real Uniswap v4 testnet transaction. The hook escrowed the
provisional charge, a Pyth-verified observation arrived, the hook finalized at 18 bps, and the sponsored claim returned
the rebate. Every transaction is linked."

Do not wait five minutes during judging. Keep a completed trade ID loaded and use the live buttons only if the network
is responsive.

### 1:40-2:10 - Mechanism

Replay the five-step mechanism.

"The hook records execution and custody. The trade matures. Pyth verifies and publishes one canonical observation.
Reactive subscribes to that event, executes the reaction in ReactVM, and requests an authenticated Unichain callback.
The hook then applies one bounded curve - no wallet blacklist and no operator choosing the outcome."

### 2:10-2:40 - Architecture and Reactive Network

Show the separated architecture and point to each plane only once.

"Frontend explains. Unichain accounts. Ethereum verifies. Reactive connects the event to an authenticated action.
The hook cannot subscribe to a foreign-chain Pyth publication by itself, so Reactive turns that canonical event into
a Unichain callback without a MARKOUT-owned cross-chain relayer. Circle is an independent delivery rail, and the
coordinator makes their order harmless."

Then show the Reactive section:

"The funded Legacy pulse is publicly deployed and exactly subscribed. One publisher event completed the full
ReactVM-to-Unichain callback path in 11 seconds. In a separate pending-first trial, ReactVM emitted two valid callback
requests but the destination relayer timed out; the trade expired and refunded in full. I separate transport proof
from economic-settlement proof."

Hard rule: leave architecture after 30 seconds. Maestro spent roughly half the presentation on it; MARKOUT must not.

### 2:40-3:25 - Research result

Show the research protocol before the result chart.

"I froze one deterministic 768-trade, 1.999 million dollar tape across six regimes and gave the same trades to fixed,
volatility, and MARKOUT policies. I then swept 21 base fees from 10 to 30 bps under constraints declared before
selection. Eighteen bps was the first candidate that kept good flow at or below 30 bps while preserving at least 20%
modeled LP improvement."

"Under those exact conditions, benign fees fall 8.58%, inventory-improving fees fall 40%, and modeled LP
net-after-proxy improves 21.87% versus fixed. This is a controlled synthetic mechanism study, not historical market
backtesting and not exact LVR."

### 3:25-3:55 - Proof and close

Show the public evidence card.

"MARKOUT has 214 passing contract tests, four public Circle-completed lifecycles covering full rebate and full
retention, a separately deployed Fair-Flow pool, and zero medium or high Slither findings. MARKOUT does not guess who
is toxic. It prices what the trade actually did."

Stop. Do not add another feature list.

## Architecture narration - maximum four sentences

1. "The frontend submits a real swap and reads the receipt; it never computes the outcome."
2. "The Unichain hook owns custody, maturity validation, and fee allocation."
3. "Pyth creates canonical evidence, while Reactive turns that foreign-chain event into an authenticated action."
4. "Circle is an independent delivery rail, and permissionless expiry guarantees a full refund if neither route succeeds."

## Questions judges are likely to ask

### Why would a trader use a pool that can charge 68 bps?

Good and inventory-improving flow receive rebates and already beat 30 bps at equal execution in the declared study.
Informed flow uses the pool only when its opportunity exceeds the fee or the pool offers a better all-in quote. The
mechanism intentionally attracts good flow and makes small adverse-selection opportunities uneconomic.

### Is the 21.87% result exact LP profit or LVR reduction?

No. It is modeled LP net after a pool-level adverse-selection proxy on a frozen synthetic tape. Concentrated-liquidity
depth, LP shares, inventory paths, routing, gas, and demand elasticity are outside the study.

### Why is Reactive necessary if Circle settled the public trades?

Circle proves authenticated delivery. Reactive supplies the intended event-driven control plane: observing trade
requests, tracking maturity, responding to reference events and cron, retrying callbacks, acknowledging terminal
states, and requesting expiry without a MARKOUT keeper. The current public callback gap is disclosed.

### Did you backtest historical Uniswap data?

Not yet. The current work is a controlled seeded mechanism experiment designed for causal comparison because every
policy receives identical trades. Historical replay with real depth and routing is the next validation step.

### What happens if the oracle or callback network fails?

Settlement cannot invent LP protection. After the grace period, anyone can expire the trade and the entire
provisional charge becomes claimable by the trader.

## Claims to avoid

- Do not say every trader saves money.
- Do not call the synthetic tape historical backtesting.
- Do not call the proxy exact LVR or an individual LP loss.
- Do not claim Reactive's public destination callback is live.
- Do not claim MARKOUT already creates deeper liquidity or volume growth.
- Do not describe Circle and Reactive as if both supply the same orchestration role.

## Rehearsal checklist

- Keep the final recording below four minutes.
- Load one completed Fair-Flow trade before recording.
- Spend no more than 30 seconds on the architecture.
- Show one benign and one informed outcome; do not tour every UI control.
- Say the research boundary immediately after the 21.87% number.
- End on the mechanism's distinction: price realized outcomes, not predicted identities.
