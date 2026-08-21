#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

./scripts/verify-phase-9-draft.sh
./scripts/verify-phase-11.sh
./scripts/verify-phase-12.sh
./scripts/verify-phase-13.sh
./scripts/verify-phase-14-local.sh

forge clean
forge test -q
git diff --check

printf 'Hybrid release-candidate verification passed. Public transaction evidence remains a separate manual gate.\n'
