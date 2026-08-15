#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

./scripts/verify-phase-7.sh

(
    cd web
    npm ci
    npm run verify
)

git diff --check

printf 'Phase 8 token-independent cumulative verification passed.\n'
