# Phase 3 Lifecycle and Accounting Specification

Status: implemented and covered by integration, fuzz, failure-path, and stateful invariant tests.

## Scope

Phase 3 joins the previously independent components:

- Phase 1 custody collects a bounded surcharge through Uniswap v4 custom accounting.
- Phase 2 pure mathematics validates an observation and divides one escrow into rebate and retention.
- `MarkoutHook` persists the trade, authenticates settlement, exposes expiry, and holds all live balances.

The local adapter models the authenticated boundary. Reactive Network replaces its operator-driven forwarding in Phase
4 without changing the hook's settlement target interface.

## Trade creation

Every nonzero surcharge creates one record with:

- a unique ID derived from chain ID, hook address, pool ID, and a monotonically increasing nonce;
- pool ID and rebate beneficiary;
- the actual surcharge currency and amount held by the hook;
- quote-per-base execution price at X18 precision;
- buy-base or sell-base direction;
- execution, maturity, and expiry timestamps; and
- `Pending` status.

Execution price uses the absolute base and quote amounts in the raw PoolManager swap delta. It excludes MARKOUT's own
return-delta surcharge, preventing the policy from measuring itself. A surcharge that rounds to zero creates no record
and consumes no nonce.

This hook instance accepts only its constructor-configured base/quote pair. Reversed token ordering is supported, but
an unrelated currency pair fails before any custody change.

## State machine

```text
                          valid authenticated observation
                     +------------------------------------+
                     |                                    v
swap + nonzero fee -> Pending                         Settled
                     |
                     | permissionless call after expiry
                     +------------------------------------>
                                                        Expired
```

`Settled` and `Expired` are terminal. A replay fails before accounting changes.

- Settlement is valid from maturity through the exact expiry timestamp, inclusive.
- Expiry becomes callable immediately after the settlement window ends.
- Expiry assigns the complete surcharge to the rebate beneficiary and assigns nothing to the LP reserve.

## Authentication

`MarkoutHook.settleTrade` accepts calls only from its immutable `settlementAuthority`. In Phase 3 that authority is a
`LocalMarkoutSettlementAdapter`:

- the adapter has one immutable operator;
- only that operator can forward observations;
- the destination can be bound once and can never be replaced; and
- the hook remains unaware of operator details.

This separation prevents Phase 4 from requiring changes to the trade or accounting model. The local operator is test
infrastructure, not the final trust model.

## Live balance accounting

Each held currency is in exactly one live accounting category:

```text
accounted balance = pending surcharge + claimable rebate + LP protection reserve
```

- `pending`: pool-scoped escrow waiting for an outcome;
- `claimable`: beneficiary-scoped user liability; and
- `LP protection reserve`: pool-scoped terminal retention.

Settlement performs only an internal reallocation. It does not transfer tokens. After every custody, settlement,
expiry, and claim transition, the hook verifies that its actual currency balance covers the complete accounted balance.
In a no-donation test environment, actual and accounted balances are exactly equal.

`totalAccruedSurcharge` remains the Phase 1 lifetime gross counter. It does not decrease on claims. Therefore:

```text
lifetime accrued = current accounted balance + cumulative claimed rebate
```

## Claims and transfer isolation

Rebates are pull payments. The recorded beneficiary chooses a nonzero recipient when self-claiming. A sponsor may pay
claim gas for another beneficiary, but that path forces the transfer to the beneficiary and exposes no recipient
choice. Both paths clear state before the external transfer and are reentrancy-guarded.

- ERC-20 claims use `SafeERC20`.
- Native claims use a checked low-level transfer.
- A failed transfer reverts only that claim and restores its credit.
- A contract that rejects native currency can redirect its claim to another address.
- Failed claims cannot block new swaps, settlements, expiries, or another beneficiary's claim.
- Sponsored claims cannot redirect value to the sponsor or any third party.

## Deliberate Phase 3 boundary

- The adapter still relies on a local operator; Reactive automation is Phase 4.
- The LP reserve is accounted and fully backed but cannot yet be withdrawn or reinvested.
- One hook instance supports one configured base/quote pair, though multiple fee-tier pools for that pair are valid.
- No production deployment or audit claim is made.
