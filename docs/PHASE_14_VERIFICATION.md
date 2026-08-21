# Phase 14 Verification — Hybrid Deployment and Release Candidate

Phase 14 packages and proves the Circle-primary, Reactive-optional topology on public testnets. The required Circle
path is complete; repository/site visibility and final submission remain owner-controlled decisions.

## Local automated gate

```bash
./scripts/verify-phase-14-local.sh
```

This checks formatting, bytecode sizes, Circle and Reactive-pulse tests, shell syntax, deployment-manifest JSON,
network chain locks, funded-pulse protection, active-runbook labeling, and whitespace.

Run the complete release candidate from a clean tree with:

```bash
./scripts/verify-hybrid-release-candidate.sh
```

The cumulative command repeats the Phase 1–13 protocol, research, security, dashboard, and presentation gates before
running the full 186-test Solidity suite.

## Read-only public-network preflight

After setting a reliable Ethereum Sepolia endpoint:

```bash
./scripts/check-hybrid-networks.sh
```

This verifies chain IDs and bytecode for Uniswap v4, Circle CCTP V2, Pyth, the Unichain Reactive callback proxy, and
legacy Lasna's system contract. When deployed-address variables exist, it also checks immutable market, publisher,
identity, coordinator, hook-authority, and pulse wiring.

## Public acceptance gate

Follow [Hybrid Testnet Deployment](HYBRID_TESTNET_DEPLOYMENT.md) and require all of the following:

1. Mined Sepolia publisher deployment and irreversible destination binding.
2. Mined Unichain coordinator, receivers, permission-mined hook, and pool initialization.
3. Real Unichain swaps with recorded trade ids for both economic branches.
4. Matured Pyth-verified publisher transactions for both trades.
5. Circle status `complete`, mined Unichain relays, and settled hook trades.
6. A mined rebate claim, reconciled LP-protection reserve, and a dated evidence manifest containing every explorer link.
7. Measured Circle latency that fits the ten-minute settlement window for both observations.

The optional Reactive pulse passes its separate live gate only with a successful legacy Lasna deployment,
subscription evidence, and a public Unichain callback. A generic Anvil fork cannot emulate Reactive's chain-specific
subscription precompile and is not accepted as registration evidence.

The required gate passed on August 21, 2026. The
[dated deployment manifest](../deployments/hybrid-2026-08-21.json) records the public addresses and transactions,
including a claimed `622`-unit test-USDC rebate, 38-second source-to-destination latency, and a later valid Circle
delivery handled as an idempotent no-op. A second public trade proves the opposite allocation branch: a 67-second
Circle relay settled positive markout and retained all `3,214,110,616,342` test-WETH base units for LP protection,
with the hook's reserve, accounted balance, and actual balance equal.

A third browser-wallet lifecycle independently reproduced the rebate branch: the real v4 swap, Pyth publication,
67-second Circle relay, −266.96 bps settlement, and rebate claim all mined publicly. The observation was 92 seconds
old at settlement, inside the 120-second freshness bound. This raises the recorded public lifecycle count to three
without changing the two demonstrated economic extremes.

With reliable Ethereum Sepolia and Unichain Sepolia endpoints configured, revalidate every recorded transaction,
deployed contract, settled trade value, and zero post-claim balance directly from both chains:

```bash
./scripts/verify-public-circle-evidence.sh
```

## GO / NO-GO

**GO** for the public Circle-settlement claim: the dated manifest records three swaps and complete observation paths,
38/67/67-second relays, opposite settlement branches, two rebate claims, LP reserve reconciliation, and idempotent
duplicate delivery.
**NO-GO** for a public Reactive-delivery claim until a callback is visible on Unichain, and for final form submission
until the project owner supplies the remaining details.
