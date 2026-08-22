export type FlowId = "benign" | "informed" | "inventory";

export type FlowCase = {
  id: FlowId;
  label: string;
  shortLabel: string;
  eyebrow: string;
  thesis: string;
  markoutDescription: string;
  fixedFeeBps: number;
  volatilityFeeBps: number;
  markoutFeeBps: number;
  rebateBps: number;
  protectionBps: number;
  markoutSignal: string;
  verdict: string;
};

export const flowCases: Record<FlowId, FlowCase> = {
  benign: {
    id: "benign",
    label: "Benign flow",
    shortLabel: "Benign",
    eyebrow: "Price stays near execution",
    thesis: "The trader did not capture a meaningful post-trade move.",
    markoutDescription: "Neutral outcome",
    fixedFeeBps: 30,
    volatilityFeeBps: 49.479,
    markoutFeeBps: 27.4262,
    rebateBps: 40.5738,
    protectionBps: 9.4262,
    markoutSignal: "≈ 0 bps",
    verdict: "Fair-Flow returns most of the provisional charge and finishes below the ordinary 30 bps pool.",
  },
  informed: {
    id: "informed",
    label: "Informed flow",
    shortLabel: "Informed",
    eyebrow: "Price moves with the trader",
    thesis: "The post-trade move indicates adverse selection against LPs.",
    markoutDescription: "Adverse outcome",
    fixedFeeBps: 30,
    volatilityFeeBps: 48.0374,
    markoutFeeBps: 61.0552,
    rebateBps: 6.9448,
    protectionBps: 43.0552,
    markoutSignal: "+22 bps",
    verdict: "MARKOUT retains more only after the outcome shows that LPs supplied a valuable option.",
  },
  inventory: {
    id: "inventory",
    label: "Inventory-improving flow",
    shortLabel: "Inventory",
    eyebrow: "Trade helps rebalance the pool",
    thesis: "The market moves against the trader and the flow improves inventory.",
    markoutDescription: "Favorable LP outcome",
    fixedFeeBps: 30,
    volatilityFeeBps: 47.4403,
    markoutFeeBps: 18,
    rebateBps: 50,
    protectionBps: 0,
    markoutSignal: "−18 bps",
    verdict: "MARKOUT returns the complete provisional charge when the outcome is favorable to LPs.",
  },
};

export const flowOrder: FlowId[] = ["benign", "informed", "inventory"];

export const aggregateMetrics = [
  { value: "768", label: "seeded trades", detail: "six market regimes" },
  { value: "$1.999M", label: "volume per policy", detail: "identical trade tape" },
  { value: "+21.87%", label: "vs fixed fee", detail: "LP net after proxy" },
  { value: "0", label: "medium / high", detail: "Slither findings" },
];

export const policyResults = [
  { policy: "Fixed fee", lpNet: 3888.993116, effectiveFee: 30, tone: "muted" },
  { policy: "Volatility", lpNet: 7593.537628, effectiveFee: 48.5294, tone: "amber" },
  { policy: "MARKOUT", lpNet: 4739.648402, effectiveFee: 34.2548, tone: "green" },
] as const;

export const adoptionBreakEvens = [
  {
    flow: "Benign",
    vsFixed: "+$2.57",
    vsFixedLabel: "saved vs fixed per $10k",
    vsVolatility: "+$22.05",
    vsVolatilityLabel: "saved vs volatility per $10k",
    conclusion: "Wins the fee-only route at equal execution quality.",
  },
  {
    flow: "Inventory-improving",
    vsFixed: "+$12.00",
    vsFixedLabel: "saved vs fixed per $10k",
    vsVolatility: "+$29.44",
    vsVolatilityLabel: "saved vs volatility per $10k",
    conclusion: "Receives the full surcharge rebate and pays only the 18 bps base.",
  },
  {
    flow: "Informed",
    vsFixed: "−$31.06",
    vsFixedLabel: "trader saving vs fixed per $10k",
    vsVolatility: "−$13.02",
    vsVolatilityLabel: "trader saving vs volatility per $10k",
    conclusion: "Intentionally expensive: adverse flow funds LP protection.",
  },
] as const;

export const timelineBase = [
  {
    label: "Swap executes",
    detail: "Uniswap v4 collects a 50 bps provisional surcharge inside bounded hook accounting.",
    tag: "Unichain",
  },
  {
    label: "Outcome window",
    detail: "The immutable trade matures after five minutes. Reactive observes the request; early evidence still fails hook validation.",
    tag: "Hook",
  },
  {
    label: "Reference published",
    detail: "Pyth verifies one normalized price, timestamp, confidence, market, and trade-bound observation.",
    tag: "Ethereum + Pyth",
  },
  {
    label: "Reactive acts",
    detail: "The lifecycle engine requests an authenticated callback, while Circle remains a redundant proven delivery rail.",
    tag: "Reactive Network",
  },
] as const;

export const experimentCaveat =
  "The volatility baseline earned $2,853.89 more overall on this tape by charging benign and inventory-improving flow more. Fair-Flow accepts that trade-off to win good routes at equal execution.";
