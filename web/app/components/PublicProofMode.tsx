"use client";

import { useState } from "react";

type ProofId = "fair-flow" | "protection" | "wallet-rebate" | "reactive";

type ProofPath = {
  id: ProofId;
  eyebrow: string;
  title: string;
  summary: string;
  status: string;
  tone: "green" | "amber" | "blue";
  metrics: { value: string; label: string }[];
  receipts: { label: string; href: string }[];
  boundary: string;
};

const proofPaths: ProofPath[] = [
  {
    id: "fair-flow",
    eyebrow: "Current Fair-Flow pool",
    title: "18 bps complete rebate",
    summary: "A real Uniswap v4 swap matured, received a Pyth observation, finalized at the base fee, and executed the sponsored claim path.",
    status: "Economic lifecycle verified",
    tone: "green",
    metrics: [
      { value: "18 bps", label: "final fee" },
      { value: "100%", label: "surcharge rebated" },
      { value: "55s", label: "fallback relay" },
    ],
    receipts: [
      { label: "Swap", href: "https://sepolia.uniscan.xyz/tx/0xf4873749b39300d5d19d28e3b0b0f43511ac907595b85d14e76c725f86f9c70f" },
      { label: "Observation", href: "https://sepolia.etherscan.io/tx/0xccd8cc932276ce3233665c230d8107854b2201bca15a173b7986245c9d517221" },
      { label: "Settlement", href: "https://sepolia.uniscan.xyz/tx/0xb1bd16c88d71fbb737cbaa20ed9002dd7bd7098d1c17ac11ab3c7f9ed01c0c4d" },
      { label: "Claim", href: "https://sepolia.uniscan.xyz/tx/0x996ae7697b54ea67df0fbd3eb9ded1163d3a3df1d272bdcc7260ee18597b5f70" },
    ],
    boundary: "This is the deployed 18 + 50 bps Fair-Flow profile and its full-rebate terminal branch.",
  },
  {
    id: "protection",
    eyebrow: "Original public pool",
    title: "100% LP protection retention",
    summary: "A positive directional markout retained the complete provisional amount and moved it into the hook's LP protection reserve.",
    status: "Opposite economic extreme verified",
    tone: "amber",
    metrics: [
      { value: "80 bps", label: "original profile final" },
      { value: "100%", label: "surcharge retained" },
      { value: "67s", label: "fallback relay" },
    ],
    receipts: [
      { label: "Swap", href: "https://sepolia.uniscan.xyz/tx/0xb6179eab5dcf9ff2f3563442dbf826fe5fcb86524e9d71aa913c9ba9e90a2376" },
      { label: "Observation", href: "https://sepolia.etherscan.io/tx/0x9d20a2a8bfc5c7dd654608a9214472ff3ed37cbdff4614064aff28805f9f8861" },
      { label: "Settlement", href: "https://sepolia.uniscan.xyz/tx/0xefeece5de9f78ae809652418e1fcd8fb592de950af64e6bbbf66df93bdc25eae" },
    ],
    boundary: "This receipt uses the earlier 30 + 50 bps deployment to prove the full-retention branch publicly.",
  },
  {
    id: "wallet-rebate",
    eyebrow: "Browser-wallet lifecycle",
    title: "Rebate claimed by the trader",
    summary: "A wallet-executed trade produced a strongly negative directional markout, received the full provisional rebate, and claimed it on Unichain.",
    status: "Wallet claim verified",
    tone: "green",
    metrics: [
      { value: "-266.96", label: "markout bps" },
      { value: "100%", label: "surcharge rebated" },
      { value: "Claimed", label: "wallet outcome" },
    ],
    receipts: [
      { label: "Swap", href: "https://sepolia.uniscan.xyz/tx/0x889ea958d19574572890a5ae5a5890c7a8d31f94ebfbe9d065b58d884c1f739a" },
      { label: "Observation", href: "https://sepolia.etherscan.io/tx/0x2465cd2f4e2299a1898f45d0634fc2fd87ae2412de615504fc0125d9ed204e42" },
      { label: "Settlement", href: "https://sepolia.uniscan.xyz/tx/0x81f7878312b81b80ba69ad8fdc0f4e06f64f8624ed610ebd5a6ea63cca0ca610" },
      { label: "Claim", href: "https://sepolia.uniscan.xyz/tx/0xd78f8533519c4468ac345f0caad52a8eb5c57ee904fc5882eb9066ee16b1b9d8" },
    ],
    boundary: "The explorer sequence proves that terminal hook accounting becomes a real wallet claim, not a dashboard-only number.",
  },
  {
    id: "reactive",
    eyebrow: "Reactive Network transport",
    title: "11-second authenticated callback",
    summary: "A canonical Ethereum event activated Legacy ReactVM and produced the authenticated callback on Unichain without a MARKOUT-operated listener.",
    status: "Cross-chain transport verified",
    tone: "blue",
    metrics: [
      { value: "11s", label: "source to destination" },
      { value: "ReactVM", label: "autonomous execution" },
      { value: "No-op", label: "duplicate-safe result" },
    ],
    receipts: [
      { label: "Source event", href: "https://sepolia.etherscan.io/tx/0x99c7110784fc9e39ff0db078be74e3995855172a4f9a8c565169373e1daa7c85" },
      { label: "Reactive pulse", href: "https://lasna.reactscan.net/address/0x253A29BfbbCECDeCE7a32ba98Bd12922Af4b9e5b" },
      { label: "Callback", href: "https://sepolia.uniscan.xyz/tx/0x5d933d5ff078c500c61fc32fef1ae526049085dad8e15ff4ef2673a971114459" },
    ],
    boundary: "The trade was already terminal, so this proves Reactive transport liveness and replay safety, not Reactive-first economic settlement.",
  },
];

export function PublicProofMode() {
  const [selectedId, setSelectedId] = useState<ProofId>("fair-flow");
  const selected = proofPaths.find((proof) => proof.id === selectedId) ?? proofPaths[0];

  return (
    <section className="proof-mode-section" id="proof-mode" aria-labelledby="proof-mode-title">
      <div className="proof-mode-heading">
        <div>
          <p className="kicker">Judge proof mode</p>
          <h2 id="proof-mode-title">Four public proof paths. No wallet required.</h2>
        </div>
        <p>
          Select an outcome, inspect its measured state, then open every source, settlement, and claim directly in a
          public explorer. The evidence boundary stays visible beside the result.
        </p>
      </div>

      <div className="proof-mode-selector" role="tablist" aria-label="Choose a public proof path">
        {proofPaths.map((proof, index) => (
          <button
            type="button"
            role="tab"
            aria-selected={selectedId === proof.id}
            data-active={selectedId === proof.id}
            onClick={() => setSelectedId(proof.id)}
            key={proof.id}
          >
            <span>0{index + 1}</span>
            <small>{proof.eyebrow}</small>
            <strong>{proof.title}</strong>
          </button>
        ))}
      </div>

      <div className="proof-mode-receipt" data-tone={selected.tone} role="tabpanel">
        <div className="proof-mode-copy">
          <span className="proof-mode-status"><i /> {selected.status}</span>
          <h3>{selected.title}</h3>
          <p>{selected.summary}</p>
          <div className="proof-mode-links">
            {selected.receipts.map((receipt) => (
              <a href={receipt.href} target="_blank" rel="noreferrer" key={receipt.href}>{receipt.label} ↗</a>
            ))}
          </div>
        </div>
        <div className="proof-mode-metrics">
          {selected.metrics.map((metric) => (
            <div key={metric.label}><strong>{metric.value}</strong><span>{metric.label}</span></div>
          ))}
        </div>
        <p className="proof-mode-boundary"><b>Evidence boundary</b>{selected.boundary}</p>
      </div>
    </section>
  );
}
