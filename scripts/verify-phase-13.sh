#!/usr/bin/env bash
set -euo pipefail

forge fmt --check
forge build --sizes
forge test --match-path 'test/reactive/ReactiveObservationPulse.t.sol' -vv
forge test --match-path 'test/hybrid/SettlementCoordinator.t.sol' -vv
forge test --match-path 'test/circle/CircleSettlementIntegration.t.sol' -vv

if rg -n 'mapping\(|Cron|lastRetry|maturityTimestamp|expiryTimestamp' src/reactive/MarkoutPulseReactive.sol; then
  echo "Stateless pulse gate failed: forbidden lifecycle state or scheduling term found" >&2
  exit 1
fi
