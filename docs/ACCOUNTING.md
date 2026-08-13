# Phase 1 Accounting Specification

Status: implemented and tested on `phase/1-accounting`.

## Purpose

Phase 1 proves one narrow but critical claim: a Uniswap v4 hook can collect a bounded provisional surcharge without
leaving unsettled PoolManager deltas or breaking conservation. Markout scoring and rebate settlement deliberately remain
outside this phase.

## Swap accounting matrix

`afterSwapReturnDelta` adjusts the unspecified side of a v4 swap. MARKOUT resolves that side from `amountSpecified` and
`zeroForOne` instead of duplicating four custom code paths.

| Swap mode | Direction | Specified currency | Surcharge currency | Trader effect |
| --- | --- | --- | --- | --- |
| Exact input | currency0 → currency1 | currency0 input | currency1 output | receives less currency1 |
| Exact input | currency1 → currency0 | currency1 input | currency0 output | receives less currency0 |
| Exact output | currency0 → currency1 | currency1 output | currency0 input | pays more currency0 |
| Exact output | currency1 → currency0 | currency0 output | currency1 input | pays more currency1 |

For every row:

```text
basis = abs(raw PoolManager delta on the unspecified side)
surcharge = floor(basis × surchargeBps / 10_000)
```

The Phase 1 policy caps deployment at 1,000 bps (10%). Each user also declares an absolute maximum amount for their
individual swap. If `surcharge > maximumAmount`, the entire swap reverts. Integrating routers must pass the
swapper-approved hook payload unchanged.

## Hook data contract

The canonical payload is exactly:

```solidity
abi.encode(rebateRecipient, maximumAmount)
```

where `rebateRecipient` is a non-zero `address` and `maximumAmount` is `uint128`. The decoder requires a 64-byte ABI
payload and rejects non-canonical high bits. Strict decoding prevents multiple byte representations of the same
authorization and makes future signing or routing integrations safer.

`rebateRecipient` is recorded now but does not receive a transfer in Phase 1. Phase 3 will use it when creating the
pending settlement record.

## PoolManager settlement sequence

Within `afterSwap`:

1. Decode and validate user authorization.
2. Resolve the unspecified currency and pre-hook amount.
3. Ask the replaceable policy for a surcharge quote.
4. Enforce the user's absolute maximum and the v4 `int128` return-delta bound.
5. Call `PoolManager.take(currency, hook, surcharge)` to transfer custody to the hook.
6. Record pool-level and aggregate currency accruals.
7. Return the same positive amount as the hook delta so PoolManager cancels the hook's transient debt.

The transaction is atomic. If any later assertion or PoolManager settlement fails, the transfer and storage writes
revert with the swap.

## Safety invariants

The Phase 1 suite checks:

- only the configured PoolManager can invoke the external hook callback;
- each of the four swap quadrants selects the correct surcharge currency;
- the hook receives exactly the emitted and recorded surcharge;
- aggregate token movement across trader, router, PoolManager, and hook is conserved;
- PoolManager finishes with zero non-zero deltas for the hook and router;
- per-pool accounting remains separated while per-currency accounting aggregates correctly;
- native currency custody follows the same accounting rule;
- direct native transfers are rejected; only the configured PoolManager may use the receive path;
- malformed hook data, a zero recipient, excess rates, and excess user charges revert without accrual;
- stateful randomized sequences keep every accounted currency fully backed.

## Intentional Phase 1 limits

- No pending trade state, markout formula, Reactive callback, rebate claim, or LP reserve release exists yet.
- `totalAccruedSurcharge` describes Phase 1 custody, not finalized economic ownership.
- The fixed-BPS policy exists to exercise the accounting primitive; it is not MARKOUT's final fee curve.
- No claim is made that the code is audited or safe for real funds.

## Extension boundary

Future policies derive from `BaseProvisionalSurcharge` and implement `_quoteSurcharge`. Phase 3 can override
`_afterSurchargeAccrued` to create the pending MARKOUT record after custody and core accounting are established. This
keeps lifecycle logic out of the PoolManager settlement primitive.
