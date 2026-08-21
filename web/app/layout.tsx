import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { headers } from "next/headers";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const fallbackOrigin = "http://localhost:3000";
const safeHost = /^[a-z0-9.-]+(?::\d{1,5})?$/i;

async function getRequestOrigin(): Promise<string> {
  const requestHeaders = await headers();
  const forwardedHost = requestHeaders.get("x-forwarded-host")?.split(",")[0]?.trim();
  const host = forwardedHost || requestHeaders.get("host")?.trim();

  if (!host || !safeHost.test(host)) return fallbackOrigin;

  const forwardedProtocol = requestHeaders.get("x-forwarded-proto")?.split(",")[0]?.trim();
  const isLocal = host.startsWith("localhost") || host.startsWith("127.0.0.1");
  const protocol =
    forwardedProtocol === "http" || forwardedProtocol === "https"
      ? forwardedProtocol
      : isLocal
        ? "http"
        : "https";

  return `${protocol}://${host}`;
}

export async function generateMetadata(): Promise<Metadata> {
  const origin = await getRequestOrigin();
  const imageUrl = `${origin}/og.png`;

  return {
    metadataBase: new URL(origin),
    title: "MARKOUT — Outcome-priced liquidity",
    description:
      "A Uniswap v4 hook that uses post-trade markout to rebate good flow and protect LPs from adverse selection.",
    applicationName: "MARKOUT",
    keywords: ["Uniswap v4", "Reactive Network", "MEV protection", "dynamic fees", "markout"],
    alternates: { canonical: origin },
    openGraph: {
      title: "MARKOUT — Fees should follow outcomes, not fear.",
      description: "Outcome-priced liquidity for Uniswap v4 with Circle-primary, Reactive-optional settlement.",
      type: "website",
      url: origin,
      images: [{ url: imageUrl, width: 1200, height: 630, alt: "MARKOUT outcome-priced liquidity" }],
    },
    twitter: {
      card: "summary_large_image",
      title: "MARKOUT — Outcome-priced liquidity",
      description: "Fees should follow outcomes, not fear.",
      images: [imageUrl],
    },
  };
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
