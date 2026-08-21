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

Three public trades now prove both allocation extremes and independently reproduce the rebate branch through the
browser wallet console. A negative-markout trade settled through Circle in 38 seconds
with a 46-second-old Pyth observation, returned all 622 test-USDC base units to the trader, and was claimed publicly.
A positive-markout trade settled through Circle in 67 seconds with a 96-second-old observation and retained all
3,214,110,616,342 test-WETH base units in the LP-protection reserve. The wallet-console trade then settled −266.96
bps markout through a second 67-second Circle relay and claimed its full 2,041,420,186,161-unit test-WETH rebate.
Onchain balances match the accounting state.

The public lifecycle proofs use the original 30 bps base + 50 bps provisional pool. A separately tested Fair-Flow
release candidate lowers the base to 18 bps. A committed 10–30 bps sweep selects 18 as the lowest candidate that keeps
good-flow fees at or below 30 bps while retaining at least 20% modeled LP-net improvement versus fixed. It remains
undeployed and is never presented as public-chain evidence.

## Partner integration answer

Select **Reactive Network**, **Circle**, and **Pyth** if those names are present in the form's partner picker.

MARKOUT uses Pyth to verify and normalize a signed delayed reference observation on Ethereum Sepolia. Circle CCTP V2
generic messaging is the primary authenticated transport to Unichain Sepolia and has completed three public swap →
observation → attestation → settlement lifecycles. A funded legacy Reactive Network pulse is deployed and exactly
subscribed to the same publisher event as an optional second transport; because no public destination callback has
been observed, MARKOUT does not claim that Reactive delivery is live.

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
- Three public Circle settlements demonstrate both terminal economic branches and reproduce the wallet-console rebate
  flow: two 100% rebates and one 100% LP retention.

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
| Legacy Lasna | Optional Reactive pulse | `0xdd81EF6558E4D4F8403B3416c25ecD1CcB303e4e` |

## Suggested four-minute demo

1. Explain why volatility cannot identify which realized trades were harmful.
2. Replay benign, informed, and inventory-improving outcomes in the dashboard.
3. Show the seeded comparison, the 18 bps selection rule, and accounting-conservation evidence.
4. Explain Circle-primary, Reactive-optional delivery and fail-open expiry.
5. Open the three Pyth/Circle lifecycle records, including the wallet-console rebate claim.
6. Close with the measured 38/67/67-second public lifecycles and both demonstrated allocation extremes: 100% rebated
   and 100% retained for LP protection.

## Honest limitations

- Testnet prototype; not independently audited and not suitable for real funds.
- The demo uses ETH/USD as an ETH/USDC reference proxy.
- Circle uses fast-confirmed finality to fit the bounded settlement window.
- The optional Reactive pulse is deployed and subscribed, but no successful public Unichain callback is claimed.
- The LP protection reserve distribution mechanism is intentionally outside this prototype.
- The 18 + 50 bps Fair-Flow profile and sponsored-claim function are locally verified release-candidate code, not the
  already deployed 30 + 50 bps hook.

## Final owner-controlled sequence

1. Fill the owner fields and confirm the official form requirements.
2. Explicitly approve making the repository public; separately approve public dashboard access or provide a judge
   allowlist.
3. Record and upload the demo using `docs/DEMO_SCRIPT.md`.
4. Test every submitted link while logged out.
5. Create the annotated `uhi10-final` tag from the verified commit.
6. Submit the form manually and retain its confirmation receipt.
