# MARKOUT Judge Demo Script

This is the reliable local fallback and the rehearsal baseline for the final live demo. It tells one story: two swaps
look similar at execution, but their outcomes justify different final fees.

## Before presenting

```bash
./scripts/run-phase-8-demo.sh
```

Open `http://localhost:3000`, keep the benign flow selected, and confirm that the five-step timeline is reset. Keep a
second tab ready for the final public explorer trace after the Lasna gate is complete.

## Core narrative — approximately four minutes

### 0:00–0:35 — The gap

“AMMs price the risk of a trade before they know whether that trade was actually harmful. Volatility fees can protect
LPs, but they charge benign and inventory-improving flow too. MARKOUT asks a different question: what happened after
the swap?”

Point to the fee comparison and establish that fixed and volatility policies classify the environment, while MARKOUT
classifies the realized outcome.

### 0:35–1:20 — Benign outcome

Keep **Benign flow** selected.

“The execution collects a bounded provisional surcharge. After five minutes the reference price remains near the
execution price, so most of that surcharge becomes a trader rebate. On a 10,000 USDC swap, the dashboard shows the
exact rebate and LP-protection allocation. No privileged account chooses the result.”

Replay the lifecycle once. Narrate only the state changes: swap, maturity, reference sample, settlement, acknowledgement.

### 1:20–2:05 — Informed outcome

Select **Informed flow**.

“This trade is followed by a 22 bps move in the trader’s direction. The same bounded curve now retains more for LP
protection and returns less. The mechanism is symmetric: it does not blacklist a wallet or guess intent; it settles an
observable outcome.”

Pause on the receipt so the changed allocation is visible.

### 2:05–2:35 — Inventory-improving outcome

Select **Inventory-improving flow**.

“When the market moves against the trader and the flow helps LP inventory, MARKOUT returns the full provisional
surcharge. The final fee falls back to the 30 bps base.”

### 2:35–3:20 — Evidence and honest regression

Scroll to the experiment.

“All three policies see one seeded 768-trade tape. MARKOUT improves modeled LP net-after-proxy by 3,249.79 USDC versus
the fixed fee while charging benign and inventory-improving flow less than the volatility policy. It trails that
volatility baseline by 454.75 USDC overall because the baseline charges good flow more. That is the tradeoff we wanted
to expose, not hide.”

State the metric boundary: the proxy is not exact LVR or individual LP PnL.

### 3:20–4:00 — Why Reactive and close

“Reactive Network is essential here. It waits for maturity, requests the reference sample, retries delivery, and sends
an authenticated callback. The hook keeps custody and enforces conservation. MARKOUT turns LP protection from a fear-
based prediction into an outcome-based settlement.”

For the final submission, finish on the public explorer-backed benign and informed traces. Until those exist, keep the
dashboard’s pending-evidence disclosure visible and use the local lifecycle only as a mechanism demonstration.

## Failure-safe fallback

- If the network is slow, do not wait onstage. Use the already-loaded local replay and show the public transaction tabs
  after the economic comparison.
- If an observation is stale or rejected, explain the implemented fail-open rule: expiry returns the complete
  provisional surcharge to the trader.
- If the hosted application is unavailable, run the same flow from localhost; the evidence is repository-owned and
  deterministic.
- Never manually call settlement to rescue a live demo. That would invalidate the core autonomy claim.
