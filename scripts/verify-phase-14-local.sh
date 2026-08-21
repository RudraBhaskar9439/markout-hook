#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

forge fmt --check
forge build --sizes
forge test --match-path 'test/circle/**' -vv
forge test --match-path 'test/reactive/ReactiveObservationPulse.t.sol' -vv

bash -n \
  scripts/check-hybrid-networks.sh \
  scripts/fetch-pyth-update.sh \
  scripts/fetch-circle-attestation.sh \
  scripts/publish-circle-observation.sh \
  scripts/relay-circle-attestation.sh

jq empty config/uhi10-testnet.json deployments/hybrid.example.json deployments/hybrid-2026-08-21.json
jq -e '
  .status == "circle-e2e-complete-reactive-pending"
  and .evidence.circleLive == true
  and .evidence.reactiveLive == false
  and (.ethereumSepolia.observationPublishTx | length == 66)
  and (.unichainSepolia.circleRelayTx | length == 66)
  and (.unichainSepolia.rebateClaimTx | length == 66)
  and (.unichainSepolia.duplicateCircleRelayTx | length == 66)
  and .unichainSepolia.settlement.status == "settled"
  and .unichainSepolia.settlement.rebateClaimed == true
  and .unichainSepolia.sourceToDestinationLatencySeconds < 600
' deployments/hybrid-2026-08-21.json >/dev/null
test -x scripts/check-hybrid-networks.sh
test -x scripts/fetch-pyth-update.sh
test -x scripts/fetch-circle-attestation.sh
test -x scripts/publish-circle-observation.sh
test -x scripts/relay-circle-attestation.sh

grep -q 'ETHEREUM_SEPOLIA_CHAIN_ID = 11_155_111' script/DeployCirclePublisher.s.sol
grep -q 'UNICHAIN_SEPOLIA_CHAIN_ID = 1301' script/DeployHybridDestination.s.sol
grep -q 'LASNA_CHAIN_ID = 5_318_007' script/DeployMarkoutPulse.s.sol
grep -q 'ZeroDeploymentValue' script/DeployMarkoutPulse.s.sol
grep -q 'ZeroAddress("BASE_CURRENCY")' script/DeployHybridDestination.s.sol
grep -q 'Circle-primary, Reactive-optional' docs/TESTNET_DEPLOYMENT.md
grep -q "legacy Lasna's subscription" docs/HYBRID_TESTNET_DEPLOYMENT.md
git diff --check

printf 'Phase 14 local deployment-automation verification passed.\n'
