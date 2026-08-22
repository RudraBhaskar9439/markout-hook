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

"The hook records execution and custody. The outcome window matures. Pyth publishes canonical evidence. Reactive is
the intended lifecycle engine: observe, wake, callback, retry, acknowledge, or expire. The hook alone validates and
allocates the escrow."

### 2:10-2:40 - Architecture + Reactive

"Frontend explains. Unichain accounts. Ethereum verifies. Reactive automates. A v4 hook cannot wake itself five
minutes later, so Reactive is essential to the no-keeper design. Circle is the publicly proven redundant delivery
rail, not a replacement for Reactive orchestration."

"The full engine has five narrow subscriptions and 17 dedicated tests. The legacy pulse is deployed, funded, and
exactly subscribed. Its public destination callback is not observed, so I disclose the boundary."

Leave the architecture after 30 seconds.

### 2:40-3:25 - Research

"I froze a deterministic 768-trade, 1.999 million dollar tape across six regimes and ran fixed, volatility, and
MARKOUT policies on identical trades. A declared 21-point fee sweep selected 18 bps as the first candidate satisfying
the trader and LP constraints."

"Under those conditions, benign fees fall 8.58%, inventory-improving fees fall 40%, and modeled LP net-after-proxy
improves 21.87% versus fixed. This is a controlled synthetic study, not historical backtesting or exact LVR."

### 3:25-3:55 - Close

"MARKOUT has 188 passing contract tests, four public Circle-completed lifecycles, both terminal economic branches, a
separate Fair-Flow pool, and zero medium or high Slither findings. MARKOUT does not guess who is toxic. It prices what
the trade actually did."

Stop.

## Failure-safe fallback

- If the network is slow, show the loaded trade and verified public receipts.
- If evidence is stale or absent, explain that permissionless expiry returns the full provisional charge.
- If Reactive does not deliver, show the implemented lifecycle tests and the public pulse/subscription, then state the
  callback boundary plainly.
- Never invent a transaction hash or bypass the authenticated settlement boundary to rescue the demo.
