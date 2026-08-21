import {
  BaseError,
  createPublicClient,
  createWalletClient,
  custom,
  defineChain,
  formatEther,
  formatUnits,
  getAddress,
  http,
  maxUint128,
  parseAbi,
  parseEventLogs,
  parseUnits,
  type Address,
  type Chain,
  type EIP1193Provider,
  type Hash,
  type Hex,
} from "viem";
import { sepolia } from "viem/chains";

export const unichainSepolia = defineChain({
  id: 1301,
  name: "Unichain Sepolia",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://sepolia.unichain.org"] },
  },
  blockExplorers: {
    default: { name: "Uniscan", url: "https://sepolia.uniscan.xyz" },
  },
  testnet: true,
});

export const MARKOUT_CONTRACTS = {
  hook: getAddress("0x2981693161ebbeaf10e91d6ddfc2ed810e80c044"),
  poolSwapRouter: getAddress("0x9140a78c1a137c7ff1c151ec8231272af78a99a4"),
  usdc: getAddress("0x31d0220469e10c4E71834a79b1f276d740d3768F"),
  weth: getAddress("0x4200000000000000000000000000000000000006"),
  circlePublisher: getAddress("0xb3d2403a028849292326668ab41ed25f0f049976"),
  pyth: getAddress("0xDd24F84d36BF92C65F92307595335bdFab5Bbd21"),
  circleMessageTransmitter: getAddress("0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275"),
} as const;

export const MARKOUT_POOL_ID =
  "0x9e5a4fc0cc370e9a999c34828a0331fb548fd75897fb0a3de9db9a4902160348" as const;
export const PYTH_ETH_USD_PRICE_ID =
  "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace" as const;

const HERMES_PRICE_URL = "https://hermes.pyth.network/v2/updates/price/latest";
const CIRCLE_MESSAGES_URL = "https://iris-api-sandbox.circle.com/v2/messages/0";
const MIN_SQRT_PRICE_PLUS_ONE = 4_295_128_740n;
const MAX_SQRT_PRICE_MINUS_ONE = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341n;
const APPROVAL_GAS_LIMIT = 100_000n;
const SWAP_GAS_LIMIT = 700_000n;
const PYTH_PUBLICATION_GAS_LIMIT = 500_000n;
const CIRCLE_RELAY_GAS_LIMIT = 1_200_000n;
const CLAIM_GAS_LIMIT = 250_000n;
const EXPIRY_GAS_LIMIT = 300_000n;

const erc20Abi = parseAbi([
  "function balanceOf(address account) view returns (uint256)",
  "function allowance(address owner,address spender) view returns (uint256)",
  "function approve(address spender,uint256 amount) returns (bool)",
]);

const swapRouterAbi = parseAbi([
  "function swap((address currency0,address currency1,uint24 fee,int24 tickSpacing,address hooks) key,(bool zeroForOne,int256 amountSpecified,uint160 sqrtPriceLimitX96) params,(bool takeClaims,bool settleUsingBurn) testSettings,bytes hookData) payable returns (int256 delta)",
]);

const markoutAbi = parseAbi([
  "event MarkoutRequested(bytes32 indexed tradeId,bytes32 indexed poolId,address indexed rebateRecipient,address currency,uint128 escrowedSurcharge,uint192 executionPriceX18,uint64 executedAt,uint64 maturityTimestamp,uint64 expiryTimestamp,uint8 direction)",
  "event MarkoutSettled(bytes32 indexed tradeId,address indexed rebateRecipient,address indexed currency,int256 markoutWad,uint16 retentionBps,uint128 retainedSurcharge,uint128 rebate,uint192 referencePriceX18,uint64 observedAt,uint16 confidenceBps)",
  "function getTrade(bytes32 tradeId) view returns ((bytes32 poolId,address rebateRecipient,address currency,uint192 executionPriceX18,uint128 escrowedSurcharge,uint64 executedAt,uint64 maturityTimestamp,uint64 expiryTimestamp,uint8 direction,uint8 status) trade)",
  "function getTradeSettlement(bytes32 tradeId) view returns ((int256 markoutWad,uint192 referencePriceX18,uint128 retainedSurcharge,uint128 rebate,uint64 observedAt,uint16 confidenceBps,uint16 retentionBps) settlement)",
  "function claimableRebate(address beneficiary,address currency) view returns (uint256)",
  "function lpProtectionReserve(bytes32 poolId,address currency) view returns (uint256)",
  "function poolPendingSurcharge(bytes32 poolId,address currency) view returns (uint256)",
  "function expireTrade(bytes32 tradeId)",
  "function claimRebate(address currency,address recipient) returns (uint256 amount)",
]);

const pythAbi = parseAbi(["function getUpdateFee(bytes[] updateData) view returns (uint256 feeAmount)"]);
const publisherAbi = parseAbi([
  "function publish(bytes32 tradeId,bytes[] updateData) payable returns ((uint192 priceX18,uint64 observedAt,uint16 confidenceBps) observation)",
]);
const circleTransmitterAbi = parseAbi([
  "function receiveMessage(bytes message,bytes attestation) returns (bool success)",
]);

export type SwapDirection = "USDC_TO_WETH" | "WETH_TO_USDC";

export type WalletSnapshot = {
  eth: bigint;
  usdc: bigint;
  weth: bigint;
  usdcAllowance: bigint;
  wethAllowance: bigint;
  usdcPending: bigint;
  wethPending: bigint;
  usdcReserve: bigint;
  wethReserve: bigint;
};

export type TradeSnapshot = {
  tradeId: Hex;
  poolId: Hex;
  rebateRecipient: Address;
  currency: Address;
  executionPriceX18: bigint;
  escrowedSurcharge: bigint;
  executedAt: number;
  maturityTimestamp: number;
  expiryTimestamp: number;
  direction: number;
  status: number;
  settlement: {
    markoutWad: bigint;
    referencePriceX18: bigint;
    retainedSurcharge: bigint;
    rebate: bigint;
    observedAt: number;
    confidenceBps: number;
    retentionBps: number;
  };
  claimable: bigint;
};

export type TransactionResult = {
  hash: Hash;
  explorerUrl: string;
};

export type SwapResult = TransactionResult & {
  approvalHash?: Hash;
  tradeId: Hex;
};

export type PublishedObservation = TransactionResult & {
  pythPublishTime: number;
  pythPrice: string;
};

export type CircleAttestation = {
  message: Hex;
  attestation: Hex;
  finality: number;
};

type EthereumProvider = EIP1193Provider & {
  on?: (event: string, listener: (...args: unknown[]) => void) => void;
  removeListener?: (event: string, listener: (...args: unknown[]) => void) => void;
};

const unichainClient = createPublicClient({ chain: unichainSepolia, transport: http() });
const sepoliaClient = createPublicClient({ chain: sepolia, transport: http() });

function explorerTransaction(chain: Chain, hash: Hash) {
  return `${chain.blockExplorers?.default.url}/tx/${hash}`;
}

function walletClient(provider: EthereumProvider, chain: Chain, account: Address) {
  return createWalletClient({ account, chain, transport: custom(provider) });
}

async function safeWalletNonce(
  client: typeof unichainClient | typeof sepoliaClient,
  account: Address,
) {
  const [confirmedNonce, pendingNonce] = await Promise.all([
    client.getTransactionCount({ address: account, blockTag: "latest" }),
    client.getTransactionCount({ address: account, blockTag: "pending" }),
  ]);
  // Some testnet RPCs can expose a stale pending nonce. Never sign below confirmed state,
  // while still respecting a legitimate pending transaction when it is ahead.
  return Math.max(confirmedNonce, pendingNonce);
}

function ensureHexBytes(value: unknown, field: string): Hex {
  if (typeof value !== "string" || !/^0x(?:[0-9a-fA-F]{2})+$/.test(value)) {
    throw new Error(`${field} was not valid hexadecimal bytes.`);
  }
  return value as Hex;
}

export function getInjectedProvider(): EthereumProvider | null {
  if (typeof window === "undefined") return null;
  return (window as typeof window & { ethereum?: EthereumProvider }).ethereum ?? null;
}

export async function connectInjectedWallet(provider: EthereumProvider): Promise<Address> {
  const accounts = await provider.request({ method: "eth_requestAccounts" });
  if (!Array.isArray(accounts) || typeof accounts[0] !== "string") {
    throw new Error("The wallet did not return an account.");
  }
  return getAddress(accounts[0]);
}

export async function switchWalletNetwork(provider: EthereumProvider, chain: Chain) {
  const chainId = `0x${chain.id.toString(16)}`;
  try {
    await provider.request({ method: "wallet_switchEthereumChain", params: [{ chainId }] });
  } catch (error) {
    const code = (error as { code?: number }).code;
    if (code !== 4902) throw error;
    await provider.request({
      method: "wallet_addEthereumChain",
      params: [
        {
          chainId,
          chainName: chain.name,
          nativeCurrency: chain.nativeCurrency,
          rpcUrls: chain.rpcUrls.default.http,
          blockExplorerUrls: chain.blockExplorers ? [chain.blockExplorers.default.url] : undefined,
        },
      ],
    });
  }
}

export async function readWalletSnapshot(account: Address): Promise<WalletSnapshot> {
  const [eth, usdc, weth, usdcAllowance, wethAllowance, usdcPending, wethPending, usdcReserve, wethReserve] =
    await Promise.all([
      unichainClient.getBalance({ address: account }),
      unichainClient.readContract({ address: MARKOUT_CONTRACTS.usdc, abi: erc20Abi, functionName: "balanceOf", args: [account] }),
      unichainClient.readContract({ address: MARKOUT_CONTRACTS.weth, abi: erc20Abi, functionName: "balanceOf", args: [account] }),
      unichainClient.readContract({ address: MARKOUT_CONTRACTS.usdc, abi: erc20Abi, functionName: "allowance", args: [account, MARKOUT_CONTRACTS.poolSwapRouter] }),
      unichainClient.readContract({ address: MARKOUT_CONTRACTS.weth, abi: erc20Abi, functionName: "allowance", args: [account, MARKOUT_CONTRACTS.poolSwapRouter] }),
      unichainClient.readContract({ address: MARKOUT_CONTRACTS.hook, abi: markoutAbi, functionName: "poolPendingSurcharge", args: [MARKOUT_POOL_ID, MARKOUT_CONTRACTS.usdc] }),
      unichainClient.readContract({ address: MARKOUT_CONTRACTS.hook, abi: markoutAbi, functionName: "poolPendingSurcharge", args: [MARKOUT_POOL_ID, MARKOUT_CONTRACTS.weth] }),
      unichainClient.readContract({ address: MARKOUT_CONTRACTS.hook, abi: markoutAbi, functionName: "lpProtectionReserve", args: [MARKOUT_POOL_ID, MARKOUT_CONTRACTS.usdc] }),
      unichainClient.readContract({ address: MARKOUT_CONTRACTS.hook, abi: markoutAbi, functionName: "lpProtectionReserve", args: [MARKOUT_POOL_ID, MARKOUT_CONTRACTS.weth] }),
    ]);
  return { eth, usdc, weth, usdcAllowance, wethAllowance, usdcPending, wethPending, usdcReserve, wethReserve };
}

export async function readTradeSnapshot(tradeId: Hex): Promise<TradeSnapshot> {
  const trade = await unichainClient.readContract({
    address: MARKOUT_CONTRACTS.hook,
    abi: markoutAbi,
    functionName: "getTrade",
    args: [tradeId],
  });
  const [settlement, claimable] = await Promise.all([
    unichainClient.readContract({
      address: MARKOUT_CONTRACTS.hook,
      abi: markoutAbi,
      functionName: "getTradeSettlement",
      args: [tradeId],
    }),
    unichainClient.readContract({
      address: MARKOUT_CONTRACTS.hook,
      abi: markoutAbi,
      functionName: "claimableRebate",
      args: [trade.rebateRecipient, trade.currency],
    }),
  ]);
  return {
    tradeId,
    poolId: trade.poolId,
    rebateRecipient: trade.rebateRecipient,
    currency: trade.currency,
    executionPriceX18: trade.executionPriceX18,
    escrowedSurcharge: trade.escrowedSurcharge,
    executedAt: Number(trade.executedAt),
    maturityTimestamp: Number(trade.maturityTimestamp),
    expiryTimestamp: Number(trade.expiryTimestamp),
    direction: trade.direction,
    status: trade.status,
    settlement: {
      markoutWad: settlement.markoutWad,
      referencePriceX18: settlement.referencePriceX18,
      retainedSurcharge: settlement.retainedSurcharge,
      rebate: settlement.rebate,
      observedAt: Number(settlement.observedAt),
      confidenceBps: settlement.confidenceBps,
      retentionBps: settlement.retentionBps,
    },
    claimable,
  };
}

export async function executeTestnetSwap(
  provider: EthereumProvider,
  account: Address,
  direction: SwapDirection,
  amount: string,
): Promise<SwapResult> {
  await switchWalletNetwork(provider, unichainSepolia);
  const input = direction === "USDC_TO_WETH"
    ? { address: MARKOUT_CONTRACTS.usdc, decimals: 6 }
    : { address: MARKOUT_CONTRACTS.weth, decimals: 18 };
  const amountSpecified = parseUnits(amount, input.decimals);
  if (amountSpecified <= 0n) throw new Error("Enter an amount greater than zero.");

  const [balance, allowance] = await Promise.all([
    unichainClient.readContract({ address: input.address, abi: erc20Abi, functionName: "balanceOf", args: [account] }),
    unichainClient.readContract({ address: input.address, abi: erc20Abi, functionName: "allowance", args: [account, MARKOUT_CONTRACTS.poolSwapRouter] }),
  ]);
  if (balance < amountSpecified) throw new Error("The connected wallet does not have enough test tokens for this swap.");

  const wallet = walletClient(provider, unichainSepolia, account);
  let approvalHash: Hash | undefined;
  if (allowance < amountSpecified) {
    const nonce = await safeWalletNonce(unichainClient, account);
    approvalHash = await wallet.writeContract({
      address: input.address,
      abi: erc20Abi,
      functionName: "approve",
      args: [MARKOUT_CONTRACTS.poolSwapRouter, amountSpecified],
      gas: APPROVAL_GAS_LIMIT,
      nonce,
    });
    const approvalReceipt = await unichainClient.waitForTransactionReceipt({ hash: approvalHash });
    if (approvalReceipt.status !== "success") throw new Error("Token approval reverted.");
  }

  const zeroForOne = direction === "USDC_TO_WETH";
  const hookData = (`0x${account.slice(2).padStart(64, "0")}${maxUint128.toString(16).padStart(64, "0")}`) as Hex;
  const nonce = await safeWalletNonce(unichainClient, account);
  const hash = await wallet.writeContract({
    address: MARKOUT_CONTRACTS.poolSwapRouter,
    abi: swapRouterAbi,
    functionName: "swap",
    args: [
      {
        currency0: MARKOUT_CONTRACTS.usdc,
        currency1: MARKOUT_CONTRACTS.weth,
        fee: 3000,
        tickSpacing: 60,
        hooks: MARKOUT_CONTRACTS.hook,
      },
      {
        zeroForOne,
        amountSpecified: -amountSpecified,
        sqrtPriceLimitX96: zeroForOne ? MIN_SQRT_PRICE_PLUS_ONE : MAX_SQRT_PRICE_MINUS_ONE,
      },
      { takeClaims: false, settleUsingBurn: false },
      hookData,
    ],
    gas: SWAP_GAS_LIMIT,
    nonce,
  });
  const receipt = await unichainClient.waitForTransactionReceipt({ hash });
  if (receipt.status !== "success") throw new Error("The Uniswap v4 swap reverted.");
  const requested = parseEventLogs({ abi: markoutAbi, eventName: "MarkoutRequested", logs: receipt.logs, strict: false })
    .find((log) => log.address.toLowerCase() === MARKOUT_CONTRACTS.hook.toLowerCase());
  if (!requested) throw new Error("The swap succeeded, but its MARKOUT trade event was not found.");

  return {
    approvalHash,
    hash,
    tradeId: requested.args.tradeId,
    explorerUrl: explorerTransaction(unichainSepolia, hash),
  };
}

async function fetchFreshPythUpdate() {
  const url = new URL(HERMES_PRICE_URL);
  url.searchParams.append("ids[]", PYTH_ETH_USD_PRICE_ID);
  url.searchParams.set("encoding", "hex");
  url.searchParams.set("parsed", "true");
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) throw new Error(`Pyth Hermes returned HTTP ${response.status}.`);
  const payload = await response.json() as {
    binary?: { data?: unknown[] };
    parsed?: Array<{ price?: { publish_time?: unknown; price?: unknown } }>;
  };
  const rawUpdate = payload.binary?.data?.[0];
  const updateData = ensureHexBytes(typeof rawUpdate === "string" ? `0x${rawUpdate.replace(/^0x/, "")}` : rawUpdate, "Pyth update");
  const publishTime = Number(payload.parsed?.[0]?.price?.publish_time);
  const price = String(payload.parsed?.[0]?.price?.price ?? "");
  if (!Number.isSafeInteger(publishTime) || publishTime <= 0 || !price) {
    throw new Error("Pyth Hermes returned an incomplete price update.");
  }
  return { updateData, publishTime, price };
}

export async function publishTestnetObservation(
  provider: EthereumProvider,
  account: Address,
  tradeId: Hex,
): Promise<PublishedObservation> {
  await switchWalletNetwork(provider, sepolia);
  const { updateData, publishTime, price } = await fetchFreshPythUpdate();
  const updateFee = await sepoliaClient.readContract({
    address: MARKOUT_CONTRACTS.pyth,
    abi: pythAbi,
    functionName: "getUpdateFee",
    args: [[updateData]],
  });
  const wallet = walletClient(provider, sepolia, account);
  const nonce = await safeWalletNonce(sepoliaClient, account);
  const hash = await wallet.writeContract({
    address: MARKOUT_CONTRACTS.circlePublisher,
    abi: publisherAbi,
    functionName: "publish",
    args: [tradeId, [updateData]],
    value: updateFee,
    gas: PYTH_PUBLICATION_GAS_LIMIT,
    nonce,
  });
  const receipt = await sepoliaClient.waitForTransactionReceipt({ hash });
  if (receipt.status !== "success") throw new Error("The Pyth observation publication reverted.");
  return { hash, explorerUrl: explorerTransaction(sepolia, hash), pythPublishTime: publishTime, pythPrice: price };
}

export async function fetchCircleAttestation(publishHash: Hash): Promise<CircleAttestation | null> {
  const url = new URL(CIRCLE_MESSAGES_URL);
  url.searchParams.set("transactionHash", publishHash);
  const response = await fetch(url, { cache: "no-store" });
  if (response.status === 404) return null;
  if (!response.ok) throw new Error(`Circle returned HTTP ${response.status}.`);
  const payload = await response.json() as {
    messages?: Array<{
      status?: unknown;
      message?: unknown;
      attestation?: unknown;
      cctpVersion?: unknown;
      version?: unknown;
      decodedMessage?: { destinationDomain?: unknown; finalityThresholdExecuted?: unknown };
    }>;
  };
  const entry = payload.messages?.[0];
  if (!entry || entry.status !== "complete") return null;
  if (Number(entry.cctpVersion ?? entry.version) !== 2) throw new Error("Circle returned an unexpected CCTP version.");
  if (Number(entry.decodedMessage?.destinationDomain) !== 10) throw new Error("Circle returned the wrong destination domain.");
  const finality = Number(entry.decodedMessage?.finalityThresholdExecuted);
  if (!Number.isSafeInteger(finality) || finality < 1000) throw new Error("Circle attestation finality was below 1000.");
  return {
    message: ensureHexBytes(entry.message, "Circle message"),
    attestation: ensureHexBytes(entry.attestation, "Circle attestation"),
    finality,
  };
}

export async function relayCircleAttestation(
  provider: EthereumProvider,
  account: Address,
  attestation: CircleAttestation,
): Promise<TransactionResult> {
  await switchWalletNetwork(provider, unichainSepolia);
  const wallet = walletClient(provider, unichainSepolia, account);
  const nonce = await safeWalletNonce(unichainClient, account);
  const hash = await wallet.writeContract({
    address: MARKOUT_CONTRACTS.circleMessageTransmitter,
    abi: circleTransmitterAbi,
    functionName: "receiveMessage",
    args: [attestation.message, attestation.attestation],
    gas: CIRCLE_RELAY_GAS_LIMIT,
    nonce,
  });
  const receipt = await unichainClient.waitForTransactionReceipt({ hash });
  if (receipt.status !== "success") throw new Error("The Circle relay reverted on Unichain.");
  return { hash, explorerUrl: explorerTransaction(unichainSepolia, hash) };
}

export async function claimTestnetRebate(
  provider: EthereumProvider,
  account: Address,
  currency: Address,
): Promise<TransactionResult> {
  await switchWalletNetwork(provider, unichainSepolia);
  const wallet = walletClient(provider, unichainSepolia, account);
  const nonce = await safeWalletNonce(unichainClient, account);
  const hash = await wallet.writeContract({
    address: MARKOUT_CONTRACTS.hook,
    abi: markoutAbi,
    functionName: "claimRebate",
    args: [currency, account],
    gas: CLAIM_GAS_LIMIT,
    nonce,
  });
  const receipt = await unichainClient.waitForTransactionReceipt({ hash });
  if (receipt.status !== "success") throw new Error("The rebate claim reverted.");
  return { hash, explorerUrl: explorerTransaction(unichainSepolia, hash) };
}

export async function expireTestnetTrade(
  provider: EthereumProvider,
  account: Address,
  tradeId: Hex,
): Promise<TransactionResult> {
  await switchWalletNetwork(provider, unichainSepolia);
  const wallet = walletClient(provider, unichainSepolia, account);
  const nonce = await safeWalletNonce(unichainClient, account);
  const hash = await wallet.writeContract({
    address: MARKOUT_CONTRACTS.hook,
    abi: markoutAbi,
    functionName: "expireTrade",
    args: [tradeId],
    gas: EXPIRY_GAS_LIMIT,
    nonce,
  });
  const receipt = await unichainClient.waitForTransactionReceipt({ hash });
  if (receipt.status !== "success") throw new Error("The expiry transaction reverted.");
  return { hash, explorerUrl: explorerTransaction(unichainSepolia, hash) };
}

export function formatTokenAmount(amount: bigint, currency: Address) {
  return currency.toLowerCase() === MARKOUT_CONTRACTS.usdc.toLowerCase()
    ? `${Number(formatUnits(amount, 6)).toLocaleString(undefined, { maximumFractionDigits: 6 })} USDC`
    : `${Number(formatUnits(amount, 18)).toLocaleString(undefined, { maximumFractionDigits: 8 })} WETH`;
}

export function formatWalletBalance(symbol: "ETH" | "USDC" | "WETH", amount: bigint) {
  const formatted = symbol === "ETH" ? formatEther(amount) : formatUnits(amount, symbol === "USDC" ? 6 : 18);
  return Number(formatted).toLocaleString(undefined, { maximumFractionDigits: symbol === "USDC" ? 4 : 6 });
}

export function readableError(error: unknown) {
  if (error instanceof BaseError) return error.shortMessage;
  if (error instanceof Error) return error.message;
  return "The wallet operation failed.";
}
