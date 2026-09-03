# Phase 12 Verification - Historical Circle CCTP V2 Recovery Transport

> Historical checkpoint. This phase proved the recovery module and economic branches before Reactive Network became
> the primary final architecture.

## Automated gate

```bash
./scripts/verify-phase-12.sh
```

The gate verifies:

1. Pyth exponent, price, publish-time, and mechanical confidence normalization.
2. Permissionless source publication with an exact Pyth update fee.
3. A fast-confirmed generic Circle message request addressed to Unichain domain `10`.
4. Destination authentication of Circle transmitter, Sepolia domain `0`, source publisher, finality, version, market,
   and nonzero trade id.
5. A complete local simulation from real v4 swap and surcharge escrow through Pyth, Circle, the coordinator, and the
   real MARKOUT terminal allocation.
6. A failed early observation leaving the trade pending for a later valid retry.

## Source and transport boundaries

- The publisher is permissionless but obtains price, confidence interval, exponent, and publish time from the configured
  Pyth contract. The caller supplies signed update bytes and a trade id, not a trusted price.
- The publisher requests Circle threshold `1000` and permits any account to relay the attested message.
- The destination receiver accepts thresholds `1000–1999` through `handleReceiveUnfinalizedMessage` and thresholds
  `2000+` through `handleReceiveFinalizedMessage`; the ranges cannot overlap.
- The fast path is necessary because Circle documents about 20 seconds for Ethereum threshold `1000`, versus 15–19
  minutes for threshold `2000`, which would miss MARKOUT's ten-minute settlement window. This accepts bounded source
  reorganization risk and is called out explicitly in the architecture and threat model.
- Circle authenticates the envelope. The hook independently authenticates economic eligibility.
- The first valid transport delivery settles. Later Circle or Reactive delivery is a coordinator no-op.

## Public deployment boundary

The local simulator proves application behavior, not Circle's public attestation service. Phase 14 requires explorer
transactions for the Sepolia `MessageSent`, Circle attestation status, Unichain `MessageReceived`, receiver event,
MARKOUT settlement, and rebate claim.

Official references:

- [Circle CCTP V2 contract interfaces](https://developers.circle.com/cctp/references/contract-interfaces)
- [Circle supported domains](https://developers.circle.com/cctp/concepts/supported-chains-and-domains)
- [Circle finality and block confirmations](https://developers.circle.com/cctp/concepts/finality-and-block-confirmations)
- [Pyth EVM contract addresses](https://docs.pyth.network/price-feeds/core/contract-addresses/evm)
