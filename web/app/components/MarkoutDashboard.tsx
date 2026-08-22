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

function ArchitectureDiagram() {
  return (
    <section className="architecture-section" id="architecture" aria-labelledby="architecture-title">
      <div className="architecture-heading">
        <div>
          <p className="kicker">Hybrid architecture</p>
          <h2 id="architecture-title">One canonical observation. Two independent delivery paths.</h2>
        </div>
        <p className="section-lede">
          The hook owns funds and economics. Pyth owns price verification. Circle and Reactive compete only to deliver
          the same normalized observation; neither transport can alter the allocation rule.
        </p>
      </div>

      <div className="architecture-map" aria-label="MARKOUT hybrid settlement architecture">
        <article className="architecture-node architecture-source">
          <span className="architecture-index">01 · UNICHAIN SEPOLIA</span>
          <strong>Uniswap v4 swap + MARKOUT escrow</strong>
          <p>The hook records direction and execution price, then holds a bounded 50 bps provisional charge.</p>
        </article>

        <div className="architecture-arrow" aria-hidden="true"><span>Five-minute outcome window</span><b>↓</b></div>

        <article className="architecture-node architecture-publisher">
          <span className="architecture-index">02 · ETHEREUM SEPOLIA</span>
          <strong>Pyth-verified canonical observation</strong>
          <p>The publisher normalizes price, timestamp, confidence, market, and trade ID once for both transports.</p>
        </article>

        <div className="architecture-arrow architecture-fork" aria-hidden="true"><span>One event · two routes</span><b>↓</b></div>

        <div className="transport-grid">
          <article className="transport-card transport-reactive">
            <div className="transport-card-topline">
              <span className="transport-badge">Reactive Network · sponsor path</span>
              <span className="transport-state transport-state-verified">Pulse deployed</span>
            </div>
            <h3>Event-driven callback accelerator</h3>
            <p>
              A funded legacy RSC holds an exact subscription to the publisher event and is designed to forward its
              immutable payload through an authenticated Unichain callback—without a keeper or trade database.
            </p>
            <div className="transport-route" aria-label="Reactive delivery route">
              <span>Publisher event</span><b>→</b><span>ReactVM</span><b>→</b><span>Callback proxy</span>
            </div>
          </article>

          <article className="transport-card transport-circle">
            <div className="transport-card-topline">
              <span className="transport-badge">Circle · proven primary</span>
              <span className="transport-state transport-state-live">4 live relays</span>
            </div>
            <h3>Attested generic message</h3>
            <p>Circle signs the application message; any relayer may submit it to the authenticated receiver.</p>
            <div className="transport-route" aria-label="Circle delivery route">
              <span>Message</span><b>→</b><span>Attestation</span><b>→</b><span>Receiver</span>
            </div>
          </article>
        </div>

        <div className="coordinator-merge">
          <span>RACE-SAFE MERGE</span>
          <strong>SettlementCoordinator · first valid delivery wins</strong>
          <small>Later delivery becomes a successful no-op</small>
        </div>

        <article className="architecture-node architecture-destination">
          <span className="architecture-index">03 · MARKOUT HOOK</span>
          <strong>Re-validate → compute directional markout → allocate</strong>
          <p>Return the surcharge to good flow or retain the justified portion as LP protection.</p>
        </article>

        <div className="architecture-failsafe">
          <span>NO VALID DELIVERY?</span>
          <strong>Permissionless expiry returns the entire provisional charge.</strong>
        </div>
      </div>
    </section>
  );
}

function ReactiveNetworkSection() {
  const capabilities = [
    {
      index: "01",
      title: "Observe once",
      copy: "The RSC subscribes to one exact publisher and event signature instead of maintaining its own oracle or sampler.",
    },
    {
      index: "02",
      title: "React autonomously",
      copy: "A matching source event is enough to construct the destination callback; no MARKOUT operator chooses which trade to forward.",
    },
    {
      index: "03",
      title: "Carry minimal state",
      copy: "Only market, trade, normalized price, observation time, and confidence cross the boundary—never custody or fee authority.",
    },
    {
      index: "04",
      title: "Accelerate safely",
      copy: "Reactive may beat Circle to settlement, while coordinator idempotency makes either arrival order economically identical.",
    },
  ];

  return (
    <section className="reactive-section" id="reactive" aria-labelledby="reactive-title">
      <div className="reactive-heading">
        <div>
          <p className="kicker">Reactive Network integration</p>
          <h2 id="reactive-title">Turn a verified observation into cross-chain action.</h2>
        </div>
        <div className="reactive-prize-chip">
          <span>Sponsor thesis</span>
          <strong>Automation without custody</strong>
        </div>
      </div>

      <div className="reactive-stage-grid">
        {capabilities.map((capability) => (
          <article key={capability.index}>
            <span>{capability.index}</span>
            <strong>{capability.title}</strong>
            <p>{capability.copy}</p>
          </article>
        ))}
      </div>

      <div className="reactive-proof-layout">
        <div className="reactive-value-copy">
          <p className="kicker">Why Reactive matters here</p>
          <h3>The RSC is an execution trigger, not another trusted protocol operator.</h3>
          <p>
            MARKOUT demonstrates a narrow Reactive pattern judges can reuse: observe an authenticated source event,
            transport the exact payload, and trigger a destination action behind independent validation. The RSC has
            no custody, pricing discretion, scheduling database, upgrade key, or ability to select a rebate recipient.
          </p>
          <div className="reactive-boundary-strip">
            <span>Event automation</span><b>✓</b>
            <span>Cross-chain callback</span><b>✓</b>
            <span>Custody</span><b>×</b>
            <span>Fee authority</span><b>×</b>
          </div>
        </div>

        <aside className="reactive-proof-card" aria-label="Reactive Network public evidence status">
          <p className="kicker">Public evidence boundary</p>
          <ul>
            <li data-status="verified"><span>Legacy Lasna pulse deployed</span><b>Verified</b></li>
            <li data-status="verified"><span>Funded and debt-free</span><b>Verified</b></li>
            <li data-status="verified"><span>Exact publisher subscription</span><b>Verified</b></li>
            <li data-status="verified"><span>Authenticated receiver + race tests</span><b>Verified</b></li>
            <li data-status="pending"><span>Public Unichain callback</span><b>Not observed</b></li>
          </ul>
          <div className="reactive-proof-actions">
            <a href="https://lasna.reactscan.net/address/0xdd81EF6558E4D4F8403B3416c25ecD1CcB303e4e" target="_blank" rel="noreferrer">Inspect Reactive pulse ↗</a>
            <a href="https://lasna.reactscan.net/tx/0xdd2af7d35c3f73aa4d667631ff6062053636e6c098e16cfb620205e3481164c6" target="_blank" rel="noreferrer">Deployment receipt ↗</a>
          </div>
          <p className="reactive-honesty-note">
            The integration is deployed and subscribed, but MARKOUT does not label Reactive delivery live until a
            destination callback is publicly visible.
          </p>
        </aside>
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
          <a href="#architecture">Architecture</a>
          <a href="#reactive">Reactive</a>
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
          <b>Live Fair-Flow pool:</b> 18 bps base + refundable 50 bps surcharge. The console and public lifecycle above
          use the separately deployed Fair-Flow hook; original 30 + 50 bps evidence remains independently linked.
        </p>
        <div className="comparison-layout">
          <OutcomeComparison selected={selected} />
          <SettlementCard selected={selected} />
        </div>
      </section>

      <SettlementTimeline key={selected} selected={selected} />
      <ArchitectureDiagram />
      <ReactiveNetworkSection />
      <ResearchEvidence />

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
