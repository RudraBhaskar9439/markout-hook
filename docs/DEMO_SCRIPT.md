# MARKOUT Judge Demo Script

This is the reliable rehearsal baseline for the hybrid build. It tells one story: similar-looking swaps can justify
different final charges once their outcomes are known.

## Before presenting

```bash
./scripts/run-phase-8-demo.sh
```

Open `http://localhost:3000`, keep benign flow selected, and reset the five-step timeline. Keep the committed Sepolia,
Circle, and Unichain explorer transactions from `deployments/hybrid-2026-08-21.json` open in a second tab.

## Core narrative — approximately four minutes

### 0:00–0:35 — The gap

“AMMs price a trade before they know whether it was actually harmful. Volatility fees can protect LPs, but they also
charge benign and inventory-improving flow. MARKOUT asks a different question: what happened after the swap?”

Fixed and volatility policies classify the environment. MARKOUT classifies the realized directional outcome.

### 0:35–1:20 — Benign outcome

Keep **Benign flow** selected.

“The hook collects a bounded provisional surcharge. After five minutes, the reference price remains near execution,
so most of that surcharge becomes a trader rebate. Under Fair-Flow, the final average is 27.43 bps—below a normal 30
bps pool. No operator chooses the result.”

Replay the lifecycle: swap, maturity, Pyth verification, authenticated delivery, allocation.

### 1:20–2:05 — Informed outcome

Select **Informed flow**.

“This trade is followed by a 22 bps move in the trader's direction. The same curve now retains more for LP protection
and returns less. MARKOUT does not blacklist a wallet or guess intent; it settles an observable outcome.”

### 2:05–2:35 — Inventory-improving outcome

Select **Inventory-improving flow**.

“When the market moves against the trader and the flow helps LP inventory, MARKOUT returns the complete provisional
surcharge. The final charge falls back to the 18 bps Fair-Flow base fee.”

### 2:35–3:20 — Research evidence

“All three policies receive one seeded 768-trade tape. A declared 10-to-30 bps sweep selects 18 bps as the lowest base
that keeps good flow at or below 30 bps while preserving at least a 20% LP advantage. Benign flow saves $2.57 and
inventory-improving flow saves $12 per $10,000 versus fixed at equal execution. MARKOUT still improves modeled LP
net-after-proxy by 21.87%, although volatility earns more by charging good flow more.”

The metric is a pool-level adverse-selection proxy, not exact LVR or individual LP profit.

### 3:20–3:45 — Reactive Network automation

“Reactive is MARKOUT's event-driven accelerator. The deployed RSC subscribes to the exact Pyth-verified publisher
event and is designed to turn it into an authenticated Unichain callback without a keeper, custody, fee authority, or
trade database. It carries only the canonical observation. Reactive and Circle race at one coordinator: first valid
delivery wins and the duplicate is harmless. This is automation without adding another trusted operator.”

Show the dedicated Reactive section: deployed pulse, funded state, exact subscription, authenticated receiver, and
race tests. Then state the boundary in one sentence: “The public destination callback has not been observed, so we do
not label Reactive live.”

### 3:45–4:00 — Public proof and close

“Circle is the proven primary route today. If either transport delivers, the same hook checks the observation; if
neither delivers, permissionless expiry returns the full surcharge. MARKOUT turns LP protection from a fear-based
prediction into outcome-based settlement.”

Clarify that the first three public lifecycles use the original 30 + 50 bps deployment, while the fourth uses the
separately deployed 18 + 50 bps Fair-Flow pool. The first live proof used a 46-second-old observation, settled in 38 seconds, and
returned 100% of the provisional surcharge. The second used a 96-second-old observation, settled in 67 seconds, and
retained 100% of its escrow for LP protection. The wallet-console lifecycle independently reproduced the rebate branch
with a 92-second-old observation and a 67-second relay, then claimed the refund. Fair-Flow completed a fourth lifecycle
in 55 seconds, finalized at 18 bps after a complete surcharge rebate, and executed the sponsored-claim entrypoint. Open the transactions and show that
onchain balances match the named accounting buckets. Show Reactive separately only if a public destination callback
exists.

## Failure-safe fallback

- If a network is slow, use the deterministic local replay and show previously verified public transactions.
- If an observation is stale or rejected, explain that expiry returns the complete provisional surcharge.
- If Reactive does not deliver, say so plainly; Circle is sufficient and Reactive is not in the critical path.
- If the hosted application is unavailable, run the same repository-owned flow locally.
- Never invent a hash or manually bypass the authenticated settlement boundary to rescue a demo.
