const PYTH_ETH_USD_PRICE_ID =
  "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace";
const HERMES_PRICE_URL = "https://pyth.dourolabs.app/hermes/v2/updates/price/latest";

export const dynamic = "force-dynamic";

type HermesPrice = {
  price: string;
  conf: string;
  expo: number;
  publish_time: number;
};

type HermesPayload = {
  parsed?: Array<{
    id?: string;
    price?: HermesPrice;
    ema_price?: HermesPrice;
  }>;
};

function jsonError(message: string, status: number) {
  return Response.json(
    { error: message },
    {
      status,
      headers: { "Cache-Control": "no-store" },
    },
  );
}

function scaledValue(value: string, exponent: number, allowZero = false) {
  const parsed = Number(value);
  const scaled = parsed * 10 ** exponent;
  if (!Number.isFinite(scaled) || (allowZero ? scaled < 0 : scaled <= 0)) {
    throw new Error("Pyth returned an invalid ETH/USD value.");
  }
  return scaled;
}

export async function GET() {
  const apiKey = process.env.PYTH_API_KEY?.trim();
  if (!apiKey) {
    return jsonError("Live Pyth pricing is not configured on this deployment.", 503);
  }

  const url = new URL(HERMES_PRICE_URL);
  url.searchParams.append("ids[]", PYTH_ETH_USD_PRICE_ID);
  url.searchParams.set("parsed", "true");

  try {
    const response = await fetch(url, {
      cache: "no-store",
      headers: { Authorization: `Bearer ${apiKey}` },
    });

    if (!response.ok) {
      const message = response.status === 401 || response.status === 403
        ? "Pyth rejected the configured server credential."
        : response.status === 429
          ? "The Pyth live-price limit was reached. Retrying shortly."
          : `Pyth Hermes returned HTTP ${response.status}.`;
      return jsonError(message, response.status === 429 ? 429 : 502);
    }

    const payload = await response.json() as HermesPayload;
    const feed = payload.parsed?.[0];
    if (!feed?.price) {
      return jsonError("Pyth returned no parsed ETH/USD observation.", 502);
    }

    const price = scaledValue(feed.price.price, feed.price.expo);
    const confidence = scaledValue(feed.price.conf, feed.price.expo, true);
    const emaPrice = feed.ema_price
      ? scaledValue(feed.ema_price.price, feed.ema_price.expo)
      : null;

    return Response.json(
      {
        symbol: "ETH/USD",
        feedId: feed.id
          ? feed.id.startsWith("0x") ? feed.id : `0x${feed.id}`
          : PYTH_ETH_USD_PRICE_ID,
        price,
        confidence,
        confidenceBps: (confidence / price) * 10_000,
        emaPrice,
        publishTime: feed.price.publish_time,
        receivedAt: Math.floor(Date.now() / 1_000),
        source: "Pyth Hermes",
      },
      {
        headers: { "Cache-Control": "no-store" },
      },
    );
  } catch (error) {
    const message = error instanceof Error && error.message.startsWith("Pyth returned")
      ? error.message
      : "Pyth Hermes could not be reached. Retrying shortly.";
    return jsonError(message, 502);
  }
}
