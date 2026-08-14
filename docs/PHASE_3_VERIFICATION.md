# Phase 3 Verification Guide

Phase 3 proves the complete local MARKOUT lifecycle: swap, escrow, pending record, authorized outcome settlement,
rebate claim, LP reserve credit, and liveness-preserving expiry.

## One-command cumulative gate

From the repository root:

```bash
./scripts/verify-phase-3.sh
```

The gate checks formatting, a clean rebuild with deployed-bytecode sizes, lint, all Phase 1–3 behavioral suites,
deterministic economics, stateful invariants, the judge-readable demo, and the committed gas snapshot.

Expected result: every suite passes, invariant output reports zero reverts, and `forge snapshot --check` reports no
difference.

## Focused commands

```bash
# Local adapter permissions and one-time binding
forge test --match-path 'test/unit/LocalMarkoutSettlementAdapter.t.sol' -vv

# End-to-end lifecycle and failure behavior
forge test --match-path 'test/lifecycle/**' -vv

# Stateful balance, allocation, claim, and PoolManager invariants
forge test --match-contract MarkoutLifecycleInvariantTest -vv

# Human-readable two-trade acceptance scenario
./scripts/run-phase-3-demo.sh
```

## Manual acceptance scenario

The demo executes two buy-base swaps with the same input parameters:

1. The neutral trade settles at its own execution price and retains 20%.
2. The toxic trade settles after a 30-bps trader-favorable move and retains 100%.
3. The neutral rebate is strictly greater than the toxic rebate.
4. Pending becomes zero.
5. Hook balance equals claimable rebates plus the LP protection reserve exactly.

The script prints both trade IDs, execution and reference prices, escrow, rebate, retention, and aggregate balances.

## Local hook deployment

`script/DeployMarkoutHook.s.sol` deploys the local adapter, mines a permission-correct v4 hook address, deploys the hook
through the canonical CREATE2 deployer, and binds the adapter once. Configure a local Anvil environment or another
development RPC with:

```bash
cp .env.example .env
# Fill only local/development values in .env, then load them into your shell.
source .env

forge script script/DeployMarkoutHook.s.sol:DeployMarkoutHook \
  --rpc-url "$RPC_URL" \
  --broadcast \
  -vv
```

Never commit `.env` or a private key. Pool initialization is intentionally separate from hook deployment because the
PoolManager and asset addresses belong to the selected environment.

## Properties covered

- all four exact-input/exact-output and direction combinations create correct records;
- execution direction and surcharge currency match v4 deltas;
- unauthorized direct and adapter settlement fail;
- terminal states cannot be replayed;
- maturity, exact-expiry, and post-expiry boundaries are enforced;
- settlement and expiry conserve every escrow exactly;
- rebates and LP reserves remain fully collateralized;
- native-transfer failure cannot block unrelated settlement or claims;
- zero-surcharge rounding creates no phantom trade;
- supported fuzz inputs traverse all swap and terminal paths without loss; and
- PoolManager transient deltas are zero after every stateful action.

## Expected Phase 3 limitations

The operator-driven adapter is replaced by the Reactive event and callback implementation in Phase 4. Reserve
deployment, governance, emergency controls, static analysis, and external review remain explicitly scheduled for later
gates.
