# MARKOUT Historical Mainnet Robustness Replay

This replay evaluates **251 real swaps** from the [Uniswap v3 USDC/WETH 0.05%](https://etherscan.io/address/0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640) pool between Ethereum blocks `20000000` and `20000399` on June 1, 2024.

It is separate from the primary 768-trade controlled synthetic experiment. The historical window tests whether the implementation can ingest canonical swap events and preserve its accounting on observed data; it is not presented as a representative market backtest.

## Method

- Execution proxy: post-swap Uniswap v3 `sqrtPriceX96`.
- Five-minute reference: first pool swap price at or after `t + 300 seconds`.
- Direction: inferred from the signed USDC pool delta.
- Volatility input: absolute five-minute trailing move, with no future observation in the input.
- Outcome buckets: ex-post markout bands used only to describe results.

## Observed result

| Policy | Volume (USDC) | Average effective fee | LP net after proxy (USDC) |
| --- | ---: | ---: | ---: |
| Fixed | 3187617.756465 | 30.0000 bps | 8853.669278 |
| Volatility | 3187617.756465 | 33.4297 bps | 9946.920985 |
| Markout | 3187617.756465 | 29.8920 bps | 8819.251444 |

Observed directional markout ranged from **-10.72 bps** to **10.66 bps**, with a median of **0.19 bps**.

On this one frozen window, MARKOUT's modeled LP net-after-proxy delta versus fixed was **-0.39%**. This value is reported whether positive or negative; it is not an acceptance threshold.

## Evidence boundary

- One fixed Ethereum mainnet pool window is a robustness replay, not a representative market sample.
- The future reference is the same pool's later marginal price, not an independent Pyth or CEX price.
- sqrtPriceX96 is the post-swap marginal price, not the trade's volume-weighted execution price.
- The replay holds trades and volume fixed and does not model routing, elasticity, liquidity depth, ranges, or rebalancing.
