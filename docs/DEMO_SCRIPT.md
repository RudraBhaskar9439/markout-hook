# MARKOUT Judge Demo Script

The detailed coaching notes, likely judge questions, and claims boundary are in
[`PRESENTATION_PLAYBOOK.md`](PRESENTATION_PLAYBOOK.md). This file is the short rehearsal card.

## Before presenting

```bash
./scripts/run-phase-8-demo.sh
```

Open `http://localhost:3000`, load a completed Fair-Flow trade, keep benign flow selected, and reset the five-step
timeline. Keep the committed public explorer receipts open in a second tab. Never wait for the five-minute maturity
window during the judged recording.

## Four-minute run

### 0:00-0:25 - Problem

"AMMs set the fee before they know whether a trade was actually harmful. MARKOUT prices the realized five-minute
outcome instead of charging everyone for predicted toxicity."

### 0:25-0:55 - Trader result

"The Fair-Flow pool starts at 18 bps and escrows a refundable 50 bps. Benign flow averages 27.43 bps,
inventory-improving flow receives the complete surcharge back, and adverse flow retains less of the rebate only after
the outcome is observable."

### 0:55-1:40 - Real testnet proof

Show the loaded receipt and its explorer links.

"This wallet submitted a real v4 swap. The hook escrowed the provisional charge, accepted a Pyth-verified
observation, finalized at 18 bps, and returned the rebate through the sponsored-claim entrypoint."

### 1:40-2:10 - Complete mechanism

Replay the timeline.

"The hook records execution and custody. The outcome window matures. Pyth verifies and publishes canonical evidence.
Reactive observes that foreign-chain event, executes in ReactVM, and requests the authenticated Unichain callback.
The hook alone validates the evidence and allocates the escrow."

### 2:10-2:40 - Architecture + Reactive

"Frontend explains. Unichain accounts. Ethereum verifies. Reactive converts the canonical publisher event into an
authenticated Unichain action without a MARKOUT-owned cross-chain relayer. Circle is an independent delivery rail,
and the coordinator makes the first valid delivery win."

"The Legacy pulse is deployed, funded, and exactly subscribed. A public publisher event completed its authenticated
Unichain callback in 11 seconds. A pending-first follow-up reached ReactVM twice but the destination relayer timed out,
so the trade safely expired to a full refund."

Leave the architecture after 30 seconds.

### 2:40-3:25 - Research

"I froze a deterministic 768-trade, 1.999 million dollar tape across six regimes and ran fixed, volatility, and
MARKOUT policies on identical trades. A declared 21-point fee sweep selected 18 bps as the first candidate satisfying
the trader and LP constraints."

"Under those conditions, benign fees fall 8.58%, inventory-improving fees fall 40%, and modeled LP net-after-proxy
improves 21.87% versus fixed. This is a controlled synthetic study, not historical backtesting or exact LVR."

"I then froze a separate Ethereum mainnet window with 251 eligible Uniswap swaps. The directional hypothesis
survived: favorable outcomes averaged 18 bps, near-zero outcomes 29.02, and adverse outcomes 39.14. Aggregate LP net
was 0.39% below fixed in that short window, so I report the negative result instead of generalizing the synthetic one."

### 3:25-3:55 - Close

"MARKOUT defines 202 Solidity test functions and 12 stateful invariant entrypoints, has four public fallback-completed
lifecycles, both terminal economic branches, a separate Fair-Flow pool, and zero medium or high Slither findings.
MARKOUT does not guess who is toxic. It prices what the trade actually did."

Stop.

## Failure-safe fallback

- If the network is slow, show the loaded trade and verified public receipts.
- If evidence is stale or absent, explain that permissionless expiry returns the full provisional charge.
- If a fresh Reactive delivery is unavailable during recording, show the public 11-second callback, the deployed
  pulse/subscription, and the implemented lifecycle tests, then state the Reactive-first settlement boundary plainly.
- Never invent a transaction hash or bypass the authenticated settlement boundary to rescue the demo.
