# Phase 1 Verification Guide

This is the reproducible handoff for the Uniswap v4 accounting proof.

## One-command gate

From the repository root:

```bash
git submodule update --init --recursive
./scripts/verify-phase-1.sh
```

The script fails immediately if formatting, compilation, size reporting, lint, any test layer, or the gas snapshot fails.

## Expected automated evidence

| Layer | Expected result | What it proves |
| --- | --- | --- |
| Unit | 21 passing tests | strict payloads, bounded arithmetic, all delta resolutions |
| Accounting | 15 passing tests | real PoolManager custody, four quadrants, native currency, maximum guard, conservation |
| Stateful invariants | 3 passing invariants, zero handler reverts | backing and zero transient deltas over randomized swap sequences |
| Build size | deployed hook below EIP-170 limit | Phase 1 leaves substantial room for later lifecycle code |
| Lint | no findings | no known Forge lint finding is left unexplained |
| Deterministic gas snapshot | exact match | unexpected gas movement is review-visible without fuzz-seed noise |

The exact test count is a Phase 1 baseline. If tests are added later, the count may increase but must never decrease
without a documented reason.

The local profile runs 1,000 cases per fuzz test and 256 × 64 calls per invariant. CI raises those limits to 10,000
fuzz cases and 1,000 × 128 calls per invariant.

## Focused manual walkthrough

Run one exact-input and one exact-output integration test with full traces:

```bash
forge test \
  --match-test 'test_exact(Input_zeroForOne|Output_zeroForOne)_escrowsCurrency[01]' \
  -vvvv
```

Confirm these two paths in the output and assertions:

1. Exact input, currency0 → currency1: the hook's currency1 balance increases by the surcharge; the trader receives
   that much less output.
2. Exact output, currency0 → currency1: the hook's currency0 balance increases by the surcharge; the trader pays that
   much more input.
3. After each swap, `PoolManager.getNonzeroDeltaCount()` is zero and the hook/router currency deltas are zero.
4. The emitted amount, pool accounting, aggregate accounting, and hook balance increase are identical.

Then run the user-consent failure path:

```bash
forge test --match-test test_maximumBelowQuote_revertsWithoutAccrual -vvvv
```

Confirm the swap reverts and neither currency receives an accounting entry.

## Pass decision

Phase 1 passes only when:

- the one-command gate exits successfully from a clean recursive checkout;
- the focused walkthrough matches the accounting matrix;
- no dependency or gas snapshot change is unexplained; and
- the reviewer accepts the surcharge currency behavior for both amount modes.

Approval permits tagging the reviewed commit `phase-1-pass` and beginning Phase 2. It does not approve deployment with
real funds.
