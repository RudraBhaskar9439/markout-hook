# MARKOUT Final Submission Draft

This document is the copy-ready source for the final UHI10 form at `https://tally.so/r/mVNEAE`. Everything backed by
code or public testnet evidence is complete. Replace only the explicitly marked owner fields, add the uploaded demo
URL, and use the exact requirements and deadline shown in the official invitation or submission form. Nothing in this
repository fills or submits the form.

## Owner fields

- **MARKOUT Project ID:** `[REQUIRED FROM UHI IDEA-SUBMISSION EMAIL]`
- **UHI registration email:** `[REQUIRED]`
- **Every team member's X handle:** `[REQUIRED FOR PRIZE AND PRESENTER POSTS]`
- **Original UHI cohort:** `[REQUIRED; CONFIRM WHETHER UHI9 IS CORRECT]`
- **Team members:** `[REQUIRED; USE SOLO IF APPLICABLE]`
- **Official presentation limit:** `[REQUIRED FROM ORGANIZER]`
- **Final demo URL:** `[REQUIRED AFTER UPLOAD]`
- **UHI experience rating and feedback:** `[REQUIRED PERSONAL RESPONSE]`

## Project

**Name:** MARKOUT

**Submission type:** Select the option corresponding to a Uniswap v4 hook.

**Theme:** Select **Yes, my project addresses the theme.**

**Tags:** `MEV Protection`, `Sustainable Liquidity`, `Fee Rebates`, `Dynamic Fees`, `LP Protection`,
`Adverse Selection`, `Cross-chain Messaging`, `Oracle`, `Uniswap v4`

**Thumbnail:** Upload `web/public/og-evidence-v2.png` (1200 × 630).

**One sentence:** MARKOUT is a Uniswap v4 hook that collects a bounded provisional surcharge and allocates it only
after a delayed, authenticated price observation reveals whether the trade was adverse or beneficial to liquidity
providers.

**Submission description:**

AMMs normally price a trade before they know whether its order flow was harmful. Volatility fees can protect liquidity
providers, but they also charge benign and inventory-improving flow. MARKOUT instead escrows a bounded provisional
surcharge, waits for a configured markout horizon, and settles the charge from signed directional evidence. Pyth
verifies the delayed reference price. Circle CCTP V2 carries the primary authenticated observation from Ethereum
Sepolia to Unichain Sepolia. An optional stateless Reactive contract can mirror the same observation, while an
immutable coordinator ensures the first valid delivery wins and later duplicates are harmless. If no valid observation
arrives, permissionless expiry returns the full surcharge.

Four public trades now prove both allocation extremes and independently reproduce the rebate branch through the
browser wallet console. A negative-markout trade settled through Circle in 38 seconds
with a 46-second-old Pyth observation, returned all 622 test-USDC base units to the trader, and was claimed publicly.
A positive-markout trade settled through Circle in 67 seconds with a 96-second-old observation and retained all
3,214,110,616,342 test-WETH base units in the LP-protection reserve. The wallet-console trade then settled −266.96
bps markout through a second 67-second Circle relay and claimed its full 2,041,420,186,161-unit test-WETH rebate. A
separate Fair-Flow pool then settled in 55 seconds, returned its full provisional surcharge, finalized at 18 bps, and
executed the deployed sponsored-claim entrypoint. Onchain balances match the accounting state.

The first three public lifecycle proofs use the original 30 bps base + 50 bps provisional pool. The separately
deployed Fair-Flow pool lowers the base to 18 bps. A committed 10–30 bps sweep selects 18 as the lowest candidate that
keeps good-flow fees at or below 30 bps while retaining at least 20% modeled LP-net improvement versus fixed.

## Partner integration answer

Select **Reactive Network**, **Circle**, and **Pyth** if those names are present in the form's partner picker.

MARKOUT's Reactive integration is an event-driven settlement accelerator, not a logo-level dependency. A funded,
debt-free legacy RSC is deployed with an exact subscription to the canonical Pyth-verified publisher event. When that
event is observed, the pulse is designed to forward only `(marketId, tradeId, priceX18, observedAt, confidenceBps)`
through a callback-proxy- and RVM-authenticated Unichain receiver. It owns no custody, oracle, scheduler database,
fee authority, recipient choice, or upgrade surface.

Reactive races Circle at one immutable coordinator: the first valid observation settles and the second becomes a
successful no-op, so Reactive can improve liveness without becoming a safety dependency. Tests prove Circle-first and
Reactive-first equivalence, malformed callback rejection, and zero effect on the expiry guarantee. The pulse
deployment and subscription are public. Because the live relayer has not produced a public Unichain callback,
MARKOUT labels `reactiveLive` false rather than overstating sponsor evidence. Circle CCTP V2 remains the primary proven
transport and has completed four public end-to-end lifecycles.

## Exact long-form answers

### Problem / background

AMMs must set fees before they know whether a swap was ordinary flow or informed flow that will be followed by a
favorable market move for the trader. Volatility-linked fees can protect LPs, but they price the market regime rather
than the realized outcome, so benign and inventory-improving users can pay more alongside toxic flow. MARKOUT tests a
different mechanism: escrow only a bounded provisional surcharge, wait for a fixed post-trade horizon, and use
directional markout as an adverse-selection proxy to determine how much becomes a trader rebate versus LP protection.

### Impact

MARKOUT turns protection from an ex-ante prediction into an ex-post, conserved settlement. It neither blacklists
wallets nor claims to measure exact LVR or individual LP profit. Every provisional unit ends in a named bucket;
invalid or missing observations fail open to a full rebate after expiry; and two authenticated transports can race
without changing the first terminal outcome. On one reproducible 768-trade tape, the 18 bps Fair-Flow profile improves
modeled LP net-after-proxy by 850.66 USDC, or 21.87%, versus a fixed 30 bps fee. At identical execution quality, benign
flow saves 2.5738 USDC and inventory-improving flow saves 12 USDC per 10,000 USDC versus fixed; those savings rise to
22.0528 and 29.4403 USDC versus the declared volatility policy. The documented regression is that volatility earns
2,853.89 USDC more overall by charging good flow more. Incremental liquidity and routing response remain hypotheses,
not claimed results.

### Challenges

The hardest work was preserving Uniswap v4 delta accounting while escrowing a provisional surcharge, normalizing a
fresh signed Pyth price inside a short settlement window, and authenticating asynchronous delivery without giving a
relayer economic authority. Reactive Network's public callback path did not deliver during bounded acceptance tests,
so the architecture was reduced to a Circle-primary, Reactive-optional topology behind an immutable coordinator. A
stale first observation and a Pyth endpoint/contract migration mismatch were both rejected safely; the final direct
relay completed inside the freshness bound. Those failures became explicit threat-model and runbook evidence instead
of being hidden.

## Why it is different

- Prices realized directional outcomes instead of charging the entire market for volatility.
- Makes benign and inventory-improving flow cheaper than a fixed 30 bps pool in the declared Fair-Flow profile.
- Keeps custody, maturity validation, settlement mathematics, and fail-open expiry inside the hook boundary.
- Uses Circle as the reliable primary transport while preserving Reactive as an optional accelerator.
- Makes at-least-once delivery safe through immutable authentication and idempotent terminal settlement.
- Reports the research metric honestly as an adverse-selection proxy, not exact LVR or individual LP profit.

## Reproducible evidence

- 188 deterministic Solidity tests with zero failures or skips.
- 12 stateful invariants.
- Zero medium/high Slither findings.
- One seeded 768-trade experiment shared by fixed, volatility, and MARKOUT policies.
- Fair-Flow improves modeled LP net-after-proxy by 850.66 USDC versus the fixed policy.
- Fair-Flow trails the volatility policy by 2,853.89 USDC overall because volatility charges good flow more.
- The LP net-after-proxy improvement versus fixed is 21.8734% on the declared tape.
- Benign flow saves 2.5738 USDC per 10,000 USDC versus fixed and 22.0528 USDC versus volatility at equal execution.
- Inventory-improving flow saves 12 USDC per 10,000 USDC versus fixed and 29.4403 USDC versus volatility.
- A 21-point parameter sweep selects 18 bps as the lowest base satisfying the declared good-flow and LP constraints.
- Four public Circle settlements demonstrate both terminal economic branches and the deployed Fair-Flow profile:
  three 100% rebates and one 100% LP retention.

## Public deployment

| Evidence | Public link |
| --- | --- |
| Rebate-branch Pyth publication | https://sepolia.etherscan.io/tx/0xed6af5c42e554c221078110d6db03fba8fd74bf24a88cf52494d4e605a31f6ca |
| Rebate-branch Circle settlement | https://sepolia.uniscan.xyz/tx/0xa64789b5a08ea8aae8c2b909b6a81b495334b707eaae12610bf3749902ec532f |
| Rebate claim | https://sepolia.uniscan.xyz/tx/0xa6ded637a8c9651f252e302f7cedec2969d637f733777f7f2ad71ac700d64630 |
| Idempotent later delivery | https://sepolia.uniscan.xyz/tx/0x06ef5334210274dd451b5465f34d108d1714cf5536ee9ae1998193450114fa76 |
| Protection-branch Uniswap v4 swap | https://sepolia.uniscan.xyz/tx/0xb6179eab5dcf9ff2f3563442dbf826fe5fcb86524e9d71aa913c9ba9e90a2376 |
| Protection-branch Pyth publication | https://sepolia.etherscan.io/tx/0x9d20a2a8bfc5c7dd654608a9214472ff3ed37cbdff4614064aff28805f9f8861 |
| Protection-branch Circle settlement | https://sepolia.uniscan.xyz/tx/0xefeece5de9f78ae809652418e1fcd8fb592de950af64e6bbbf66df93bdc25eae |
| Wallet-console v4 swap | https://sepolia.uniscan.xyz/tx/0x889ea958d19574572890a5ae5a5890c7a8d31f94ebfbe9d065b58d884c1f739a |
| Wallet-console Pyth publication | https://sepolia.etherscan.io/tx/0x2465cd2f4e2299a1898f45d0634fc2fd87ae2412de615504fc0125d9ed204e42 |
| Wallet-console Circle settlement | https://sepolia.uniscan.xyz/tx/0x81f7878312b81b80ba69ad8fdc0f4e06f64f8624ed610ebd5a6ea63cca0ca610 |
| Wallet-console rebate claim | https://sepolia.uniscan.xyz/tx/0xd78f8533519c4468ac345f0caad52a8eb5c57ee904fc5882eb9066ee16b1b9d8 |
| Fair-Flow 18 bps pool initialization | https://sepolia.uniscan.xyz/tx/0xf96119129f7bb91fe9331725a5ba2c4aabaa8ebeec17042d1c3ef15f95a4cba9 |
| Fair-Flow v4 swap | https://sepolia.uniscan.xyz/tx/0xf4873749b39300d5d19d28e3b0b0f43511ac907595b85d14e76c725f86f9c70f |
| Fair-Flow Pyth publication | https://sepolia.etherscan.io/tx/0xccd8cc932276ce3233665c230d8107854b2201bca15a173b7986245c9d517221 |
| Fair-Flow Circle settlement | https://sepolia.uniscan.xyz/tx/0xb1bd16c88d71fbb737cbaa20ed9002dd7bd7098d1c17ac11ab3c7f9ed01c0c4d |
| Fair-Flow sponsored-claim entrypoint | https://sepolia.uniscan.xyz/tx/0x996ae7697b54ea67df0fbd3eb9ded1163d3a3df1d272bdcc7260ee18597b5f70 |
| Hosted judge dashboard | https://markout-uhi10.rbrudra9439.chatgpt.site |
| GitHub repository | https://github.com/RudraBhaskar9439/markout-hook |

The repository and dashboard remain owner-controlled until public or judge-specific access is explicitly approved.
The final form requires the GitHub repository to be public before its confirmation can truthfully be selected.

## Deployed contracts

| Network | Contract | Address |
| --- | --- | --- |
| Ethereum Sepolia | Pyth/Circle observation publisher | `0xb3d2403a028849292326668ab41ed25f0f049976` |
| Unichain Sepolia | Settlement coordinator | `0x282a2ed0eaf48e52e7844de40a1faf6f13445dc0` |
| Unichain Sepolia | Circle receiver | `0x88d2384a2bddffb26936d4b05b55d530709e534b` |
| Unichain Sepolia | MARKOUT hook | `0x2981693161ebbeaf10e91d6ddfc2ed810e80c044` |
| Ethereum Sepolia | Fair-Flow Pyth/Circle publisher | `0xeeb18d96AABcec142D95Ba2b9E7E3221832Cf139` |
| Unichain Sepolia | Fair-Flow settlement coordinator | `0x7BC38f019D5F3000c15C9E5309dFB1e7f361cb6e` |
| Unichain Sepolia | Fair-Flow Circle receiver | `0x24858E73A18f1A4537897DD2d04417a7a24b8f68` |
| Unichain Sepolia | Fair-Flow MARKOUT hook | `0x3A17354331C21B246A9eC9BF979Af77e64f30044` |
| Legacy Lasna | Optional Reactive pulse | `0xdd81EF6558E4D4F8403B3416c25ecD1CcB303e4e` |

## Suggested four-minute demo

1. Explain why volatility cannot identify which realized trades were harmful.
2. Replay benign, informed, and inventory-improving outcomes in the dashboard.
3. Show the seeded comparison, the 18 bps selection rule, and accounting-conservation evidence.
4. Explain Circle-primary, Reactive-optional delivery and fail-open expiry.
5. Open the four Pyth/Circle lifecycle records, including the Fair-Flow 18 bps settlement and claim.
6. Close with the measured 38/67/67/55-second public lifecycles and both demonstrated allocation extremes: 100%
   rebated and 100% retained for LP protection.

## Honest limitations

- Testnet prototype; not independently audited and not suitable for real funds.
- The demo uses ETH/USD as an ETH/USDC reference proxy.
- Circle uses fast-confirmed finality to fit the bounded settlement window.
- The optional Reactive pulse is deployed and subscribed, but no successful public Unichain callback is claimed.
- The LP protection reserve distribution mechanism is intentionally outside this prototype.
- The Fair-Flow pool has one public complete-rebate lifecycle; the original pool remains the public proof for the
  full-retention branch.

## Final owner-controlled sequence

1. Fill the owner fields and confirm the official form requirements.
2. Explicitly approve making the repository public; separately approve public dashboard access or provide a judge
   allowlist.
3. Record and upload the demo using `docs/DEMO_SCRIPT.md`.
4. Test every submitted link while logged out.
5. Create the annotated `uhi10-final` tag from the verified commit.
6. Submit the form manually and retain its confirmation receipt.
