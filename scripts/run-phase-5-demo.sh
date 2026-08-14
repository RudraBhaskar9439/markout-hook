#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

forge test \
    --match-path 'test/reactive/MarkoutReactiveAutonomousSampling.t.sol' \
    --match-test 'test_oneCronAutonomouslySamplesMedianSettlesAndAcknowledges' \
    -vv
