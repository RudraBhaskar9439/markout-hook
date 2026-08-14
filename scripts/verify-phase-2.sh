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
forge test --match-path 'test/invariants/**' -vv
forge snapshot --check --no-match-test '^(testFuzz|invariant_)'
