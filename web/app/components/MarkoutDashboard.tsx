"use client";

import { useEffect, useMemo, useState, type CSSProperties } from "react";
import {
  adoptionBreakEvens,
  aggregateMetrics,
  experimentCaveat,
  flowCases,
  flowOrder,
  policyResults,
  timelineBase,
  type FlowId,
} from "../lib/demo-data";
import { LiveTestnetConsole } from "./LiveTestnetConsole";

const maximumFeeBps = 80;

function formatBps(value: number) {
  return `${value.toFixed(value % 1 === 0 ? 0 : 2)} bps`;
}

function dollarsPerTenThousand(value: number) {
  return `$${value.toFixed(2)}`;
}

function Bar({ value, tone }: { value: number; tone: "fixed" | "volatility" | "markout" }) {
  const style = { "--bar-size": `${(value / maximumFeeBps) * 100}%` } as CSSProperties;
  return (
    <div className="fee-bar-track" aria-hidden="true">
      <div className={`fee-bar fee-bar-${tone}`} style={style} />
    </div>
  );
}

function FlowSelector({ selected, onChange }: { selected: FlowId; onChange: (flow: FlowId) => void }) {
  return (
    <div className="flow-selector" role="group" aria-label="Choose an order-flow outcome">
      {flowOrder.map((flowId) => {
        const flow = flowCases[flowId];
        return (
          <button
            className="flow-option"
            data-active={selected === flowId}
            key={flowId}
            onClick={() => onChange(flowId)}
            type="button"
            aria-pressed={selected === flowId}
          >
            <span className="flow-option-dot" />
            {flow.shortLabel}
          </button>
        );
      })}
    </div>
  );
}

function OutcomeComparison({ selected }: { selected: FlowId }) {
  const flow = flowCases[selected];
  const rows = [
    { label: "Fixed fee", value: flow.fixedFeeBps, tone: "fixed" as const, note: "Same for every trader" },
    {
      label: "Volatility fee",
      value: flow.volatilityFeeBps,
      tone: "volatility" as const,
      note: "Prices the market regime",
    },
    {
      label: "MARKOUT",
      value: flow.markoutFeeBps,
      tone: "markout" as const,
      note: "Prices the realized outcome",
    },
  ];

  return (
    <div className="comparison-panel">
      <div className="comparison-heading">
        <div>
          <p className="kicker">Average effective fee by flow class</p>
          <h3>{flow.label}</h3>
        </div>
        <div className="signal-chip">
          <span>Directional markout</span>
          <strong>{flow.markoutSignal}</strong>
        </div>
      </div>

      <p className="comparison-thesis">{flow.thesis}</p>

      <div className="fee-rows">
        {rows.map((row) => (
          <div className="fee-row" key={row.label}>
            <div className="fee-row-label">
              <strong>{row.label}</strong>
              <span>{row.note}</span>
            </div>
            <Bar value={row.value} tone={row.tone} />
            <span className="fee-value">{formatBps(row.value)}</span>
          </div>
        ))}
      </div>

      <div className="outcome-callout">
        <span className="outcome-index">Outcome</span>
        <p>{flow.verdict}</p>
      </div>
    </div>
  );
}

function SettlementCard({ selected }: { selected: FlowId }) {
  const flow = flowCases[selected];
  return (
    <aside className="settlement-card" aria-label="MARKOUT settlement receipt">
      <div className="receipt-header">
        <div>
          <p className="kicker">Settlement receipt</p>
          <h3>{flow.markoutDescription}</h3>
        </div>
        <span className="local-badge">Deterministic</span>
      </div>

      <div className="receipt-notional">
        <span>Illustrative notional</span>
        <strong>$10,000.00</strong>
      </div>

      <div className="receipt-grid">
        <div>
          <span>Base LP fee</span>
          <strong>$18.00</strong>
          <small>18 bps candidate</small>
        </div>
        <div>
          <span>Provisional</span>
          <strong>$50.00</strong>
          <small>50 bps escrowed</small>
        </div>
      </div>

      <div className="allocation-rail" aria-label="Provisional fee allocation">
        <div className="allocation-rebate" style={{ flexGrow: flow.rebateBps }} />
        <div className="allocation-protection" style={{ flexGrow: Math.max(flow.protectionBps, 0.001) }} />
      </div>

      <div className="allocation-legend">
        <div>
          <span className="legend-dot legend-rebate" />
          <span>Returned to trader</span>
          <strong>{dollarsPerTenThousand(flow.rebateBps)}</strong>
        </div>
        <div>
          <span className="legend-dot legend-protection" />
          <span>LP protection</span>
          <strong>{dollarsPerTenThousand(flow.protectionBps)}</strong>
        </div>
      </div>

      <div className="receipt-total">
        <span>Final effective fee</span>
        <strong>{dollarsPerTenThousand(flow.markoutFeeBps)}</strong>
        <small>{formatBps(flow.markoutFeeBps)}</small>
      </div>
    </aside>
  );
}

function SettlementTimeline({ selected }: { selected: FlowId }) {
  const [activeStep, setActiveStep] = useState(0);
  const [playing, setPlaying] = useState(false);
  const flow = flowCases[selected];
  const steps = useMemo(
    () => [
      ...timelineBase,
      {
        label: flow.rebateBps === 50 ? "Full rebate unlocked" : "Allocation finalized",
        detail: `${dollarsPerTenThousand(flow.rebateBps)} returns to the trader; ${dollarsPerTenThousand(flow.protectionBps)} remains as LP protection per $10,000.`,
        tag: "Destination",
      },
    ],
    [flow],
  );

  useEffect(() => {
    if (!playing) return;
    const timer = window.setInterval(() => {
      setActiveStep((current) => {
        if (current >= steps.length - 1) {
          setPlaying(false);
          return current;
        }
        return current + 1;
      });
    }, 850);
    return () => window.clearInterval(timer);
  }, [playing, steps.length]);

  function replay() {
    setActiveStep(0);
    setPlaying(true);
  }

  return (
    <section className="timeline-section" id="mechanism" aria-labelledby="timeline-title">
      <div className="section-heading timeline-title-row">
        <div>
          <p className="kicker">Autonomous lifecycle</p>
          <h2 id="timeline-title">Outcome → observation → settlement</h2>
        </div>
        <button className="replay-button" type="button" onClick={replay} disabled={playing}>
          <span className="replay-symbol">↻</span>
          {playing ? "Running…" : "Replay 5-step demo"}
        </button>
      </div>

      <div className="timeline-grid">
        {steps.map((step, index) => {
          const reached = index <= activeStep;
          return (
            <button
              type="button"
              className="timeline-step"
              data-reached={reached}
              data-current={index === activeStep}
              key={step.label}
              onClick={() => {
                setPlaying(false);
                setActiveStep(index);
              }}
              aria-label={`Show step ${index + 1}: ${step.label}`}
            >
              <span className="timeline-number">0{index + 1}</span>
              <span className="timeline-copy">
                <span className="timeline-tag">{step.tag}</span>
                <strong>{step.label}</strong>
                <span>{step.detail}</span>
              </span>
            </button>
          );
        })}
      </div>

      <div className="proof-strip">
        <span className="proof-status"><i /> Public Circle lifecycle proven</span>
        <span>MarkoutRequested</span>
        <span className="proof-arrow">→</span>
        <span>Reference sample</span>
        <span className="proof-arrow">→</span>
        <span>Authenticated delivery</span>
        <span className="proof-arrow">→</span>
        <span>Allocation finalized</span>
      </div>
    </section>
  );
}

function ResearchEvidence() {
  const maxLpNet = Math.max(...policyResults.map((result) => result.lpNet));
  return (
    <section className="evidence-section" id="evidence" aria-labelledby="evidence-title">
      <div className="section-heading">
        <p className="kicker">Reproducible evidence</p>
        <h2 id="evidence-title">Same trades. Three policies. No hidden win.</h2>
        <p className="section-lede">
          Each policy receives the same deterministic tape. The metric is a pool-level adverse-selection proxy, not
          individual LP profit or exact LVR.
        </p>
      </div>

      <div className="live-proof-card" aria-label="Four public Circle settlement lifecycles">
        <div>
          <p className="kicker">Public testnet proof</p>
          <strong>Four lifecycles. Both settlement extremes.</strong>
          <p>
            Circle delivered Pyth observations for four real Unichain v4 swaps. The original 30 + 50 bps pool proves
            both terminal extremes; the separate Fair-Flow pool completed its own rebate lifecycle at an 18 bps final
            fee and executed the sponsored-claim entrypoint.
          </p>
        </div>
        <div className="live-proof-metrics">
          <span><b>4</b> public end-to-end lifecycles</span>
          <span><b>3 / 1</b> full rebates / full retention</span>
          <span><b>38/67/67/55s</b> measured relays</span>
        </div>
        <div className="live-proof-links">
          <a href="https://sepolia.etherscan.io/tx/0xed6af5c42e554c221078110d6db03fba8fd74bf24a88cf52494d4e605a31f6ca" target="_blank" rel="noreferrer">Rebate observation ↗</a>
          <a href="https://sepolia.uniscan.xyz/tx/0xa64789b5a08ea8aae8c2b909b6a81b495334b707eaae12610bf3749902ec532f" target="_blank" rel="noreferrer">Rebate settlement ↗</a>
          <a href="https://sepolia.uniscan.xyz/tx/0xa6ded637a8c9651f252e302f7cedec2969d637f733777f7f2ad71ac700d64630" target="_blank" rel="noreferrer">Rebate claim ↗</a>
          <a href="https://sepolia.uniscan.xyz/tx/0xb6179eab5dcf9ff2f3563442dbf826fe5fcb86524e9d71aa913c9ba9e90a2376" target="_blank" rel="noreferrer">Protection swap ↗</a>
          <a href="https://sepolia.etherscan.io/tx/0x9d20a2a8bfc5c7dd654608a9214472ff3ed37cbdff4614064aff28805f9f8861" target="_blank" rel="noreferrer">Protection observation ↗</a>
          <a href="https://sepolia.uniscan.xyz/tx/0xefeece5de9f78ae809652418e1fcd8fb592de950af64e6bbbf66df93bdc25eae" target="_blank" rel="noreferrer">Protection settlement ↗</a>
          <a href="https://sepolia.uniscan.xyz/tx/0x889ea958d19574572890a5ae5a5890c7a8d31f94ebfbe9d065b58d884c1f739a" target="_blank" rel="noreferrer">Wallet-console swap ↗</a>
          <a href="https://sepolia.uniscan.xyz/tx/0x81f7878312b81b80ba69ad8fdc0f4e06f64f8624ed610ebd5a6ea63cca0ca610" target="_blank" rel="noreferrer">Wallet-console settlement ↗</a>
          <a href="https://sepolia.uniscan.xyz/tx/0xd78f8533519c4468ac345f0caad52a8eb5c57ee904fc5882eb9066ee16b1b9d8" target="_blank" rel="noreferrer">Wallet-console claim ↗</a>
          <a href="https://sepolia.uniscan.xyz/tx/0xf4873749b39300d5d19d28e3b0b0f43511ac907595b85d14e76c725f86f9c70f" target="_blank" rel="noreferrer">Fair-Flow swap ↗</a>
          <a href="https://sepolia.etherscan.io/tx/0xccd8cc932276ce3233665c230d8107854b2201bca15a173b7986245c9d517221" target="_blank" rel="noreferrer">Fair-Flow observation ↗</a>
          <a href="https://sepolia.uniscan.xyz/tx/0xb1bd16c88d71fbb737cbaa20ed9002dd7bd7098d1c17ac11ab3c7f9ed01c0c4d" target="_blank" rel="noreferrer">Fair-Flow settlement ↗</a>
          <a href="https://sepolia.uniscan.xyz/tx/0x996ae7697b54ea67df0fbd3eb9ded1163d3a3df1d272bdcc7260ee18597b5f70" target="_blank" rel="noreferrer">Fair-Flow claim ↗</a>
        </div>
      </div>

      <div className="evidence-layout">
        <div className="policy-chart" aria-label="LP net after adverse-selection proxy by policy">
          <div className="chart-axis-label">LP net after proxy · USDC</div>
          {policyResults.map((result) => (
            <div className="policy-column" key={result.policy}>
              <div className="policy-value">${result.lpNet.toLocaleString("en-US", { maximumFractionDigits: 0 })}</div>
              <div className="policy-column-track">
                <div
                  className={`policy-column-fill policy-${result.tone}`}
                  style={{ height: `${(result.lpNet / maxLpNet) * 100}%` }}
                />
              </div>
              <strong>{result.policy}</strong>
              <span>{formatBps(result.effectiveFee)} avg fee</span>
            </div>
          ))}
        </div>

        <aside className="honest-result">
          <span className="honest-label">The honest regression</span>
          <strong>MARKOUT is not the highest-fee policy.</strong>
          <p>{experimentCaveat}</p>
          <div className="honest-divider" />
          <span className="honest-thesis">Research claim</span>
          <p>Outcome-based fees can protect LPs while charging good flow less than a volatility-only policy.</p>
        </aside>
      </div>

      <div className="adoption-proof" aria-labelledby="adoption-proof-title">
        <div className="adoption-proof-heading">
          <div>
            <p className="kicker">Trader adoption proof</p>
            <h3 id="adoption-proof-title">Good flow wins without assuming deeper liquidity.</h3>
          </div>
          <p>
            Under the selected 18 bps base, benign and inventory-improving traders already beat a fixed 30 bps pool
            at equal execution quality. Informed flow pays more only after its realized outcome is adverse.
          </p>
        </div>
        <div className="adoption-grid">
          {adoptionBreakEvens.map((item) => (
            <article key={item.flow}>
              <span>{item.flow}</span>
              <div>
                <strong>{item.vsFixed}</strong>
                <small>{item.vsFixedLabel}</small>
              </div>
              <div>
                <strong>{item.vsVolatility}</strong>
                <small>{item.vsVolatilityLabel}</small>
              </div>
              <p>{item.conclusion}</p>
            </article>
          ))}
        </div>
        <p className="adoption-verdict">
          <b>Measured result:</b> benign flow saves $2.57 and inventory-improving flow saves $12.00 per $10,000
          versus fixed, while MARKOUT still improves modeled LP net-after-proxy by 21.87%. <b>Boundary:</b> routing,
          demand elasticity, and additional liquidity remain unmodeled.
        </p>
      </div>
    </section>
  );
}

export function MarkoutDashboard() {
  const [selected, setSelected] = useState<FlowId>("benign");

  return (
    <main>
      <header className="site-header">
        <a className="brand" href="#top" aria-label="MARKOUT home">
          <span className="brand-mark">M</span>
          <span>MARKOUT</span>
        </a>
        <nav aria-label="Primary navigation">
          <a href="#testnet">Live testnet</a>
          <a href="#compare">Compare</a>
          <a href="#mechanism">Mechanism</a>
          <a href="#evidence">Evidence</a>
        </nav>
        <span className="testnet-status"><i /> Circle live · Reactive optional</span>
      </header>

      <section className="hero" id="top">
        <div className="hero-copy">
          <div className="hero-eyebrow"><span>UHI10</span> Sustainable liquidity × MEV protection</div>
          <h1>Fees should follow <em>outcomes.</em><br />Not fear.</h1>
          <p>
            MARKOUT is a Uniswap v4 hook that escrows a provisional charge, waits for post-trade evidence, then lets
            an authenticated observation return it to good flow—or retain it when LPs were adversely selected. The
            Fair-Flow profile starts at 18 bps, so good flow finishes below a normal 30 bps pool.
          </p>
          <div className="hero-actions">
            <a className="primary-action" href="#testnet">Run a real testnet swap <span>↓</span></a>
            <a className="secondary-action" href="#evidence">Inspect the research</a>
          </div>
        </div>

        <div className="hero-system" aria-label="MARKOUT mechanism summary">
          <div className="system-topline">
            <span>TRADE_QUALITY_ENGINE</span>
            <span className="system-live"><i /> DETERMINISTIC</span>
          </div>
          <div className="system-orbit">
            <div className="orbit-ring orbit-ring-outer" />
            <div className="orbit-ring orbit-ring-inner" />
            <div className="orbit-node orbit-node-one">SWAP</div>
            <div className="orbit-node orbit-node-two">PRICE</div>
            <div className="orbit-node orbit-node-three">CALLBACK</div>
            <div className="orbit-core"><span>POST-TRADE</span><strong>MARKOUT</strong><small>t + 5 min</small></div>
          </div>
          <div className="system-equation">
            <span>EXECUTION</span><b>→</b><span>OBSERVATION</span><b>→</b><strong>FAIR FEE</strong>
          </div>
        </div>
      </section>

      <section className="metric-ribbon" aria-label="Research and security metrics">
        {aggregateMetrics.map((metric) => (
          <div className="metric" key={metric.label}>
            <strong>{metric.value}</strong>
            <span>{metric.label}</span>
            <small>{metric.detail}</small>
          </div>
        ))}
      </section>

      <LiveTestnetConsole />

      <section className="comparison-section" id="compare" aria-labelledby="comparison-title">
        <div className="section-heading comparison-section-heading">
          <div>
            <p className="kicker">Guided comparison</p>
            <h2 id="comparison-title">Same market. Different information.</h2>
          </div>
          <FlowSelector selected={selected} onChange={setSelected} />
        </div>
        <p className="section-lede">
          <b>Fair-Flow release candidate:</b> 18 bps base + refundable 50 bps surcharge. The live console above stays
          connected to the proven 30 + 50 bps deployment until a separate candidate pool is explicitly deployed.
        </p>
        <div className="comparison-layout">
          <OutcomeComparison selected={selected} />
          <SettlementCard selected={selected} />
        </div>
      </section>

      <SettlementTimeline key={selected} selected={selected} />
      <ResearchEvidence />

      <section className="architecture-section" aria-labelledby="architecture-title">
        <div>
          <p className="kicker">System boundary</p>
          <h2 id="architecture-title">One outcome. Two transport paths.</h2>
        </div>
        <div className="architecture-flow">
          <div><span>01</span><strong>Uniswap v4</strong><small>Swap + escrow</small></div>
          <b>→</b>
          <div><span>02</span><strong>Pyth + Circle</strong><small>Verify + attest</small></div>
          <b>→</b>
          <div><span>03</span><strong>MARKOUT curve</strong><small>Bounded allocation</small></div>
          <b>→</b>
          <div><span>04</span><strong>Coordinator</strong><small>First valid delivery</small></div>
        </div>
      </section>

      <footer>
        <div>
          <span className="brand footer-brand"><span className="brand-mark">M</span> MARKOUT</span>
          <p>Outcome-priced liquidity for Uniswap v4.</p>
        </div>
        <div className="footer-status">
          <span><i className="status-green" /> Four public Circle lifecycles proven</span>
          <span><i className="status-amber" /> Reactive callback not yet observed</span>
        </div>
        <p className="footer-note">Experimental UHI10 prototype · Not audited · No real funds</p>
      </footer>
    </main>
  );
}
