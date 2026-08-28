"use client";

import { useEffect, useRef, useState } from "react";

type LiveQuote = {
  symbol: string;
  feedId: string;
  price: number;
  confidence: number;
  confidenceBps: number;
  emaPrice: number | null;
  publishTime: number;
  receivedAt: number;
  source: string;
};

type QuoteSample = {
  price: number;
  publishTime: number;
};

type ScenarioId = "benign" | "inventory" | "adverse";

type Scenario = {
  id: ScenarioId;
  label: string;
  signal: string;
  outcome: string;
  markoutBps: number;
  finalFeeBps: number;
  rebateBps: number;
  protectionBps: number;
  pathBps: number[];
};

const scenarioOrder: ScenarioId[] = ["benign", "inventory", "adverse"];

const scenarios: Record<ScenarioId, Scenario> = {
  benign: {
    id: "benign",
    label: "Benign flow",
    signal: "Near execution",
    outcome: "Most escrow returns to the trader",
    markoutBps: 2.4,
    finalFeeBps: 27.43,
    rebateBps: 40.57,
    protectionBps: 9.43,
    pathBps: [0, 1.8, -0.7, 2.6, 0.9, -1.3, 1.2, 2.9, 1.1, 0.4, 2.1, 1.6, 2.8, 2.4],
  },
  inventory: {
    id: "inventory",
    label: "Inventory-improving",
    signal: "Moves against trader",
    outcome: "The entire escrow returns to the trader",
    markoutBps: -18,
    finalFeeBps: 18,
    rebateBps: 50,
    protectionBps: 0,
    pathBps: [0, -1.7, -3.1, -2.4, -5.8, -7.2, -6.3, -9.5, -11.4, -10.8, -13.9, -15.6, -17.1, -18],
  },
  adverse: {
    id: "adverse",
    label: "Adverse flow",
    signal: "Moves with trader",
    outcome: "Escrow is retained for LP protection",
    markoutBps: 22,
    finalFeeBps: 61.06,
    rebateBps: 6.94,
    protectionBps: 43.06,
    pathBps: [0, 2.4, 1.1, 4.8, 6.3, 5.6, 9.1, 11.8, 10.9, 14.7, 16.3, 19.2, 20.4, 22],
  },
};

function formatUsd(value: number) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
}

function formatClock(timestamp: number) {
  return new Intl.DateTimeFormat("en-US", {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).format(new Date(timestamp * 1_000));
}

function ageLabel(timestamp: number, now: number) {
  const seconds = Math.max(0, Math.round(now / 1_000 - timestamp));
  return seconds < 2 ? "now" : `${seconds}s ago`;
}

function MarketCanvas({
  points,
  tone,
  baseline,
}: {
  points: number[];
  tone: "live" | ScenarioId;
  baseline?: number;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const context = canvas.getContext("2d");
    if (!context) return;

    const render = () => {
      const rect = canvas.getBoundingClientRect();
      const ratio = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width = Math.max(1, Math.floor(rect.width * ratio));
      canvas.height = Math.max(1, Math.floor(rect.height * ratio));
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
      context.clearRect(0, 0, rect.width, rect.height);

      const padding = { top: 18, right: 14, bottom: 22, left: 14 };
      const width = Math.max(1, rect.width - padding.left - padding.right);
      const height = Math.max(1, rect.height - padding.top - padding.bottom);
      const values = points.length > 1 ? points : [points[0] ?? 0, points[0] ?? 0];
      const valueBaseline = baseline ?? values[0];
      const minimum = Math.min(...values, valueBaseline);
      const maximum = Math.max(...values, valueBaseline);
      const naturalRange = Math.max(maximum - minimum, Math.abs(valueBaseline) * 0.00002, 0.0001);
      const low = minimum - naturalRange * 0.25;
      const high = maximum + naturalRange * 0.25;
      const x = (index: number) => padding.left + (index / Math.max(values.length - 1, 1)) * width;
      const y = (value: number) => padding.top + (1 - (value - low) / (high - low)) * height;

      context.strokeStyle = "rgba(221, 255, 231, 0.08)";
      context.lineWidth = 1;
      for (let row = 0; row <= 3; row += 1) {
        const gridY = padding.top + (row / 3) * height;
        context.beginPath();
        context.moveTo(padding.left, gridY);
        context.lineTo(rect.width - padding.right, gridY);
        context.stroke();
      }

      const baseY = y(valueBaseline);
      context.setLineDash([4, 5]);
      context.strokeStyle = "rgba(244, 198, 106, 0.46)";
      context.beginPath();
      context.moveTo(padding.left, baseY);
      context.lineTo(rect.width - padding.right, baseY);
      context.stroke();
      context.setLineDash([]);

      const colors: Record<typeof tone, string> = {
        live: "#8affad",
        benign: "#8affad",
        inventory: "#82b9ff",
        adverse: "#ff8e74",
      };
      const color = colors[tone];
      const gradient = context.createLinearGradient(0, padding.top, 0, rect.height - padding.bottom);
      gradient.addColorStop(0, `${color}38`);
      gradient.addColorStop(1, `${color}00`);

      context.beginPath();
      values.forEach((value, index) => {
        if (index === 0) context.moveTo(x(index), y(value));
        else context.lineTo(x(index), y(value));
      });
      context.lineTo(x(values.length - 1), rect.height - padding.bottom);
      context.lineTo(x(0), rect.height - padding.bottom);
      context.closePath();
      context.fillStyle = gradient;
      context.fill();

      context.beginPath();
      values.forEach((value, index) => {
        if (index === 0) context.moveTo(x(index), y(value));
        else context.lineTo(x(index), y(value));
      });
      context.strokeStyle = color;
      context.lineWidth = 2;
      context.lineJoin = "round";
      context.lineCap = "round";
      context.shadowColor = `${color}7a`;
      context.shadowBlur = 12;
      context.stroke();
      context.shadowBlur = 0;

      const lastIndex = values.length - 1;
      context.beginPath();
      context.arc(x(lastIndex), y(values[lastIndex]), 3.5, 0, Math.PI * 2);
      context.fillStyle = color;
      context.fill();
    };

    render();
    const observer = new ResizeObserver(render);
    observer.observe(canvas);
    return () => observer.disconnect();
  }, [baseline, points, tone]);

  return <canvas className="market-canvas" ref={canvasRef} aria-hidden="true" />;
}

function LiveMarketMonitor() {
  const [quote, setQuote] = useState<LiveQuote | null>(null);
  const [samples, setSamples] = useState<QuoteSample[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    let cancelled = false;

    async function refresh() {
      try {
        const response = await fetch("/api/market-price", { cache: "no-store" });
        const payload = await response.json() as LiveQuote & { error?: string };
        if (!response.ok) throw new Error(payload.error ?? "Live Pyth pricing is temporarily unavailable.");
        if (cancelled) return;
        setQuote(payload);
        setError(null);
        setSamples((current) => {
          if (current.at(-1)?.publishTime === payload.publishTime) return current;
          return [...current, { price: payload.price, publishTime: payload.publishTime }].slice(-36);
        });
      } catch (refreshError) {
        if (!cancelled) {
          setError(refreshError instanceof Error ? refreshError.message : "Live Pyth pricing is temporarily unavailable.");
        }
      }
    }

    void refresh();
    const quoteTimer = window.setInterval(refresh, 5_000);
    const clockTimer = window.setInterval(() => setNow(Date.now()), 1_000);
    return () => {
      cancelled = true;
      window.clearInterval(quoteTimer);
      window.clearInterval(clockTimer);
    };
  }, []);

  const pricePoints = samples.map((sample) => sample.price);
  const sessionMoveBps = samples.length > 1
    ? ((samples.at(-1)!.price / samples[0].price) - 1) * 10_000
    : 0;

  return (
    <article className="market-live-card">
      <div className="market-card-heading">
        <div>
          <p className="kicker">Live reference monitor</p>
          <h3>Pyth ETH/USD</h3>
        </div>
        <span className="market-live-status" data-live={Boolean(quote && !error)}>
          <i /> {quote && !error ? "LIVE" : error ? "RETRYING" : "CONNECTING"}
        </span>
      </div>

      <div className="live-price-row">
        <strong>{quote ? formatUsd(quote.price) : "$-,---.--"}</strong>
        <span data-positive={sessionMoveBps >= 0}>
          {sessionMoveBps >= 0 ? "+" : ""}{sessionMoveBps.toFixed(2)} bps session
        </span>
      </div>

      <div className="market-chart-shell">
        <MarketCanvas points={pricePoints} tone="live" />
        <div className="market-chart-labels"><span>Session start</span><span>Latest signed price</span></div>
      </div>

      <div className="market-telemetry">
        <div><span>Published</span><strong>{quote ? formatClock(quote.publishTime) : "Waiting"}</strong></div>
        <div><span>Freshness</span><strong>{quote ? ageLabel(quote.publishTime, now) : "-"}</strong></div>
        <div><span>Confidence</span><strong>{quote ? `±${quote.confidenceBps.toFixed(3)} bps` : "-"}</strong></div>
        <div><span>Samples</span><strong>{samples.length} / 36</strong></div>
      </div>

      {error ? <p className="market-error">{error} The research replay remains available.</p> : null}
      <p className="market-source-note">Server-authenticated Pyth Hermes feed. No wallet or simulated value is used here.</p>
    </article>
  );
}

function ResearchReplay() {
  const [selected, setSelected] = useState<ScenarioId>("benign");
  const [progress, setProgress] = useState(1);
  const [playing, setPlaying] = useState(true);
  const scenario = scenarios[selected];

  useEffect(() => {
    if (!playing) return;
    const timer = window.setInterval(() => {
      setProgress((current) => {
        if (current >= scenario.pathBps.length) {
          setPlaying(false);
          return current;
        }
        return current + 1;
      });
    }, 430);
    return () => window.clearInterval(timer);
  }, [playing, scenario.pathBps.length]);

  function playScenario(nextScenario: ScenarioId) {
    setSelected(nextScenario);
    setProgress(1);
    setPlaying(true);
  }

  function replay() {
    setProgress(1);
    setPlaying(true);
  }

  const visiblePath = scenario.pathBps.slice(0, progress);
  const currentMarkout = visiblePath.at(-1) ?? 0;
  const finished = progress >= scenario.pathBps.length;
  const fiveMinuteProgress = Math.round((Math.max(progress - 1, 0) / (scenario.pathBps.length - 1)) * 300);
  const currentMinute = Math.floor(fiveMinuteProgress / 60);
  const currentSecond = fiveMinuteProgress % 60;
  const outcomeTone = scenario.id === "adverse" ? "protection" : scenario.id === "inventory" ? "rebate" : "neutral";

  return (
    <article className="market-replay-card">
      <div className="market-card-heading">
        <div>
          <p className="kicker">Controlled scenario replay</p>
          <h3>Five-minute outcome window</h3>
        </div>
        <span className="research-replay-badge">RESEARCH · NOT ONCHAIN</span>
      </div>

      <div className="replay-selector" role="group" aria-label="Choose a research replay">
        {scenarioOrder.map((scenarioId) => (
          <button
            type="button"
            key={scenarioId}
            data-active={selected === scenarioId}
            onClick={() => playScenario(scenarioId)}
            aria-pressed={selected === scenarioId}
          >
            {scenarios[scenarioId].label}
          </button>
        ))}
      </div>

      <div className="replay-summary-row">
        <div><span>Scenario</span><strong>{scenario.signal}</strong></div>
        <div><span>Directional markout</span><strong data-tone={outcomeTone}>{currentMarkout > 0 ? "+" : ""}{currentMarkout.toFixed(1)} bps</strong></div>
        <div><span>Protocol clock</span><strong>{currentMinute}:{currentSecond.toString().padStart(2, "0")} / 5:00</strong></div>
      </div>

      <div className="market-chart-shell replay-chart-shell">
        <MarketCanvas points={visiblePath} tone={scenario.id} baseline={0} />
        <div className="market-chart-labels"><span>Execution · t+0</span><span>Pyth observation · t+5m</span></div>
      </div>

      <div className="replay-progress" aria-label={`Replay progress ${fiveMinuteProgress} of 300 seconds`}>
        <div style={{ width: `${(fiveMinuteProgress / 300) * 100}%` }} />
      </div>

      <div className="replay-allocation" data-finished={finished}>
        <div><span>Base fee</span><strong>18.00 bps</strong></div>
        <div><span>Trader rebate</span><strong>{finished ? `${scenario.rebateBps.toFixed(2)} bps` : "Pending"}</strong></div>
        <div><span>LP protection</span><strong>{finished ? `${scenario.protectionBps.toFixed(2)} bps` : "Pending"}</strong></div>
        <div className="replay-final"><span>Final fee</span><strong>{finished ? `${scenario.finalFeeBps.toFixed(2)} bps` : "Pending"}</strong></div>
      </div>

      <div className="replay-verdict">
        <div><span>Outcome</span><strong>{finished ? scenario.outcome : "Waiting for delayed evidence"}</strong></div>
        <button type="button" onClick={replay} disabled={playing}>↻ {playing ? "Replaying" : "Replay"}</button>
      </div>
    </article>
  );
}

export function MarketReplayLab() {
  return (
    <section className="market-lab-section" id="market-lab" aria-labelledby="market-lab-title">
      <div className="market-lab-heading">
        <div>
          <p className="kicker">Market intelligence layer</p>
          <h2 id="market-lab-title">Watch the price. Then watch the fee respond.</h2>
        </div>
        <p className="section-lede">
          The live panel reports signed Pyth ETH/USD observations. The replay panel uses declared deterministic paths
          to expose both settlement extremes without pretending that a controlled experiment is a live trade.
        </p>
      </div>

      <div className="market-lab-truth-strip" aria-label="Evidence labels">
        <span><i className="truth-live" /> LIVE MARKET DATA</span>
        <b>Pyth-signed ETH/USD observations</b>
        <span><i className="truth-research" /> CONTROLLED REPLAY</span>
        <b>Frozen synthetic mechanism study</b>
        <span><i className="truth-chain" /> LIVE TESTNET</span>
        <b>Transactions remain in the console below</b>
      </div>

      <div className="market-lab-grid">
        <LiveMarketMonitor />
        <ResearchReplay />
      </div>
    </section>
  );
}
