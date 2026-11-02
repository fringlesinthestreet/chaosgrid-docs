---
id: T-149
title: Planner beats greedy in the soak
milestone: M5
depends_on: [T-148]
branch: agent/T-149-planner-beats-greedy-in-the-soak
model: opus
effort: high
scope:
  - packages/bots/src/**
  - packages/bots/README.md
  - tools/sim-cli/test/planner.soak.test.ts
context:
  - docs/DECISIONS.md#D55
  - packages/bots/README.md
  - docs/tasks/M5/T-148-planner-previews-guess-the-other-seats-p.md
---

# T-149 — Planner beats greedy in the soak

## Goal

After this PR the planner bot beats the average greedy seat in the soak. T-148 gave previews a guess for each other seat, but the guesses never changed a pick and the planner wins about its fair share (10 of 40).

## Interfaces

The planner's `plan` and its candidate generation and scoring (T-135, T-148), and the soak in `tools/sim-cli/test/planner.soak.test.ts`. No contract changes: if one seems needed, send a `question` first.

## Deliverables

1. A stronger planner: wider or better candidates, or a better score of a preview. Say in the PR what you measured.
2. The soak asserts `3 × wins[0] > wins[1] + wins[2] + wins[3]` over 40 games (planner vs 3 greedy, starter decks, target 30), on every seed it uses.
3. The bots README documents any change to the budget.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm test:soak` passes
- [ ] `pnpm test:perf` passes

## Out of scope

- Changing previewRound or the protocol (T-148), or greedy's plans.

## Notes

T-148's measurements (planner wins, seeds 1/2/3): 10, 12, 10 of 40, with and without guesses. Longer previews made seed 1 worse, so previews mislead rather than run short. The planner picks greedy's plan in about 73% of its multi-candidate decisions, so look at candidates and the score before the budget.
