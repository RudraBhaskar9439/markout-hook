#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

python3 -m unittest discover -s experiments/tests -p 'test_*.py' -v

generated_root="$(mktemp -d)"
trap 'rm -rf "$generated_root"' EXIT

PYTHONPATH=experiments python3 -m markout_experiment.cli \
    --config experiments/config/experiment.json \
    --output-root "$generated_root"

diff -ru experiments/results "$generated_root/results"
diff -ru experiments/charts "$generated_root/charts"

printf 'Phase 6 experiment is reproducible: committed artifacts match a fresh seeded run.\n'
