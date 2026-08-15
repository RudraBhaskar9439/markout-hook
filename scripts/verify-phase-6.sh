#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

./scripts/verify-phase-5-local.sh --offline
./experiments/run.sh
git diff --check

printf 'Phase 6 cumulative verification passed.\n'
