#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

generated_root="$(mktemp -d)"
trap 'rm -rf "$generated_root"' EXIT

PYTHONPATH=experiments python3 experiments/historical/analyze.py \
  --config experiments/historical/config.json \
  --data experiments/historical/data/swaps.csv \
  --output "$generated_root"

diff -ru experiments/historical/results "$generated_root"
printf 'Historical replay is reproducible from the committed canonical Swap logs.\n'
