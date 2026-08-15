#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

./scripts/verify-phase-6.sh
forge test --match-path 'test/security/**' -vv
uv lock --project security --check
./scripts/run-slither.sh
git diff --check

printf 'Phase 7 cumulative security verification passed.\n'
