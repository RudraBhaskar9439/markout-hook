import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

const developmentPreviewMeta =
  /<meta(?=[^>]*\bname=["']codex-preview["'])(?=[^>]*\bcontent=["']development["'])[^>]*>/i;
const templateRoot = new URL("../", import.meta.url);

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("server-renders the complete MARKOUT judge dashboard", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.doesNotMatch(html, developmentPreviewMeta);
  assert.match(html, /<title>MARKOUT - Outcome-priced liquidity<\/title>/i);
  assert.match(html, /Fees should follow/);
  assert.match(html, /Not fear\./);
  assert.match(html, /Make the swap\. Watch the fee change\./);
  assert.match(html, /Real v4 swap/);
  assert.match(html, /Onchain lifecycle/);
  assert.match(html, /Fee allocation/);
  assert.match(html, /Connect wallet/);
  assert.match(html, /Testnet only/);
  assert.match(html, /Same market\. Different information\./);
  assert.match(html, /The interface explains the trade\. The contracts decide it\./);
  assert.match(html, /Every terminal number is read from the deployed hook\./);
  assert.match(html, /Swap → mature → react → allocate/);
  assert.match(html, /Four planes\. One outcome-priced hook\./);
  assert.match(html, /Live autonomous cross-chain reaction/);
  assert.match(html, /Reactive makes verified evidence actionable\./);
  assert.match(html, /Live event-to-action rail/);
  assert.match(html, /Stateless Legacy adapter/);
  assert.match(html, /Exact publisher subscription/);
  assert.match(html, /Public Unichain callback/);
  assert.match(html, /11s · Verified/);
  assert.match(html, /Reactive-first settlement/);
  assert.match(html, /Relayer timeout/);
  assert.match(html, /0x253A29BfbbCECDeCE7a32ba98Bd12922Af4b9e5b/);
  assert.match(html, /0x5d933d5ff078c500c61fc32fef1ae526049085dad8e15ff4ef2673a971114459/);
  assert.match(html, /768 trades · \$1\.999M per policy/);
  assert.match(html, /SplitMix64 seed · 20260825/);
  assert.match(html, /40% lower fee/);
  assert.match(html, /The honest regression/);
  assert.match(html, /Four lifecycles\. Both settlement extremes\./);
  assert.match(html, /4<\/b> public end-to-end lifecycles/);
  assert.match(html, /3 \/ 1<\/b> full rebates \/ full retention/);
  assert.match(html, /Reactive Network callback publicly verified/);
  assert.match(html, /Four fallback lifecycles proven/);
  assert.match(html, /Reactive Network transport live/);
  assert.match(html, /Reactive-first settlement relayer timed out/);
  assert.match(html, /Good flow wins without assuming deeper liquidity\./);
  assert.match(html, /21\.87%/);
  assert.match(html, /benign flow saves \$2\.57/);
  assert.match(html, /18 bps base \+ refundable 50 bps surcharge/);
  assert.match(html, /both terminal extremes/);
  assert.match(html, /0xa64789b5a08ea8aae8c2b909b6a81b495334b707eaae12610bf3749902ec532f/);
  assert.match(html, /0xefeece5de9f78ae809652418e1fcd8fb592de950af64e6bbbf66df93bdc25eae/);
  assert.match(html, /0x81f7878312b81b80ba69ad8fdc0f4e06f64f8624ed610ebd5a6ea63cca0ca610/);
  assert.match(html, /0xd78f8533519c4468ac345f0caad52a8eb5c57ee904fc5882eb9066ee16b1b9d8/);
  assert.match(html, /0xb1bd16c88d71fbb737cbaa20ed9002dd7bd7098d1c17ac11ab3c7f9ed01c0c4d/);
  assert.match(html, /0x996ae7697b54ea67df0fbd3eb9ded1163d3a3df1d272bdcc7260ee18597b5f70/);
  assert.match(html, /aria-label="MARKOUT settlement receipt"/);
  assert.match(html, /aria-label="Choose an order-flow outcome"/);
  assert.match(html, /aria-labelledby="testnet-title"/);
  assert.doesNotMatch(html, /Codex/);
  assert.doesNotMatch(html, /react-loading-skeleton/);
});

test("removes starter metadata and keeps deterministic evidence explicit", async () => {
  const [page, layout, packageJson, data, testnet, consoleSource, css] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/demo-data.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/testnet/markout.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/components/LiveTestnetConsole.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
  ]);

  assert.match(page, /<MarkoutDashboard \/>/);
  assert.match(layout, /title:\s*"MARKOUT - Outcome-priced liquidity"/);
  assert.match(layout, /imageUrl = `\$\{origin\}\/og-evidence-v2\.png`/);
  assert.match(layout, /x-forwarded-host/);
  assert.doesNotMatch(layout, /codex-preview|_sites-preview|Starter Project/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
  assert.match(data, /fixedFeeBps:\s*30/);
  assert.match(data, /volatilityFeeBps:\s*49\.479/);
  assert.match(data, /markoutFeeBps:\s*61\.0552/);
  assert.match(data, /\+21\.87%/);
  assert.match(data, /saved vs fixed per \$10k/);
  assert.match(data, /\+\$22\.05/);
  assert.match(testnet, /0x3A17354331C21B246A9eC9BF979Af77e64f30044/);
  assert.match(testnet, /0xee2fba8ece79cbbf20bb44f861fae605b7caf5fa12883daa34811f54e753580d/);
  assert.match(testnet, /MARKOUT_BASE_FEE_BPS = 18/);
  assert.match(testnet, /MARKOUT_POOL_FEE = 1800/);
  assert.match(testnet, /https:\/\/ethereum-sepolia-rpc\.publicnode\.com/);
  assert.match(consoleSource, /Reactive Network event/);
  assert.match(consoleSource, /Publish Pyth event for Reactive Network/);
  assert.doesNotMatch(consoleSource, /Settle with Pyth \+ Circle|label: "Circle relayed"/);
  assert.match(css, /prefers-reduced-motion:\s*reduce/);
  assert.match(css, /\.plane-reactive/);
  assert.match(css, /\.frontend-stage-grid/);
  assert.match(css, /\.research-protocol/);
  assert.match(css, /\.reactive-proof-card/);

  await assert.rejects(
    access(new URL("app/_sites-preview", templateRoot)),
  );
});

test("keeps the authenticated Pyth request on the server", async () => {
  const [testnetLibrary, pythRoute] = await Promise.all([
    readFile(new URL("../app/lib/testnet/markout.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/pyth-update/route.ts", import.meta.url), "utf8"),
  ]);

  assert.match(testnetLibrary, /const PYTH_UPDATE_URL = "\/api\/pyth-update"/);
  assert.doesNotMatch(testnetLibrary, /PYTH_API_KEY|Authorization:\s*`Bearer/);
  assert.match(pythRoute, /process\.env\.PYTH_API_KEY/);
  assert.match(pythRoute, /Authorization:\s*`Bearer \$\{apiKey\}`/);
  assert.match(pythRoute, /pyth\.dourolabs\.app\/hermes/);
});

test("ships an exact-size social preview card", async () => {
  const image = await readFile(new URL("../public/og-evidence-v2.png", import.meta.url));

  assert.equal(image.toString("ascii", 1, 4), "PNG");
  assert.equal(image.readUInt32BE(16), 1200);
  assert.equal(image.readUInt32BE(20), 630);
});

test("keeps the judge projection synchronized with committed research artifacts", async () => {
  const [data, summary, sweep] = await Promise.all([
    readFile(new URL("../app/lib/demo-data.ts", import.meta.url), "utf8"),
    readFile(new URL("../../experiments/results/summary.json", import.meta.url), "utf8").then(JSON.parse),
    readFile(new URL("../../experiments/results/fair_flow_sweep.json", import.meta.url), "utf8").then(JSON.parse),
  ]);
  const markout = summary.aggregate.find((row) => row.policy === "markout");
  const byFlow = Object.fromEntries(
    summary.byFlowClass
      .filter((row) => row.policy === "markout")
      .map((row) => [row.flow_class, row]),
  );

  assert.equal(sweep.selected.base_fee_bps, 18);
  assert.match(data, new RegExp(`lpNet:\\s*${markout.lp_net_after_proxy_quote_micro / 1e6}`));
  assert.match(data, new RegExp(`effectiveFee:\\s*${Number(markout.average_effective_trader_fee_bps)}`));
  assert.match(data, new RegExp(`markoutFeeBps:\\s*${Number(byFlow.benign.average_effective_trader_fee_bps)}`));
  assert.match(data, new RegExp(`markoutFeeBps:\\s*${Number(byFlow.informed.average_effective_trader_fee_bps)}`));
  assert.match(data, new RegExp(`markoutFeeBps:\\s*${Number(byFlow.inventory_improving.average_effective_trader_fee_bps)}`));
});
