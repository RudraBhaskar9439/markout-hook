# MARKOUT architecture narration

## 55-second video script

“MARKOUT charges a trade by its outcome, instead of guessing its risk upfront.

First, the trader executes a real Uniswap v4 swap. The pool charges an 18-basis-point base fee and temporarily escrows another 50 basis points.

Second, the hook records the execution price, direction, trader, and a five-minute maturity.

Third, Pyth provides a signed delayed reference price on Ethereum.

The key step is Reactive Network. A hook cannot wake itself five minutes later, so the Reactive lifecycle watches both the trade and price events, waits for maturity, matches the correct observation, and triggers an authenticated callback without a privileged keeper.

Back on Unichain, the contracts validate that callback and compute the directional markout exactly once. Fair or inventory-improving flow receives a refund. Adverse flow contributes to LP protection. If no valid price arrives, anyone can expire the trade and the provisional amount remains fully refundable.

Circle CCTP is the redundant delivery rail, while the same Unichain contracts remain the final source of truth.”

## Evidence transition

“In our controlled 768-trade synthetic study, MARKOUT reduced the average benign-flow fee by 8.58%, reduced inventory-improving fees by 40%, and improved LP net-after-proxy by 21.87% versus the fixed-fee policy.”

## Accuracy note for the submission

Describe the full Reactive lifecycle as **implemented and tested**, not as a publicly completed Reactive-to-Unichain callback. The publicly verified delivery evidence currently comes from the redundant Circle path.
