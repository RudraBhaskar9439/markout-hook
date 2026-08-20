# Phase 9 Draft Verification Guide

The draft gate verifies every final-submission artifact that can be completed without autonomous settlement evidence,
owner identity fields, visibility changes, or final-form submission.

## Automated gate

```bash
./scripts/verify-phase-9-draft.sh
```

The script repeats the Phase 8 cumulative protocol, research, security, and judge-application checks. It then validates
the final PowerPoint archive, requires nine slides and nine speaker-note source blocks, checks the final README
architecture diagram, and verifies that the demo script and submission checklist exist.

## Visual deck gate

The deck is rendered slide-by-slide with the bundled presentation runtime. Every full-size slide and the montage must
be inspected for clipping, unintended overlap, unreadable type, incorrect chart values, and inconsistent styling. The
overflow checker must report zero out-of-bounds elements before the deck is committed.

## Exact boundary

Passing this checkpoint supports narrative review and rehearsal. It does not satisfy the final roadmap phase. The
following still require external or owner state: successful Reactive destination delivery, two live settlements, final
explorer links, the final video, owner form details, repository/site visibility decisions, and form submission.

## GO / NO-GO

**GO** for teammate review, private judge-app review, rehearsal, and live-evidence integration. **NO-GO** for the
`uhi10-final` tag, final form submission, public settlement claims, or access changes.
