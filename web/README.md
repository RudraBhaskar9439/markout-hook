# MARKOUT Judge Application

The judge application turns MARKOUT's mechanism and reproducible experiment into one guided browser story. It also
contains a wallet-safe console for running the deployed USDC/WETH pool end to end on Unichain Sepolia. It is a
Cloudflare Worker-compatible React application built with vinext and the Sites Vite plugin.

## Product boundary

- The comparison values come from the committed Phase 6 Fair-Flow experiment: an 18 bps base selected by
  declared constraints across a 10–30 bps sweep.
- The research timeline demonstrates the tested outcome-to-settlement lifecycle without simulating live network state.
- The separate testnet console reads balances and trades from the deployed hook, executes real v4 swaps, publishes a
  signed Pyth observation on Ethereum Sepolia, relays its Circle attestation, and reads the resulting fee allocation.
- The console is connected to the separately deployed 18 + 50 bps Fair-Flow pool and uses versioned browser storage
  so trade identifiers from the original hook cannot be loaded accidentally.
- The interface links four public Pyth/Circle lifecycles and three claimed rebates from the dated manifests.
- The public evidence contrasts both allocation extremes: three 100% rebates after negative markout and 100% retained
  for LP protection after positive markout.
- The architecture diagram and dedicated sponsor section foreground Reactive's exact subscription, autonomous callback
  intent, minimal payload, authenticated receiver, and order-independent race with Circle.
- Reactive remains visibly optional and is not labeled live without a public destination callback.
- Wallet signing uses the injected EIP-1193 provider. Private keys and Pyth credentials are never collected or bundled.
- Active trade and public transaction hashes are stored only in browser local storage so an interrupted relay can resume.
- There is no database, upload surface, server-side signer, or privileged protocol operation in this application.

## Local use

```bash
npm ci
npm run dev
```

Open `http://localhost:3000/#testnet` in Chrome with MetaMask or another injected wallet. The Codex in-app browser can
display the console but does not inject MetaMask.

For the complete live path:

1. Connect the funded deployment wallet and keep test ETH available on both Unichain Sepolia and Ethereum Sepolia.
2. Execute a small USDC → WETH or WETH → USDC swap. An ERC-20 approval appears only when required.
3. Wait for the immutable five-minute maturity countdown.
4. Choose **Settle with Pyth + Circle**, approve the Sepolia publication, wait for the attestation, and approve the
   Unichain relay when the wallet switches back.
5. Inspect the finalized effective fee, rebate, LP reserve, and explorer links. Claim a rebate when one is available.

The active console addresses are recorded in `../deployments/fair-flow-2026-08-22.json`; original opposite-branch
evidence remains in `../deployments/hybrid-2026-08-21.json`. Never use real funds: these contracts are experimental
and unaudited.

### MetaMask RPC recovery

If MetaMask reports `replacement transaction underpriced` before a transaction reaches the explorer, edit the
Unichain Sepolia network in MetaMask and use `https://unichain-sepolia-rpc.publicnode.com` as its RPC URL. The official
rate-limited testnet endpoint has intermittently returned a pending nonce older than confirmed state. The console checks
for that impossible condition before signing and will display both nonce values instead of submitting a doomed retry.

## Verification

```bash
npm run verify
cd ..
./scripts/verify-live-testnet-console.sh
```

The gate lints the TypeScript application, builds the Cloudflare-compatible output, verifies server-rendered product
content and starter removal, and rejects high-severity production dependency advisories.

The repository-level live-console gate additionally confirms the deployed Unichain chain and bytecode, performs a
read-only simulation of the exact v4 swap call from the funded test account, and validates the current Pyth response.
It never broadcasts a transaction and does not require a private key.

The development-only vinext tool currently inherits two `image-size` parser advisories. MARKOUT has no image upload or
untrusted image-processing path; the package is excluded from the deployed dependency audit and is used only to compile
repository-owned assets. See `../docs/PHASE_8_VERIFICATION.md` for the exact boundary.
