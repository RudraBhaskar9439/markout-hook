#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

forge fmt --check
forge clean
forge build --sizes
forge lint
forge test --match-path 'test/unit/**' -vv
forge test --match-path 'test/accounting/**' -vv
forge test --match-path 'test/math/**' -vv
forge test --match-path 'test/lifecycle/**' -vv
forge test --match-path 'test/reactive/**' -vv
forge test --match-path 'test/invariants/**' -vv
forge test --match-path 'test/demo/**' -vv
./scripts/run-phase-5-demo.sh
./scripts/check-phase-5-networks.sh
forge snapshot --check --no-match-test '^(testFuzz|invariant_|test_demo_)'
