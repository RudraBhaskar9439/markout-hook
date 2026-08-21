# MARKOUT Evidence Ledger

Status: three public Circle-primary lifecycles verified on August 21, 2026; one deterministic 768-trade policy
comparison reproduced locally; liquidity and routing response remain an unproven adoption hypothesis.

## Evidence hierarchy

MARKOUT separates facts by strength so the submission never turns a model result into a market claim.

1. **Public onchain evidence** proves that the deployed hook can escrow, mature, receive a Pyth-verified observation
   through Circle, settle both economic extremes, conserve custody, and pay a rebate.
2. **Controlled synthetic evidence** compares fixed, volatility-only, and MARKOUT policies against one identical
   committed trade tape. It proves properties of the declared model, not future market behavior.
3. **External research** establishes that adverse selection, fees, markout, and liquidity are economically relevant.
   It motivates the hypothesis; it does not validate MARKOUT's chosen curve.
4. **Not yet proven:** that MARKOUT attracts enough incremental liquidity or improves execution enough to beat a
   same-liquidity fixed 30 bps pool for benign traders.

## Public onchain evidence

The dated [deployment manifest](../deployments/hybrid-2026-08-21.json) is machine-readable and can be rechecked with
`scripts/verify-public-circle-evidence.sh`.

| Lifecycle | Real v4 swap | Pyth publication | Circle settlement | Terminal result |
| --- | --- | --- | --- | --- |
| Rebate branch A | [swap](https://sepolia.uniscan.xyz/tx/0x41127cb3dc8c86b115cc0547c646bee192907f9d75fdc4af6f052c5110b7b90c) | [observation](https://sepolia.etherscan.io/tx/0xed6af5c42e554c221078110d6db03fba8fd74bf24a88cf52494d4e605a31f6ca) | [38-second relay](https://sepolia.uniscan.xyz/tx/0xa64789b5a08ea8aae8c2b909b6a81b495334b707eaae12610bf3749902ec532f) | 100% surcharge rebated and [claimed](https://sepolia.uniscan.xyz/tx/0xa6ded637a8c9651f252e302f7cedec2969d637f733777f7f2ad71ac700d64630) |
| Protection branch | [swap](https://sepolia.uniscan.xyz/tx/0xb6179eab5dcf9ff2f3563442dbf826fe5fcb86524e9d71aa913c9ba9e90a2376) | [observation](https://sepolia.etherscan.io/tx/0x9d20a2a8bfc5c7dd654608a9214472ff3ed37cbdff4614064aff28805f9f8861) | [67-second relay](https://sepolia.uniscan.xyz/tx/0xefeece5de9f78ae809652418e1fcd8fb592de950af64e6bbbf66df93bdc25eae) | 100% surcharge retained; reserve equals actual hook balance |
| Browser-wallet rebate | [swap](https://sepolia.uniscan.xyz/tx/0x889ea958d19574572890a5ae5a5890c7a8d31f94ebfbe9d065b58d884c1f739a) | [observation](https://sepolia.etherscan.io/tx/0x2465cd2f4e2299a1898f45d0634fc2fd87ae2412de615504fc0125d9ed204e42) | [67-second relay](https://sepolia.uniscan.xyz/tx/0x81f7878312b81b80ba69ad8fdc0f4e06f64f8624ed610ebd5a6ea63cca0ca610) | −266.96 bps markout; 100% of 2,041,420,186,161 test-WETH units [claimed](https://sepolia.uniscan.xyz/tx/0xd78f8533519c4468ac345f0caad52a8eb5c57ee904fc5882eb9066ee16b1b9d8) |

The third lifecycle is important demo evidence: it was initiated and completed through the wallet console rather than
an owner-side deployment script. Its observation was 92 seconds old when settlement mined, inside the hook's
120-second freshness bound.

## Controlled policy evidence

The reproducible report is [experiments/results/report.md](../experiments/results/report.md), and the separate
[adoption artifact](../experiments/results/adoption_summary.json) makes the trader objection measurable.

On the frozen 768-trade, 1,999,280 USDC tape:

- MARKOUT improves modeled LP net-after-proxy by **3,249.791286 USDC**, or **83.5638%**, versus fixed 30 bps.
- MARKOUT trails the volatility baseline by **454.753226 USDC**, or **5.9887%**, because volatility charges benign
  and inventory-improving flow more.
- Benign flow pays **39.4262 bps** under MARKOUT versus **49.4790 bps** under volatility: a **10.0528 USDC** saving
  per 10,000 USDC of notional.
- Inventory-improving flow pays **30.0000 bps** versus **47.4403 bps** under volatility: a **17.4403 USDC** saving
  per 10,000 USDC.
- Informed flow pays **73.0552 bps**, establishing a **33.6290 bps** discrimination gap from benign flow.
- MARKOUT returns **6,746.608714 USDC** in modeled rebates and credits **3,249.791286 USDC** to the modeled LP
  protection reserve.
- Sixty-three invalid references fail open to 63 full-surcharge expiries.

### Trader routing break-even

Against a fixed 30 bps pool with identical execution quality, benign MARKOUT flow carries a **9.4262 bps** fee
premium. A rational router chooses MARKOUT only if its better price or lower slippage exceeds that premium. For
inventory-improving flow the threshold is **0 bps**. This repository does not claim the required depth improvement has
already happened.

Against the declared volatility policy at identical execution quality, benign and inventory-improving flow already
receive the lower modeled all-in fee. Informed flow pays more by design and is not a trader-acquisition target.

## External research basis

- Milionis, Moallemi, Roughgarden, and Zhang formalize LVR as the adverse-selection cost created when better-informed
  arbitrageurs trade against stale AMM prices: [Automated Market Making and Loss-Versus-Rebalancing](https://arxiv.org/abs/2208.06046).
- Campbell, Bergault, Milionis, and Nutz identify the central fee trade-off: fees must remain low enough to attract
  volume while high enough to compensate LPs and mitigate arbitrage losses: [Optimal Fees for Liquidity Provision in
  Automated Market Makers](https://arxiv.org/abs/2508.08152).
- Caparros, Chaudhary, and Klein find empirically that volatility, fee revenue, and markout affect Uniswap liquidity
  through both total value and liquidity concentration: [What Drives Liquidity on Decentralized Exchanges?](https://arxiv.org/abs/2410.19107).
- Uniswap's official v4 documentation names order-flow discrimination, LP-return improvement, and cross-pool
  arbitrage mitigation as dynamic-fee use cases, while warning that optimal fees depend on volatility and uninformed
  volume: [Dynamic Fees](https://developers.uniswap.org/docs/protocols/v4/concepts/dynamic-fees).
- A 2026 concentrated-liquidity agent-based study finds dynamic fee rules improve hedged LP profitability primarily
  through compensation rather than removal of LVR. MARKOUT therefore claims **LP protection funding**, not MEV
  prevention: [Mitigating Adverse Selection in Concentrated Liquidity AMMs with Dynamic Fees](https://arxiv.org/abs/2606.23070).

## Claims the evidence supports

- The deployed hook settles real Uniswap v4 swaps from authenticated delayed observations.
- Negative directional markout can produce a complete rebate; positive directional markout can produce complete LP
  retention.
- The onchain accounting conserves the provisional surcharge and fails open on missing or invalid observations.
- On the declared synthetic tape, MARKOUT discriminates by realized outcome, improves the modeled LP result versus
  fixed fees, and charges good flow less than the declared volatility baseline.

## Claims the evidence does not support

- Guaranteed LP profit, exact LVR measurement, or individual-position loss estimates.
- Guaranteed trader savings versus every fixed-fee pool.
- Proven incremental liquidity, market share, or volume.
- Pair-accurate ETH/USDC production markout; the testnet uses ETH/USD as a documented proxy.
- A live Reactive destination callback. Reactive remains optional until a public callback is observed.

## Highest-value next experiment

Replay historical pool and external reference-market data through a concentrated-liquidity simulator with endogenous
routing. Sweep the base fee, surcharge cap, horizon, and retention curve, then report the Pareto frontier between LP
net-after-cost, benign all-in execution, routed volume, false-positive retention, and settlement cost. Until that work
exists, the 9.4262 bps benign break-even is the honest adoption threshold.
