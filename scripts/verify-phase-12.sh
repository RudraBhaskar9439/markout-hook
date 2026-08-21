#!/usr/bin/env bash
set -euo pipefail

forge fmt --check
forge build --sizes
forge test --match-path 'test/math/PythObservation.t.sol' -vv
forge test --match-path 'test/circle/CirclePythObservationPublisher.t.sol' -vv
forge test --match-path 'test/circle/CircleObservationReceiver.t.sol' -vv
forge test --match-path 'test/circle/CircleSettlementIntegration.t.sol' -vv
