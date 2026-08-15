#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

readonly slither_version="0.11.6"

if ! command -v uv >/dev/null 2>&1; then
    printf 'uv is required. Install the pinned CI version documented in docs/DEPENDENCIES.md.\n' >&2
    exit 1
fi

uv run --project security --frozen --python 3.12 \
    slither . --config-file slither.config.json

printf 'Slither %s completed with no medium- or high-severity findings.\n' "$slither_version"
