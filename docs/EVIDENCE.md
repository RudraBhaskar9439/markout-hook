# MARKOUT Evidence Ledger

Status: four public Circle economic lifecycles and one 11-second Legacy Reactive cross-chain callback verified;
one deterministic 768-trade policy comparison and 21-point base-fee sweep reproduced locally; Reactive-first economic
settlement, liquidity response, and routing response remain unproven.

## Evidence hierarchy

MARKOUT separates facts by strength so the submission never turns a model result into a market claim.

1. **Public onchain evidence** proves that the deployed hook can escrow, mature, receive a Pyth-verified observation
   through Circle, settle both economic extremes, conserve custody, and pay a rebate. It separately proves a live
   Ethereum Sepolia → ReactVM → Unichain callback through Legacy Reactive.
2. **Controlled synthetic evidence** compares fixed, volatility-only, and MARKOUT policies against one identical
   committed trade tape. It proves properties of the declared model, not future market behavior.
3. **External research** establishes that adverse selection, fees, markout, and liquidity are economically relevant.
   It motivates the hypothesis; it does not validate MARKOUT's chosen curve.
4. **Not yet proven:** that MARKOUT attracts incremental liquidity, changes routed volume, or improves market share.
   Fair-Flow's fee-only comparison does not require those assumptions, but real all-in execution still does.

## Reactive acceptance - August 26, 2026

The [machine-readable Legacy record](../deployments/reactive-legacy-2026-08-26.json) separates three claims that are
often incorrectly collapsed:

- **Transport is live:** source transaction
  [`0x99c7…7c85`](https://sepolia.etherscan.io/tx/0x99c7110784fc9e39ff0db078be74e3995855172a4f9a8c565169373e1daa7c85)
  produced ReactVM transaction `0x00be…b0d6` and successful authenticated Unichain callback
  [`0x5d93…4459`](https://sepolia.uniscan.xyz/tx/0x5d933d5ff078c500c61fc32fef1ae526049085dad8e15ff4ef2673a971114459)
  in 11 seconds.
- **ReactVM processing is live:** a new funded pulse has the exact public publisher/market subscription and processed
  two observations for a fresh pending trade with successful ReactVM transactions `0x47c8…c03d` and `0xfa74…a960`.
- **Reactive-first economic settlement is not proven:** neither funded callback request produced a destination
  transaction before the trade expired. No Circle relay was invoked; permissionless expiry returned all 601 test-USDC
  units and the beneficiary claimed them, leaving pending escrow, claimable rebate, LP reserve, and hook balance at zero.

The successful callback targeted an already-terminal historical trade, so the coordinator correctly treated it as an
idempotent duplicate. That is strong transport evidence but not evidence that Reactive won the economic-settlement
race. The fresh acceptance attempt shows that relayer reliability remains the unresolved external dependency.

## Historical Reactive liveness recheck - August 24, 2026

MARKOUT repeated both public Reactive probes with fresh Ethereum Sepolia events. The complete machine-readable record is
[`deployments/reactive-recheck-2026-08-24.json`](../deployments/reactive-recheck-2026-08-24.json).

- The Ethereum Sepolia canary emitted request `4` in
  [transaction `0x291f…cbd4`](https://sepolia.etherscan.io/tx/0x291f015e805ef184141a82d8adb4dc9635f1a7df10afdb115d84ca212a1ecbd4).
  After 809 seconds and through Lasna Omni block `5,071,680`, the funded scheduler had emitted no fresh
  `CanaryCallbackRequested` event and the destination still reported `callbackReceived(4) == false`.
- The canonical Pyth/Circle publisher emitted a matching `ObservationPublished` event for the funded legacy MARKOUT
  pulse in [transaction `0xb925…d7ba`](https://sepolia.etherscan.io/tx/0xb925f88dd97434f32ac01a518410757603517fefb5111e63b0a12e5d38b6d7ba).
  After 473 seconds, no fresh `ObservationPulseRequested`, callback-proxy transaction, or
  `ReactiveObservationReceived` event was observable.
- Both Reactive RPCs continued producing blocks, deployed bytecode and immutable configuration remained readable, the
  hybrid public-network preflight passed, and Reactive-side service debt was zero.

This historical recheck did not support declaring the Reactive path live. The August 26 Legacy callback supersedes its
transport conclusion, while the later pending-first timeout confirms that destination relaying is still intermittent.

## Public onchain evidence

The dated [deployment manifest](../deployments/hybrid-2026-08-21.json) is machine-readable and can be rechecked with
`scripts/verify-public-circle-evidence.sh`.

| Lifecycle | Real v4 swap | Pyth publication | Circle settlement | Terminal result |
| --- | --- | --- | --- | --- |
| Rebate branch A | [swap](https://sepolia.uniscan.xyz/tx/0x41127cb3dc8c86b115cc0547c646bee192907f9d75fdc4af6f052c5110b7b90c) | [observation](https://sepolia.etherscan.io/tx/0xed6af5c42e554c221078110d6db03fba8fd74bf24a88cf52494d4e605a31f6ca) | [38-second relay](https://sepolia.uniscan.xyz/tx/0xa64789b5a08ea8aae8c2b909b6a81b495334b707eaae12610bf3749902ec532f) | 100% surcharge rebated and [claimed](https://sepolia.uniscan.xyz/tx/0xa6ded637a8c9651f252e302f7cedec2969d637f733777f7f2ad71ac700d64630) |
| Protection branch | [swap](https://sepolia.uniscan.xyz/tx/0xb6179eab5dcf9ff2f3563442dbf826fe5fcb86524e9d71aa913c9ba9e90a2376) | [observation](https://sepolia.etherscan.io/tx/0x9d20a2a8bfc5c7dd654608a9214472ff3ed37cbdff4614064aff28805f9f8861) | [67-second relay](https://sepolia.uniscan.xyz/tx/0xefeece5de9f78ae809652418e1fcd8fb592de950af64e6bbbf66df93bdc25eae) | 100% surcharge retained; reserve equals actual hook balance |
| Browser-wallet rebate | [swap](https://sepolia.uniscan.xyz/tx/0x889ea958d19574572890a5ae5a5890c7a8d31f94ebfbe9d065b58d884c1f739a) | [observation](https://sepolia.etherscan.io/tx/0x2465cd2f4e2299a1898f45d0634fc2fd87ae2412de615504fc0125d9ed204e42) | [67-second relay](https://sepolia.uniscan.xyz/tx/0x81f7878312b81b80ba69ad8fdc0f4e06f64f8624ed610ebd5a6ea63cca0ca610) | −266.96 bps markout; 100% of 2,041,420,186,161 test-WETH units [claimed](https://sepolia.uniscan.xyz/tx/0xd78f8533519c4468ac345f0caad52a8eb5c57ee904fc5882eb9066ee16b1b9d8) |
| Fair-Flow 18 bps | [swap](https://sepolia.uniscan.xyz/tx/0xf4873749b39300d5d19d28e3b0b0f43511ac907595b85d14e76c725f86f9c70f) | [observation](https://sepolia.etherscan.io/tx/0xccd8cc932276ce3233665c230d8107854b2201bca15a173b7986245c9d517221) | [55-second relay](https://sepolia.uniscan.xyz/tx/0xb1bd16c88d71fbb737cbaa20ed9002dd7bd7098d1c17ac11ab3c7f9ed01c0c4d) | 100% surcharge rebated; 18 bps final fee and [sponsored-claim entrypoint](https://sepolia.uniscan.xyz/tx/0x996ae7697b54ea67df0fbd3eb9ded1163d3a3df1d272bdcc7260ee18597b5f70) executed |

The third lifecycle is important demo evidence: it was initiated and completed through the wallet console rather than
an owner-side deployment script. Its observation was 92 seconds old when settlement mined, inside that deployed hook's
120-second freshness bound.

The first three lifecycles use the original 30 + 50 bps profile and prove both terminal branches. The separate
[Fair-Flow manifest](../deployments/fair-flow-2026-08-22.json) proves that the selected 18 + 50 bps profile is deployed,
liquid, and can complete the same Circle lifecycle at an 18 bps final fee. The original protection-branch evidence
remains the public proof for full retention.

## Controlled policy evidence

The reproducible report is [experiments/results/report.md](../experiments/results/report.md), and the separate
[adoption artifact](../experiments/results/adoption_summary.json) makes the trader objection measurable.

On the frozen 768-trade, 1,999,280 USDC tape, the Fair-Flow candidate uses an 18 bps base:

- MARKOUT improves modeled LP net-after-proxy by **850.655286 USDC**, or **21.8734%**, versus fixed 30 bps.
- MARKOUT trails the volatility baseline by **2,853.889226 USDC**, or **37.5831%**, because volatility charges benign
  and inventory-improving flow more.
- Benign flow pays **27.4262 bps**: **2.5738 USDC** less than fixed and **22.0528 USDC** less than volatility per
  10,000 USDC of notional at equal execution.
- Inventory-improving flow pays **18.0000 bps**: **12.0000 USDC** less than fixed and **29.4403 USDC** less than
  volatility per 10,000 USDC.
- Informed flow pays **61.0552 bps**, establishing a **33.6290 bps** discrimination gap from benign flow.
- MARKOUT returns **6,746.608714 USDC** in modeled rebates and credits **3,249.791286 USDC** to the modeled LP
  protection reserve.
- Sixty-three invalid references fail open to 63 full-surcharge expiries.

### Trader routing break-even

Against a fixed 30 bps pool with identical execution quality, benign Fair-Flow saves **2.5738 bps** and
inventory-improving flow saves **12.0000 bps**. Their execution-advantage threshold is therefore **0 bps**: a rational
fee-aware router can choose them without assuming deeper liquidity. Informed flow carries a **31.0552 bps** premium by
design.

Against the declared volatility policy at identical execution quality, benign and inventory-improving flow already
receive the lower modeled all-in fee. Informed flow pays more by design and is not a trader-acquisition target.

### Fair-Flow parameter selection

The machine-readable [fee sweep](../experiments/results/fair_flow_sweep.json) evaluates every integer base fee from 10
through 30 bps on the same tape. Before selection, the repository declares three constraints: benign effective fee no
greater than 30 bps, inventory-improving effective fee no greater than 30 bps, and at least 20% modeled LP-net
improvement versus fixed. Seventeen bps misses the LP constraint at 16.7325%; 18 bps is the lowest eligible candidate
at 21.8734%. The selection is therefore reproducible and falsifiable rather than discretionary.

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
- Legacy Reactive has publicly processed a canonical publisher event and completed an authenticated Unichain callback.
- Negative directional markout can produce a complete rebate; positive directional markout can produce complete LP
  retention.
- The onchain accounting conserves the provisional surcharge and fails open on missing or invalid observations.
- On the declared synthetic tape, MARKOUT discriminates by realized outcome, improves the modeled LP result versus
  fixed fees, and the Fair-Flow candidate charges good flow less than both fixed and volatility baselines.
- The next hook version exposes a permissionless sponsored-claim path that can only transfer to the recorded
  beneficiary; this is locally tested source code, not a claim about the existing deployment.

## Claims the evidence does not support

- Guaranteed LP profit, exact LVR measurement, or individual-position loss estimates.
- Guaranteed trader savings after slippage, gas, rebate delay, or routing effects in every market.
- Proven incremental liquidity, market share, or volume.
- Pair-accurate ETH/USDC production markout; the testnet uses ETH/USD as a documented proxy.
- A Reactive-first economic settlement or reliable destination relaying. The public callback targeted an already
  terminal trade, and the separate pending-first acceptance trade expired after two undelivered callback requests.

## Highest-value next experiment

Replay historical pool and external reference-market data through a concentrated-liquidity simulator with endogenous
routing and fee-sensitive demand. Sweep the surcharge cap, horizon, retention curve, and gas sponsorship policy, then
report the Pareto frontier between LP net-after-cost, benign all-in execution, routed volume, false-positive retention,
and settlement cost. The current sweep establishes fee-only economics; it does not predict live routing response.
