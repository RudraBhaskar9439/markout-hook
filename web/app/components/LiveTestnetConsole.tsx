"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { getAddress, isAddress, isHex, type Address, type Hash, type Hex } from "viem";
import {
  MARKOUT_CONTRACTS,
  MARKOUT_BASE_FEE_BPS,
  claimTestnetRebate,
  connectInjectedWallet,
  executeTestnetSwap,
  expireTestnetTrade,
  fetchCircleAttestation,
  formatTokenAmount,
  formatWalletBalance,
  getInjectedProvider,
  publishTestnetObservation,
  readTradeSnapshot,
  readWalletSnapshot,
  readableError,
  relayCircleAttestation,
  type PublishedObservation,
  type SwapDirection,
  type SwapResult,
  type TradeSnapshot,
  type TransactionResult,
  type WalletSnapshot,
} from "../lib/testnet/markout";

const ACTIVE_TRADE_KEY = "markout.fairFlow.activeTradeId";
const PUBLISH_HASH_KEY = "markout.fairFlow.publishHash";
const EMPTY_BALANCES: WalletSnapshot = {
  eth: 0n,
  usdc: 0n,
  weth: 0n,
  usdcAllowance: 0n,
  wethAllowance: 0n,
  usdcPending: 0n,
  wethPending: 0n,
  usdcReserve: 0n,
  wethReserve: 0n,
};

const statusLabels = ["Unknown", "Pending", "Settled", "Expired"] as const;

function compact(value: string, left = 6, right = 4) {
  return `${value.slice(0, left)}…${value.slice(-right)}`;
}

function formatTimestamp(timestamp: number) {
  if (!timestamp) return "-";
  return new Intl.DateTimeFormat(undefined, {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).format(new Date(timestamp * 1000));
}

function relativeTime(target: number, now: number) {
  const difference = target - now;
  const absolute = Math.abs(difference);
  const minutes = Math.floor(absolute / 60);
  const seconds = absolute % 60;
  const time = `${minutes}:${seconds.toString().padStart(2, "0")}`;
  return difference > 0 ? `in ${time}` : `${time} ago`;
}

function transactionLink(result: TransactionResult | null, label: string) {
  if (!result) return null;
  return <a href={result.explorerUrl} target="_blank" rel="noreferrer">{label} ↗</a>;
}

export function LiveTestnetConsole() {
  const [hasWallet, setHasWallet] = useState<boolean | null>(null);
  const [account, setAccount] = useState<Address | null>(null);
  const [balances, setBalances] = useState<WalletSnapshot>(EMPTY_BALANCES);
  const [direction, setDirection] = useState<SwapDirection>("USDC_TO_WETH");
  const [amount, setAmount] = useState("1");
  const [tradeId, setTradeId] = useState<Hex | null>(null);
  const [tradeIdInput, setTradeIdInput] = useState("");
  const [trade, setTrade] = useState<TradeSnapshot | null>(null);
  const [swapResult, setSwapResult] = useState<SwapResult | null>(null);
  const [publishResult, setPublishResult] = useState<PublishedObservation | null>(null);
  const [relayResult, setRelayResult] = useState<TransactionResult | null>(null);
  const [claimResult, setClaimResult] = useState<TransactionResult | null>(null);
  const [publishHash, setPublishHash] = useState<Hash | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));

  const refresh = useCallback(async (wallet: Address | null = account, activeTrade: Hex | null = tradeId) => {
    const tasks: Promise<void>[] = [];
    if (wallet) {
      tasks.push(readWalletSnapshot(wallet).then(setBalances));
    }
    if (activeTrade) {
      tasks.push(readTradeSnapshot(activeTrade).then(setTrade));
    }
    await Promise.all(tasks);
  }, [account, tradeId]);

  useEffect(() => {
    const provider = getInjectedProvider();
    const hydrateTimer = window.setTimeout(() => {
      setHasWallet(Boolean(provider));
      const storedTrade = window.localStorage.getItem(ACTIVE_TRADE_KEY);
      const storedPublish = window.localStorage.getItem(PUBLISH_HASH_KEY);
      if (storedTrade && isHex(storedTrade, { strict: true }) && storedTrade.length === 66) {
        setTradeId(storedTrade as Hex);
        setTradeIdInput(storedTrade);
      }
      if (storedPublish && isHex(storedPublish, { strict: true }) && storedPublish.length === 66) {
        setPublishHash(storedPublish as Hash);
      }
    }, 0);
    if (!provider) return;
    const handleAccountsChanged = (...arguments_: unknown[]) => {
      const accounts = arguments_[0];
      if (Array.isArray(accounts) && typeof accounts[0] === "string" && isAddress(accounts[0])) {
        setAccount(getAddress(accounts[0]));
      } else {
        setAccount(null);
      }
    };
    provider.on?.("accountsChanged", handleAccountsChanged);
    provider.request({ method: "eth_accounts" }).then((accounts) => {
      if (Array.isArray(accounts) && typeof accounts[0] === "string" && isAddress(accounts[0])) {
        setAccount(getAddress(accounts[0]));
      }
    }).catch(() => undefined);
    return () => {
      window.clearTimeout(hydrateTimer);
      provider.removeListener?.("accountsChanged", handleAccountsChanged);
    };
  }, []);

  useEffect(() => {
    const timer = window.setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1_000);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    if (!account && !tradeId) return;
    refresh().catch((reason) => setError(readableError(reason)));
    const timer = window.setInterval(() => {
      refresh().catch(() => undefined);
    }, 6_000);
    return () => window.clearInterval(timer);
  }, [account, tradeId, refresh]);

  const maturityReached = Boolean(trade && now >= trade.maturityTimestamp);
  const expiryReached = Boolean(trade && now > trade.expiryTimestamp);
  const feeBps = trade?.status === 2 || trade?.status === 3
    ? MARKOUT_BASE_FEE_BPS + (50 * trade.settlement.retentionBps) / 10_000
    : null;
  const escrowCurrency = trade?.currency ?? MARKOUT_CONTRACTS.usdc;
  const displayedPending = escrowCurrency.toLowerCase() === MARKOUT_CONTRACTS.usdc.toLowerCase()
    ? balances.usdcPending
    : balances.wethPending;
  const displayedReserve = escrowCurrency.toLowerCase() === MARKOUT_CONTRACTS.usdc.toLowerCase()
    ? balances.usdcReserve
    : balances.wethReserve;

  const settlementSteps = useMemo(() => {
    const hasTrade = Boolean(trade && trade.status > 0);
    const isMature = Boolean(hasTrade && maturityReached);
    const hasPublish = Boolean(publishHash);
    const terminal = Boolean(trade && trade.status >= 2);
    return [
      { label: "Swap mined", reached: hasTrade, detail: hasTrade ? formatTimestamp(trade!.executedAt) : "Waiting" },
      { label: "5-minute markout", reached: isMature, detail: trade ? relativeTime(trade.maturityTimestamp, now) : "Waiting" },
      { label: "Pyth evidence published", reached: hasPublish, detail: hasPublish ? "Ethereum Sepolia" : "Waiting" },
      {
        label: "Reactive subscription eligible",
        reached: hasPublish,
        detail: hasPublish ? "Publisher event available" : "Waiting",
      },
      { label: "Fee finalized", reached: terminal, detail: terminal && feeBps !== null ? `${feeBps.toFixed(2)} bps effective` : "Waiting" },
    ];
  }, [feeBps, maturityReached, now, publishHash, trade]);

  async function connect() {
    const provider = getInjectedProvider();
    if (!provider) {
      setError("Install a browser wallet such as MetaMask to run the live testnet flow.");
      return;
    }
    setBusy("Connecting wallet");
    setError(null);
    try {
      const connected = await connectInjectedWallet(provider);
      setAccount(connected);
      await refresh(connected, tradeId);
      setNotice("Wallet connected. Transactions remain in your wallet for approval.");
    } catch (reason) {
      setError(readableError(reason));
    } finally {
      setBusy(null);
    }
  }

  function changeDirection(nextDirection: SwapDirection) {
    setDirection(nextDirection);
    setAmount(nextDirection === "USDC_TO_WETH" ? "1" : "0.0003");
  }

  async function runSwap() {
    const provider = getInjectedProvider();
    if (!provider || !account) {
      await connect();
      return;
    }
    setBusy("Confirm the Unichain swap in your wallet");
    setError(null);
    setNotice(null);
    try {
      const result = await executeTestnetSwap(provider, account, direction, amount);
      setSwapResult(result);
      setTradeId(result.tradeId);
      setTradeIdInput(result.tradeId);
      setPublishHash(null);
      setPublishResult(null);
      setRelayResult(null);
      setClaimResult(null);
      window.localStorage.setItem(ACTIVE_TRADE_KEY, result.tradeId);
      window.localStorage.removeItem(PUBLISH_HASH_KEY);
      await refresh(account, result.tradeId);
      setNotice("Real v4 swap mined. The 50 bps provisional amount is now visible in hook escrow.");
    } catch (reason) {
      setError(readableError(reason));
    } finally {
      setBusy(null);
    }
  }

  async function waitForCircle(hash: Hash) {
    for (let attempt = 1; attempt <= 60; attempt += 1) {
      setBusy(`Waiting for independent fallback · ${attempt * 2}s`);
      const attestation = await fetchCircleAttestation(hash);
      if (attestation) return attestation;
      await new Promise((resolve) => window.setTimeout(resolve, 2_000));
    }
    throw new Error("The independent fallback is still processing. Resume settlement in a moment.");
  }

  async function settleWithCircle() {
    const provider = getInjectedProvider();
    if (!provider || !account || !tradeId || !trade) {
      setError("Connect the wallet and execute or load a trade first.");
      return;
    }
    if (trade.status !== 1) {
      setError("This trade is already in a terminal state.");
      return;
    }
    if (!maturityReached) {
      setError(`The observation must wait for maturity ${relativeTime(trade.maturityTimestamp, now)}.`);
      return;
    }
    setError(null);
    setNotice(null);
    try {
      let hash = publishHash;
      if (!hash) {
        setBusy("Confirm the Pyth publication on Ethereum Sepolia");
        const publication = await publishTestnetObservation(provider, account, tradeId);
        setPublishResult(publication);
        hash = publication.hash;
        setPublishHash(hash);
        window.localStorage.setItem(PUBLISH_HASH_KEY, hash);
      }
      const attestation = await waitForCircle(hash);
      setBusy("Confirm fallback settlement on Unichain Sepolia");
      const relay = await relayCircleAttestation(provider, account, attestation);
      setRelayResult(relay);
      await refresh(account, tradeId);
      setNotice("The observation was delivered and the hook finalized the fee allocation onchain.");
    } catch (reason) {
      setError(readableError(reason));
    } finally {
      setBusy(null);
    }
  }

  function discardPublication() {
    setPublishHash(null);
    setPublishResult(null);
    window.localStorage.removeItem(PUBLISH_HASH_KEY);
    setError(null);
    setNotice("The previous publication was discarded. Start settlement again to publish a fresh observation.");
  }

  async function claim() {
    const provider = getInjectedProvider();
    if (!provider || !account || !trade) return;
    setBusy("Confirm the rebate claim on Unichain");
    setError(null);
    try {
      const result = await claimTestnetRebate(provider, account, trade.currency);
      setClaimResult(result);
      await refresh(account, tradeId);
      setNotice("The claimable rebate was transferred to your wallet.");
    } catch (reason) {
      setError(readableError(reason));
    } finally {
      setBusy(null);
    }
  }

  async function expire() {
    const provider = getInjectedProvider();
    if (!provider || !account || !tradeId) return;
    setBusy("Confirm the safe-expiry transaction on Unichain");
    setError(null);
    try {
      const result = await expireTestnetTrade(provider, account, tradeId);
      setRelayResult(result);
      await refresh(account, tradeId);
      setNotice("The stale trade expired safely and its complete provisional charge became claimable.");
    } catch (reason) {
      setError(readableError(reason));
    } finally {
      setBusy(null);
    }
  }

  async function loadTrade() {
    if (!isHex(tradeIdInput, { strict: true }) || tradeIdInput.length !== 66) {
      setError("Enter a complete 32-byte trade ID.");
      return;
    }
    const nextTradeId = tradeIdInput as Hex;
    setBusy("Reading trade from Unichain");
    setError(null);
    try {
      const snapshot = await readTradeSnapshot(nextTradeId);
      if (snapshot.status === 0) throw new Error("That trade ID does not exist on the deployed hook.");
      setTradeId(nextTradeId);
      setTrade(snapshot);
      setPublishHash(null);
      setPublishResult(null);
      setRelayResult(null);
      window.localStorage.setItem(ACTIVE_TRADE_KEY, nextTradeId);
      window.localStorage.removeItem(PUBLISH_HASH_KEY);
      setNotice("Trade loaded directly from the deployed hook.");
    } catch (reason) {
      setError(readableError(reason));
    } finally {
      setBusy(null);
    }
  }

  return (
    <section className="testnet-section" id="testnet" aria-labelledby="testnet-title">
      <div className="section-heading testnet-heading">
        <div>
          <p className="kicker">Live testnet console</p>
          <h2 id="testnet-title">Make the swap. Watch the fee change.</h2>
          <p className="section-lede">
            This is the deployed USDC/WETH Uniswap v4 pool on Unichain Sepolia - not a simulation. Your wallet signs
            every transaction; no private key enters this page. Reactive Network watches the canonical evidence event,
            while an independent fallback keeps the live demonstration recoverable.
          </p>
        </div>
        <div className="wallet-control">
          <span className="network-chip"><i /> Unichain Sepolia · 1301</span>
          <button type="button" className="wallet-button" onClick={connect} disabled={Boolean(busy)}>
            {account ? compact(account) : hasWallet === false ? "Wallet not found" : "Connect wallet"}
          </button>
        </div>
      </div>

      <div className="testnet-balance-row" aria-label="Connected testnet balances">
        <div><span>Gas</span><strong>{formatWalletBalance("ETH", balances.eth)} ETH</strong></div>
        <div><span>Spendable</span><strong>{formatWalletBalance("USDC", balances.usdc)} USDC</strong></div>
        <div><span>Spendable</span><strong>{formatWalletBalance("WETH", balances.weth)} WETH</strong></div>
        <div><span>Pool pending</span><strong>{formatTokenAmount(displayedPending, escrowCurrency)}</strong></div>
        <div><span>LP reserve</span><strong>{formatTokenAmount(displayedReserve, escrowCurrency)}</strong></div>
        <button type="button" className="icon-button" onClick={() => refresh()} disabled={Boolean(busy)} aria-label="Refresh onchain balances">↻</button>
      </div>

      <div className="testnet-console-grid">
        <article className="testnet-card swap-card">
          <div className="testnet-card-number">01</div>
          <p className="kicker">Execute</p>
          <h3>Real v4 swap</h3>
          <label className="field-label" htmlFor="swap-direction">Direction</label>
          <select
            id="swap-direction"
            value={direction}
            onChange={(event) => changeDirection(event.target.value as SwapDirection)}
            disabled={Boolean(busy)}
          >
            <option value="USDC_TO_WETH">USDC → WETH</option>
            <option value="WETH_TO_USDC">WETH → USDC</option>
          </select>
          <label className="field-label" htmlFor="swap-amount">Exact input</label>
          <div className="amount-field">
            <input
              id="swap-amount"
              inputMode="decimal"
              value={amount}
              onChange={(event) => setAmount(event.target.value)}
              disabled={Boolean(busy)}
            />
            <span>{direction === "USDC_TO_WETH" ? "USDC" : "WETH"}</span>
          </div>
          <div className="fee-preview">
            <span><b>18 bps</b> pool fee</span>
            <span>+</span>
            <span><b>50 bps</b> provisional</span>
          </div>
          <button type="button" className="primary-action testnet-action" onClick={runSwap} disabled={Boolean(busy)}>
            {busy?.includes("swap") ? busy : account ? "Execute testnet swap" : "Connect to begin"}
          </button>
          <small className="card-footnote">Approval appears first only when the selected token allowance is insufficient.</small>
        </article>

        <article className="testnet-card lifecycle-card">
          <div className="testnet-card-number">02</div>
          <p className="kicker">Observe</p>
          <h3>Onchain lifecycle</h3>
          <div className="live-steps">
            {settlementSteps.map((step, index) => (
              <div className="live-step" data-reached={step.reached} key={step.label}>
                <span>{index + 1}</span>
                <div><strong>{step.label}</strong><small>{step.detail}</small></div>
              </div>
            ))}
          </div>
          {trade && trade.status === 1 && !maturityReached && (
            <div className="countdown-panel">
              <span>Observation unlocks</span>
              <strong>{relativeTime(trade.maturityTimestamp, now)}</strong>
            </div>
          )}
          {trade && trade.status === 1 && maturityReached && !expiryReached && (
            <>
              <button type="button" className="primary-action testnet-action" onClick={settleWithCircle} disabled={Boolean(busy)}>
                {busy ?? (publishHash ? "Complete independent fallback" : "Publish evidence + settle safely")}
              </button>
              <small className="card-footnote">
                Publishing creates the canonical event consumed by Reactive Network. This wallet demo then uses the
                independently authenticated fallback for deterministic completion; it does not claim a Reactive callback.
              </small>
              {publishHash && !busy && (
                <button type="button" className="discard-publication" onClick={discardPublication}>
                  Discard stale publication
                </button>
              )}
            </>
          )}
          {trade && trade.status === 1 && expiryReached && (
            <button type="button" className="secondary-testnet-action" onClick={expire} disabled={Boolean(busy)}>
              Expire safely + unlock full rebate
            </button>
          )}
          {!trade && <p className="empty-state">Execute a swap or load an existing trade to start the live timeline.</p>}
        </article>

        <article className="testnet-card result-card">
          <div className="testnet-card-number">03</div>
          <p className="kicker">Verify</p>
          <h3>Fee allocation</h3>
          <div className="live-fee-result" data-terminal={Boolean(trade && trade.status >= 2)}>
            <span>Final effective fee</span>
            <strong>{feeBps === null ? "Pending" : `${feeBps.toFixed(2)} bps`}</strong>
            <small>{trade ? statusLabels[trade.status] ?? "Unknown" : "No active trade"}</small>
          </div>
          <div className="live-allocation">
            <div>
              <span>Escrowed</span>
              <strong>{trade ? formatTokenAmount(trade.escrowedSurcharge, trade.currency) : "-"}</strong>
            </div>
            <div>
              <span>Returned</span>
              <strong>{trade && trade.status >= 2 ? formatTokenAmount(trade.settlement.rebate, trade.currency) : "-"}</strong>
            </div>
            <div>
              <span>LP protection</span>
              <strong>{trade && trade.status >= 2 ? formatTokenAmount(trade.settlement.retainedSurcharge, trade.currency) : "-"}</strong>
            </div>
            <div>
              <span>Directional markout</span>
              <strong>{trade && trade.status === 2 ? `${(Number(trade.settlement.markoutWad) / 1e14).toFixed(2)} bps` : "-"}</strong>
            </div>
          </div>
          {trade && trade.claimable > 0n && trade.rebateRecipient.toLowerCase() === account?.toLowerCase() && (
            <button type="button" className="primary-action testnet-action" onClick={claim} disabled={Boolean(busy)}>
              Claim {formatTokenAmount(trade.claimable, trade.currency)}
            </button>
          )}
          <div className="transaction-links">
            {transactionLink(swapResult, "Swap")}
            {transactionLink(publishResult, "Pyth publish")}
            {transactionLink(relayResult, "Fallback settlement")}
            {transactionLink(claimResult, "Rebate claim")}
          </div>
        </article>
      </div>

      <div className="trade-loader">
        <div>
          <span className="field-label">Active trade ID</span>
          <code>{tradeId ? compact(tradeId, 12, 10) : "No trade selected"}</code>
        </div>
        <div className="trade-loader-form">
          <input
            aria-label="Existing MARKOUT trade ID"
            placeholder="0x… load any deployed-hook trade"
            value={tradeIdInput}
            onChange={(event) => setTradeIdInput(event.target.value)}
          />
          <button type="button" onClick={loadTrade} disabled={Boolean(busy)}>Load trade</button>
        </div>
        {tradeId && <a href={`https://sepolia.uniscan.xyz/address/${MARKOUT_CONTRACTS.hook}`} target="_blank" rel="noreferrer">Inspect hook ↗</a>}
      </div>

      {busy && <div className="console-notice console-working"><i /> {busy}</div>}
      {notice && !busy && <div className="console-notice console-success"><i /> {notice}</div>}
      {error && <div className="console-notice console-error" role="alert"><i /> {error}</div>}
      <p className="testnet-disclaimer">Testnet only · contracts are experimental and unaudited · Pyth ETH/USD assumes test USDC ≈ $1.</p>
    </section>
  );
}
