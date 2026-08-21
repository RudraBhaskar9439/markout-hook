# Phase 9 Draft Verification Guide

The draft gate verifies the final-submission package, including the explorer-backed Circle settlement now recorded in
the dated deployment manifest. Owner identity fields, visibility changes, the uploaded video, and final-form
submission remain outside this local gate.

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

Passing this checkpoint supports narrative review, rehearsal, and the public Circle-settlement claim. The required
Circle settlement, claim, duplicate-delivery proof, and explorer links are complete. The following still require
external or owner state: optional Reactive callback proof, the final uploaded video, owner form details,
repository/site visibility decisions, logged-out link checks, and form submission.

## GO / NO-GO

**GO** for teammate review, private judge-app review, rehearsal, and public Circle-settlement claims. **NO-GO** for
the `uhi10-final` tag, final form submission, public Reactive-delivery claims, or access changes.
