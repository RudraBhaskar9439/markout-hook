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
  assert.match(html, /<title>MARKOUT — Outcome-priced liquidity<\/title>/i);
  assert.match(html, /Fees should follow/);
  assert.match(html, /Not fear\./);
  assert.match(html, /Same market\. Different information\./);
  assert.match(html, /Outcome → observation → settlement/);
  assert.match(html, /The honest regression/);
  assert.match(html, /Live Lasna evidence pending lREACT/);
  assert.match(html, /aria-label="MARKOUT settlement receipt"/);
  assert.match(html, /aria-label="Choose an order-flow outcome"/);
  assert.doesNotMatch(html, /Codex/);
  assert.doesNotMatch(html, /react-loading-skeleton/);
});

test("removes starter metadata and keeps deterministic evidence explicit", async () => {
  const [page, layout, packageJson, data, css] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/demo-data.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
  ]);

  assert.match(page, /<MarkoutDashboard \/>/);
  assert.match(layout, /title:\s*"MARKOUT — Outcome-priced liquidity"/);
  assert.match(layout, /imageUrl = `\$\{origin\}\/og\.png`/);
  assert.match(layout, /x-forwarded-host/);
  assert.doesNotMatch(layout, /codex-preview|_sites-preview|Starter Project/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
  assert.match(data, /fixedFeeBps:\s*30/);
  assert.match(data, /volatilityFeeBps:\s*49\.479/);
  assert.match(data, /markoutFeeBps:\s*73\.0552/);
  assert.match(data, /\+\$3,249\.79/);
  assert.match(css, /prefers-reduced-motion:\s*reduce/);

  await assert.rejects(
    access(new URL("app/_sites-preview", templateRoot)),
  );
});

test("ships an exact-size social preview card", async () => {
  const image = await readFile(new URL("../public/og.png", import.meta.url));

  assert.equal(image.toString("ascii", 1, 4), "PNG");
  assert.equal(image.readUInt32BE(16), 1200);
  assert.equal(image.readUInt32BE(20), 630);
});
