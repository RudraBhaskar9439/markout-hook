# Phase 14 Verification — Hybrid Deployment and Release Candidate

Phase 14 packages the Circle-primary, Reactive-optional topology for public testnet deployment. Local automation is
complete; public broadcasts remain an owner-controlled gate because they require a private key, testnet balances,
irreversible address confirmation, and a Pyth API credential.

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
running the full 212-test Solidity suite.

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
3. One real Unichain swap with a recorded trade id.
4. One matured Pyth-verified publisher transaction.
5. Circle status `complete`, a mined Unichain relay, and a settled hook trade.
6. A mined rebate claim and a dated evidence manifest containing every explorer link.
7. Measured Circle latency that fits the ten-minute settlement window.

The optional Reactive pulse passes its separate live gate only with a successful legacy Lasna deployment,
subscription evidence, and a public Unichain callback. A generic Anvil fork cannot emulate Reactive's chain-specific
subscription precompile and is not accepted as registration evidence.

## GO / NO-GO

**GO** for owner-controlled deployment using the runbook and for judge rehearsal using deterministic local evidence.
**NO-GO** for the `uhi10-final` tag, public live-settlement claims, or final form submission until the required Circle
transactions and claim are recorded and reverified.
