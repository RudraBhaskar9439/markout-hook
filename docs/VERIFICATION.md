# Verification Protocol

MARKOUT is built as a sequence of independently reviewable checkpoints. The next phase starts only after the current gate has been reviewed and marked GO.

## What every phase handoff includes

- A short explanation of the completed behavior
- Exact commands that can be copied and run
- Expected output and the actual observed output
- One manual demonstration
- Links to live transactions when the phase reaches testnet
- Known limitations and unresolved risks
- The commit hash and an annotated `phase-N-pass` tag

## Verification levels

### Level 1 — Build

The code compiles using pinned dependencies from a clean checkout.

### Level 2 — Behavioral tests

Unit and integration tests prove expected trade behavior, including both successful and failing paths.

### Level 3 — Invariants

Fuzz and stateful tests verify properties such as solvency, bounded rebates, replay protection, and conservation of balances.

### Level 4 — Manual scenario

A small scenario makes the phase understandable without reading Solidity. For example, two traders pay equal provisional surcharges and receive different rebates after different markouts.

### Level 5 — Live evidence

Explorer transactions prove the real publication, Circle attestation relay, settlement, and claim lifecycle. Reactive
receives separate live credit only when its destination callback transaction exists publicly.

## Gate discipline

- A failing mandatory check means **NO-GO**.
- A skipped mandatory check means **NO-GO**.
- A known issue is acceptable only if it is documented, does not violate a phase invariant, and has a scheduled resolution phase.
- Test expectations are not weakened merely to make a phase pass.
- Experimental results include negative outcomes and limitations.

## Clean-checkout rule

Before the final phase, all documented verification commands must be repeated from a clean clone of the private repository. Local, uncommitted configuration must not be required except documented secrets loaded from environment variables.

## Secrets rule

- Private keys, RPC credentials, API keys, and `.env` files are never committed.
- `.env.example` contains names and descriptions only.
- Testnet deployer addresses may be public; their keys may not.
