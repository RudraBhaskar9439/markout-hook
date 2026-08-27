const PYTH_ETH_USD_PRICE_ID =
  "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace";
const HERMES_PRICE_URL = "https://pyth.dourolabs.app/hermes/v2/updates/price/latest";

export const dynamic = "force-dynamic";

function jsonError(message: string, status: number) {
  return Response.json(
    { error: message },
    {
      status,
      headers: { "Cache-Control": "no-store" },
    },
  );
}

export async function GET() {
  const apiKey = process.env.PYTH_API_KEY?.trim();
  if (!apiKey) {
    return jsonError(
      "Pyth settlement is not configured on this deployment. Add the server-only PYTH_API_KEY and retry.",
      503,
    );
  }

  const url = new URL(HERMES_PRICE_URL);
  url.searchParams.append("ids[]", PYTH_ETH_USD_PRICE_ID);
  url.searchParams.set("encoding", "hex");
  url.searchParams.set("parsed", "true");

  try {
    const response = await fetch(url, {
      cache: "no-store",
      headers: { Authorization: `Bearer ${apiKey}` },
    });

    if (!response.ok) {
      const message = response.status === 401 || response.status === 403
        ? "Pyth rejected the configured API key. Replace PYTH_API_KEY and retry."
        : `Pyth Hermes returned HTTP ${response.status}.`;
      return jsonError(message, response.status === 429 ? 429 : 502);
    }

    return Response.json(await response.json(), {
      headers: { "Cache-Control": "no-store" },
    });
  } catch {
    return jsonError("Pyth Hermes could not be reached. Retry the settlement in a moment.", 502);
  }
}
