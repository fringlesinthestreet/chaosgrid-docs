---
id: T-219
title: Raise the point target
milestone: M5
depends_on: [T-206]
branch: agent/T-219-raise-the-point-target
model: sonnet
effort: medium
scope:
  - packages/core/src/state/config.ts
  - packages/core/src/state/config.test.ts
  - packages/core/README.md
  - docs/balance/**
context:
  - docs/balance/2026-11-08-baseline.md
  - docs/RULES.md#Balance knobs and open questions
  - tools/sim-cli/README.md
---

# T-219 — Raise the point target

## Goal

Games end in a median of 5 rounds (p10 5, p90 9), against M5's 12 to 16. At about 12 points a seat a round, the first-order target for 12 to 16 rounds is 280 (100 × 14 / 5). After this PR the default point target is the value that puts the median at 12 to 16 rounds, with the runs that show it.

## Interfaces

The point target default is in `packages/core/src/state/config.ts`. `pnpm sim … --target <n>` overrides it for a run.

## Deliverables

1. Rerun the starter and generated baselines (T-206's method and sizing) at `--target 200` and `--target 280`; merge them into `docs/balance/<date>-target-200.json` and `-target-280.json` with a short `docs/balance/<date>-point-target.md` that gives the median, p10 and p90 rounds of each.
2. Set the default to the value whose median round count falls in 12 to 16 (interpolate and rerun once if neither does), and update the tests and the README line that name it.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm sim --merge docs/balance/<date>-target-<n>.json` prints a median of 12 to 16 rounds for the chosen default

## Out of scope

- Tuning cards or decks (T-220 to T-228).
- Changing the Chaos factor or cap (D65, D76): if the write-up shows the target is not the knob, stop and report.

## Notes

The protocol exposes the target in the snapshot; if changing the default alters a payload, stop and ask the lead.
