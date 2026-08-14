#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

forge test \
    --match-path 'test/demo/MarkoutLifecycleDemo.t.sol' \
    --match-test 'test_demo_twoTradesReceiveDifferentOutcomeBasedRebates' \
    -vv
