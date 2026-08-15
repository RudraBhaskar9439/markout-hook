#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

PYTHONPATH=experiments python3 -m markout_experiment.cli \
    --config experiments/config/experiment.json \
    --output-root experiments

printf 'Regenerated Phase 6 artifacts. Review every result and chart before committing.\n'
