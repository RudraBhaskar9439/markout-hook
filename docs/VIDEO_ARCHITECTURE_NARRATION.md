# MARKOUT — full-marks four-minute video plan

## What changes from the Maestro video

Maestro's strongest score was originality (4.5/5), while presentation was the lowest score (3.5/5). The judge said
the explanation and flow were good, but the video ran over time and the architecture diagram needed to be reduced to
key points and flows. The published Maestro video is 5:48 and displays the same dense diagram for nearly its entire
runtime.

MARKOUT therefore uses seven short visual scenes, finishes around 3:50, shows working testnet evidence before technical
detail, and limits the complete architecture diagram to roughly 48 seconds.

## Recording setup

Prepare these tabs before recording:

1. Live dashboard hero: `https://markout-uhi10.rbrudra9439.chatgpt.site/`
2. Testnet console: `https://markout-uhi10.rbrudra9439.chatgpt.site/#testnet`
3. Completed Fair-Flow trade loaded in the console:
   `0x0a7e4ba34d430d4a3a8e839ddd652f40d5a7a716d7dd3e959dc33ca49acb262d`
4. Complete architecture at `docs/diagrams/MARKOUT_COMPLETE_ARCHITECTURE_4K.png`
5. Reactive section: `https://markout-uhi10.rbrudra9439.chatgpt.site/#reactive`
6. Research evidence: `https://markout-uhi10.rbrudra9439.chatgpt.site/#evidence`
7. Terminal or captured test summary showing `188 passed; 0 failed`.

Record the successful swap interaction as a separate clip before assembling the final video. The five-minute maturity
does not fit inside a four-minute submission, so show the new swap mining, then cut to the already completed and
publicly verifiable trade.

## Exact spoken script and shot list

### 0:00–0:25 — The problem

**Show:** Your face for three to five seconds, then cut to the landing page and the fixed-versus-MARKOUT comparison.

**Say:**

“Today, a benign trader and an informed arbitrageur can pay the same fee because a pool sets that fee before seeing the
outcome. Only one extracts value from stale liquidity. Volatility fees adjust to the market, yet still charge everyone.
MARKOUT asks: what if the final fee were settled after evidence of the trade’s outcome exists?”

### 0:25–0:47 — The new primitive

**Show:** Fair-Flow fee card: 18 bps base, 50 bps provisional and an 18–68 bps final range.

**Say:**

“MARKOUT is a two-stage, outcome-priced fee primitive for Uniswap v4. The pool charges an 18-basis-point base and
escrows a bounded 50-basis-point provisional amount. After five minutes, signed price evidence decides the allocation:
fair flow receives a rebate, adverse flow funds LP protection, and missing evidence produces a full provisional refund.
It evaluates outcomes, not identities.”

### 0:47–1:30 — Show that it works

**Show:** A short clip of a real testnet swap mining. Jump-cut to the completed Fair-Flow trade. Point to the five green
lifecycle steps, final 18 bps fee, returned amount and explorer links. Briefly show the protection-branch receipt.

**Say:**

“This is a real v4 swap on Unichain Sepolia, initiated through the browser wallet. The hook recorded the execution,
locked the provisional amount and created a unique trade ID. I prepared this completed trade because settlement
matures after five minutes. A signed delayed Pyth observation was published, authenticated on Unichain and finalized
exactly once. Its markout was negative, so the trader received the full provisional amount and the final fee fell to
18 basis points. A separate public lifecycle proves the opposite branch, where the provisional amount was retained
for LP protection. In total, four public cross-chain lifecycles are linked here.”

### 1:30–2:18 — Explain only the load-bearing architecture

**Show:** Complete architecture. Zoom into one region at a time: Unichain hook, Pyth, Reactive, then settlement. Do not
leave the full unreadable diagram static on screen.

**Say:**

“The architecture has one story. First, `afterSwap` records price, direction, beneficiary and maturity while the hook
escrows the provisional amount. Second, Pyth produces signed delayed price evidence.

Third is the automation core: Reactive Network. A hook cannot wake itself five minutes later. The Reactive control
plane subscribes to trade, price, terminal and cron events; tracks maturity; matches the observation; retries work; and
requests settlement or expiry without a privileged keeper.

The callback reaches the Unichain settlement gateway, where the first valid observation wins and duplicates become
no-ops. Circle CCTP is the resilience rail. Neither transport controls funds or chooses the fee; the hook validates
evidence and allocates onchain.”

### 2:18–2:43 — Demonstrate technical craft

**Show:** Terminal test summary, then the dashboard security metrics. Keep this scene under 25 seconds.

**Say:**

“This is not a frontend simulation. The hook uses the real v4 `afterSwap` lifecycle, pull-based rebates, bounded
escrow, permissionless expiry, authenticated delivery and replay-safe settlement. The repository has 188 deterministic
Solidity tests, including 12 stateful invariants, adversarial accounting tests and 17 dedicated Reactive lifecycle
tests. The committed static-analysis gate reports no medium- or high-severity findings.”

### 2:43–3:24 — Quantify the impact

**Show:** Evidence comparison. Reveal one result at a time: benign flow, improving flow, LP result and evidence boundary.

**Say:**

“I then replayed fixed-fee, volatility-only and MARKOUT policies on the same deterministic 768-trade synthetic tape,
covering six regimes and 1.999 million dollars of notional per policy. Against a fixed 30-basis-point pool, benign flow
paid 27.43 basis points on average, an 8.58 percent reduction. Inventory-improving flow paid 18 basis points, a 40
percent reduction. The modeled LP net-after-markout-loss-proxy improved by 21.87 percent, while informed flow paid a
clear premium. Markout is a directional risk proxy here, not a claim of exact realized LP loss. The experiment and
parameter sweep are committed and reproducible.”

### 3:24–3:50 — Why it matters and close

**Show:** Three outcomes, then finish on the project name and dashboard URL. Bring your face back for the final sentence.

**Say:**

“Traders can route fair flow here and finish below the fixed fee. LPs gain a reserve funded by adverse flow. Protocols
gain discrimination without identity lists or centralized fee decisions. MARKOUT is not another fee guessed at
execution. It is an autonomous, outcome-priced settlement primitive for sustainable Uniswap v4 liquidity. Charge by
outcome, not by guesswork.”

## Editing plan

| Time | Visual | Maximum continuous shot |
| --- | --- | ---: |
| 0:00–0:25 | Face → hero → comparison | 12 seconds |
| 0:25–0:47 | Fair-Flow fee mechanism | 22 seconds |
| 0:47–1:30 | Swap clip → completed lifecycle → protection receipt | 18 seconds |
| 1:30–2:18 | Architecture with four deliberate zooms | 14 seconds per zoom |
| 2:18–2:43 | Tests and security | 13 seconds |
| 2:43–3:24 | Research evidence, revealed metric by metric | 14 seconds |
| 3:24–3:50 | Outcomes → project name → face | 12 seconds |

Use simple cuts and gentle zooms. Do not use decorative transitions, an AI avatar or an AI-generated voice. Keep
captions to two lines, highlight only the number currently being discussed, and keep the cursor still unless it is
pointing to evidence.

## Rubric strategy

| Category | What the video must prove |
| --- | --- |
| Original idea | Explicitly call MARKOUT a two-stage, outcome-priced settlement primitive rather than another dynamic fee. |
| Unique execution | Show real `afterSwap`, escrow, authenticated coordinator, expiry, tests and invariants. |
| Impact | Quantify lower good-flow fees and the modeled LP improvement; explain who would route and who would LP. |
| Functionality | Show a real browser-wallet swap, completed rebate and protection lifecycles, transaction links and test output. |
| Presentation | Finish near 3:50, use your own voice, explain why before what, and never remain on one dense diagram. |

## Reactive Network judge answer

**Why is Reactive Network integral?**

“A Uniswap hook runs only when it is called; it cannot wake itself at the five-minute observation horizon. Reactive
Network is MARKOUT’s event-driven control plane: it correlates trade and price events, tracks maturity, retries work and
requests the terminal callback without a privileged keeper. Unichain remains the custody and fee authority.”

## Mandatory honesty boundary

The complete Reactive lifecycle is implemented and covered by 17 focused tests, but the latest public Lasna probe did
not produce an observable destination callback. Unless that changes before recording, say **implemented and
test-verified Reactive lifecycle** rather than **live Reactive settlement**. Public end-to-end settlement evidence comes
from the authenticated Circle resilience rail.

A sponsor-specific perfect functionality score normally requires a public callback transaction. If Reactive delivery
starts working before submission, add an eight-second proof clip showing the source event, Reactive callback and
destination transaction, replacing part of the research scene rather than making the video longer.

## Final recording checklist

- Target duration: 3:45–3:55. Never submit a cut longer than 4:00.
- Use your own voice and appear briefly at the beginning and end.
- Record at 1920×1080 or higher, 30 fps, with browser zoom around 90%.
- Hide notifications, bookmarks, wallet balances and every secret or private key.
- Use a clean microphone; remove long pauses and filler words, but keep natural breathing.
- Use large burned-in captions with a maximum of two lines.
- Do not wait five minutes on screen; use an honest jump cut to the completed trade.
- Never say “exact LP loss,” “guaranteed savings,” “MEV eliminated” or “Reactive callback is live” without evidence.
- End with the repository and live dashboard visible for at least three seconds.
