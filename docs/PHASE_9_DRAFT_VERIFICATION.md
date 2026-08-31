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

Passing this checkpoint supports narrative review, rehearsal, and the public Circle-settlement claims. The required
opposite-branch settlements, claim, reserve reconciliation, duplicate-delivery proof, and explorer links are complete.
The following still require external or owner state: the final uploaded video, owner identity and Project ID fields,
and form submission. Reactive transport proof, public repository/site access, and logged-out link checks are complete.

## GO / NO-GO

**GO** for public judge review, rehearsal, Circle-backed economic-settlement claims, and the bounded Reactive-transport
claim. **NO-GO** for the `uhi10-final` tag or final form submission until the owner supplies the remaining details.
