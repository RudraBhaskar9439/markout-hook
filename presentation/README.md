# MARKOUT UHI10 Presentation

`MARKOUT-UHI10.pptx` is the nine-slide judge deck for the hybrid release candidate. Its narrative moves from the
fee-classification gap through mechanism, deterministic evidence, Circle-primary/Reactive-optional architecture,
engineering proof, and the completed public Circle lifecycle.

## Evidence policy

- Every quantitative value comes from the committed Phase 6 trade tape and generated reports.
- The deck calls the loss metric a post-trade adverse-selection proxy, not exact LVR or individual LP PnL.
- The volatility-policy regression is visible rather than hidden.
- The final slide records both public Circle outcomes: a negative-markout trade settled in 38 seconds and rebated 100%
  of its surcharge; a positive-markout trade settled in 67 seconds and retained 100% for LP protection.
- Reactive is presented as optional and receives live credit only when a public destination callback exists.
- Speaker notes contain a `[Sources]` block on every slide.

## Visual verification

The final PowerPoint was imported from the approved nine-slide design, edited in place, rendered slide-by-slide, and
passed both template-fidelity and overflow checks with zero issues. Connector direction, chart legibility, numeric
wrapping, speaker-note source blocks, inherited theme preservation, and footer consistency were reviewed.

Reactive remains explicitly optional and must not be presented as live until a public destination callback exists.
