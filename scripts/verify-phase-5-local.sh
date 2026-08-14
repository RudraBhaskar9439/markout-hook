#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

run_network_preflight=true
case "${1:-}" in
    "") ;;
    --offline) run_network_preflight=false ;;
    *)
        echo "Usage: $0 [--offline]" >&2
        exit 64
        ;;
esac

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
if [[ "$run_network_preflight" == true ]]; then
    ./scripts/check-phase-5-networks.sh
fi
forge snapshot --check --no-match-test '^(testFuzz|invariant_|test_demo_)'
