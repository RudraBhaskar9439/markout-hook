# MARKOUT — four-minute demo script

This script is designed for one continuous four-minute submission video. The architecture diagram is the visual spine:
move through it from left to right, then reveal the three outcomes and the research evidence at the bottom.

## Before recording

1. Open the live dashboard on the landing section.
2. Keep the testnet console open in a second tab with the completed Fair-Flow trade loaded:
   `0x0a7e4ba34d430d4a3a8e839ddd652f40d5a7a716d7dd3e959dc33ca49acb262d`.
3. Open `docs/diagrams/MARKOUT_COMPLETE_ARCHITECTURE_4K.png` at fit-to-screen.
4. Keep the Evidence section ready with the four public lifecycle links and the research comparison.
5. Record at 1080p or higher. Keep browser zoom between 90% and 100%, notifications off, and wallet addresses hidden
   unless they are part of the proof.

## Exact narration and screen direction

### 0:00–0:26 — Hook

**Show:** Landing page. Keep the project name and one-line mechanism visible.

**Say:**

“A normal AMM charges a trade before it knows whether that trade helped the pool or extracted value from it. That means
fair traders can subsidize toxic flow, while liquidity providers still absorb adverse selection. MARKOUT changes the
timing of that decision. It is a Uniswap v4 hook that charges by the observed outcome of a trade, not by guesswork at
execution.”

### 0:26–0:51 — Mechanism in one sentence

**Show:** Testnet console. Point to the 18 bps base fee and 50 bps provisional amount, then the completed 18 bps result.

**Say:**

“On the Fair-Flow pool, every swap pays an 18-basis-point base fee and temporarily escrows a bounded 50-basis-point
provisional amount. Five minutes later, MARKOUT compares the execution price with a signed delayed reference price.
Fair or inventory-improving flow receives a rebate. Adverse flow contributes more to LP protection. The final fee is
always bounded between 18 and 68 basis points.”

### 0:51–2:26 — Architecture story

**Show:** Full architecture diagram. Begin at the frontend, then follow numbered stages 1 through 5. Pause longest on
the separate blue Reactive Network control plane before returning to the Unichain settlement gateway.

**Say:**

“Here is the complete lifecycle.

Step one: the trader submits a real Uniswap v4 swap on Unichain. The frontend is only an interface; it never supplies
the settlement price.

Step two: the hook records the execution price, direction, beneficiary, unique trade ID, and a five-minute maturity.
It escrows the provisional amount and emits a MarkoutRequested event.

Step three: after maturity, Pyth provides the signed reference price on Ethereum, including publish time and
confidence, so the observation can be checked against the exact trade.

Step four is the automation core: Reactive Network. A Uniswap hook cannot wake itself five minutes later, and relying
on my server would introduce a privileged keeper. MARKOUT’s Reactive control plane subscribes to both trade and price
events, persists every pending lifecycle, wakes when the observation horizon is reached, matches the right signed
price to the right trade, retries incomplete work, and triggers the authenticated destination callback. This is what
turns delayed markout from an offchain analytics idea into autonomous protocol behavior.

Circle CCTP is a separate resilience rail carrying the same authenticated observation. Both paths converge on one
immutable coordinator, so the first valid message settles and duplicates become safe no-ops.

Step five: Unichain remains the settlement authority. The contracts authenticate the delivery, validate time,
confidence, market and solvency, compute directional markout, and finalize exactly once. Neither transport holds user
funds or decides the fee.”

### 2:26–2:54 — Three safe outcomes

**Show:** Move the cursor across Fair Flow, Adverse Flow, and No Valid Price.

**Say:**

“That lifecycle has three safe endings. For fair or inventory-improving flow, the provisional amount is refunded and
the effective fee can fall to 18 basis points. For adverse flow, part or all of it moves to the LP protection reserve.
And if no valid observation arrives, anyone can expire the trade and the provisional amount remains fully refundable.
So automation failure cannot silently confiscate the trader’s escrow.”

### 2:54–3:19 — Public demo evidence

**Show:** Return to the completed Fair-Flow trade in the console. Point to the five completed lifecycle steps, the
negative directional markout, 18 bps effective fee, and explorer links.

**Say:**

“This is a completed Fair-Flow testnet lifecycle. A real v4 swap created the escrow, a signed delayed Pyth observation
was published, the cross-chain message was authenticated on Unichain, and the full provisional amount was returned,
leaving an 18-basis-point final fee. Across the project, four public end-to-end lifecycles prove the rebate branch, the
LP-protection branch, browser-wallet execution, and the separate 18-basis-point deployment.”

### 3:19–3:49 — Research evidence

**Show:** Research strip at the bottom of the diagram or the Evidence comparison table.

**Say:**

“I also replayed fixed-fee, volatility-only, and MARKOUT policies on the same deterministic 768-trade synthetic tape,
covering six market regimes and 1.999 million dollars of notional per policy. Against fixed 30 basis points, MARKOUT
reduced the average benign-flow fee by 8.58 percent, reduced inventory-improving fees by 40 percent, and improved
modeled LP net-after-markout-loss-proxy by 21.87 percent. Markout is a directional risk proxy here, not a claim of exact
realized LP loss.”

### 3:49–4:00 — Close

**Show:** Project name plus the Reactive Network block, then end on the live dashboard URL.

**Say:**

“MARKOUT gives Uniswap v4 an autonomous, outcome-priced fee lifecycle: cheaper fair flow, funded LP protection, and
safe settlement driven by Reactive Network. Charge by outcome, not by guesswork.”

## Delivery notes

- Speak at roughly 145 words per minute; the 581-word spoken copy is approximately four minutes with natural pauses.
- Do not wait five minutes during the recording. Load the completed Fair-Flow trade and narrate its verified lifecycle.
- Spend roughly 35 seconds on the Reactive block. It is the architectural answer to “who wakes the hook later?”
- Say **directional markout proxy**, not “exact LP loss” or “MEV eliminated.”
- Say **implemented and test-verified Reactive lifecycle**. If asked about public liveness, state that the current Lasna
  callback was not observed during the latest probe and the authenticated Circle resilience rail supplied the public
  end-to-end settlement evidence. This preserves credibility without weakening Reactive’s architectural role.

## One-line judge answers

**Why would a trader use this pool?**

“On the controlled tape, benign flow paid 27.43 bps on average and inventory-improving flow paid 18 bps, versus 30 bps
in the fixed pool, while the maximum fee remained capped.”

**Why is Reactive Network integral?**

“The hook cannot wake itself after five minutes; Reactive Network owns the event-driven lifecycle that correlates the
trade with delayed evidence and autonomously triggers terminal settlement without a privileged keeper.”

**Who controls the money and fee decision?**

“Unichain contracts do: Reactive orchestrates, while the hook authenticates evidence, computes the allocation, and
holds the accounting authority.”

**What is proven?**

“Four public Unichain/Pyth cross-chain settlements, 188 Solidity tests with 12 stateful invariants, and one reproducible
768-trade synthetic policy comparison.”
