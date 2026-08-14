# Phase 2 Economic Specification

Status: frozen for the UHI10 MVP and implemented as pure Solidity.

## Objective

MARKOUT does not attempt to identify malicious addresses. It measures whether the reference market moved in the
trader's direction after execution, then uses that outcome as a bounded proxy for LP adverse selection.

## Canonical prices

All prices use:

```text
priceX18 = quote-token units per one base token × 1e18
```

For an ETH/USDC pool, ETH is base and USDC is quote. A $2,000 ETH price is `2000e18`. `PriceNormalization` supports:

- raw quote-per-base sources with 0–36 decimals;
- raw base-per-quote sources through deterministic inversion;
- executed base and quote token amounts with independent token decimals.

Scaling, division, and inversion round down. Zero inputs, values erased by precision loss, unsupported decimals, and
normalized values above `uint192` fail explicitly.

## Directional markout

```text
q = +1 for BUY_BASE
q = -1 for SELL_BASE

markoutWad = q × (referencePriceX18 - executionPriceX18) × 1e18 / executionPriceX18
```

- positive: the market moved in the trader's direction, adverse to the LP under this proxy;
- zero: neutral;
- negative: the market moved against the trader, inventory-improving or benign under this proxy.

Equivalent percentage moves for buys and sells produce identical directional markout.

## Retention curve

Let `m` be `markoutWad`, `F = 5e14` (-5 bps magnitude), `A = 25e14` (+25 bps), `rMin = 0`, and `r0 = 2,000`.

```text
m <= -F       retentionBps = rMin
-F < m < 0    retentionBps = rMin + floor((r0 - rMin) × (m + F) / F)
0 <= m < A    retentionBps = r0 + floor((10,000 - r0) × m / A)
m >= A        retentionBps = 10,000
```

Settlement is:

```text
retained = floor(escrow × retentionBps / 10,000)
rebate = escrow - retained
```

The subtraction makes conservation exact, and any indivisible remainder benefits the trader rebate.

## Reference observation policy

| Rule | MVP value |
| --- | ---: |
| Maturity delay | 5 minutes after execution |
| Settlement grace | 10 minutes after maturity |
| Maximum observation age | 2 minutes at evaluation |
| Minimum normalized confidence | 9,000 / 10,000 |

An eligible observation must be at or after maturity, at or before evaluation, fresh, non-zero, and sufficiently
confident. Evaluation before maturity or after the grace period fails.

The confidence value is not invented by the hook. A source adapter must deterministically map the selected oracle's
native validity and confidence information to 0–10,000. Phase 4 must document that mapping and authenticate the source.

## Expiry

If the trade has not settled when the grace period elapses, it becomes expired. Phase 3 will make 100% of its escrow
claimable as a trader rebate. There is no LP allocation without a valid observation.

## Deterministic scenarios

With execution price `2000e18` and escrow `1,000` units:

| Scenario | Direction | Reference | Markout | Retain rate | Retained | Rebate |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Inventory-improving buy | Buy base | 1998 | -10 bps | 0% | 0 | 1,000 |
| Neutral buy | Buy base | 2000 | 0 bps | 20% | 200 | 800 |
| Mild adverse buy | Buy base | 2002 | +10 bps | 52% | 520 | 480 |
| Toxic buy | Buy base | 2006 | +30 bps | 100% | 1,000 | 0 |
| Inventory-improving sell | Sell base | 2002 | -10 bps | 0% | 0 | 1,000 |
| Neutral sell | Sell base | 2000 | 0 bps | 20% | 200 | 800 |
| Mild adverse sell | Sell base | 1998 | +10 bps | 52% | 520 | 480 |
| Toxic sell | Sell base | 1994 | +30 bps | 100% | 1,000 | 0 |

The machine-readable source is `test/fixtures/markout-scenarios.csv`; the same rows are asserted on-chain by
`MarkoutScenariosTest`.

## Phase boundary

Phase 2 is pure evaluation only. It does not store trades, authenticate a settler, transfer rebates, or credit an LP
reserve. Phase 3 connects this engine to the Phase 1 escrow while preserving the tested math unchanged.
