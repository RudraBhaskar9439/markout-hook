#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

./scripts/verify-phase-8.sh

pptx="presentation/MARKOUT-UHI10.pptx"
test -f "$pptx"
unzip -tqq "$pptx"

slide_count="$(unzip -Z1 "$pptx" | grep -Ec '^ppt/slides/slide[0-9]+\.xml$')"
test "$slide_count" -eq 9

source_block_count="$(unzip -p "$pptx" 'ppt/notesSlides/notesSlide*.xml' | grep -o '\[Sources\]' | wc -l | tr -d ' ')"
test "$source_block_count" -eq 9

grep -q '^```mermaid$' README.md
grep -q '^# MARKOUT Judge Demo Script$' docs/DEMO_SCRIPT.md
grep -q '^# UHI10 Final Submission Checklist$' docs/SUBMISSION_CHECKLIST.md
grep -q '^# MARKOUT UHI10 Presentation$' presentation/README.md
git diff --check

printf 'Phase 9 token-independent draft verification passed.\n'
