---
id: T-229
title: Planner plays removal and wipes
milestone: M5
depends_on: [T-206, T-224]
branch: agent/T-229-planner-plays-removal-and-wipes
model: opus
effort: high
scope:
  - packages/bots/src/**
  - tools/sim-cli/src/**
  - docs/balance/**
context:
  - docs/balance/2026-11-08-baseline.md
  - packages/bots/README.md
  - tools/sim-cli/README.md
  - docs/RULES.md#Balance knobs and open questions
---

# T-229 — Planner plays removal and wipes

## Goal

The 11 removal and wipe spells T-201 added are played in 7% to 22% of draws (`bramble_grasp` 19%, `landslide` 22%, `dark_bargain` 7%), and the older exile, `oblivion` and `ember_rain` in 9% to 15%. It looks like a bot gap, not a card problem. After this PR the planner plays each of them in above 30% of the draws where it is castable.

## Deliverables

1. Find why the planner passes on these spells (its value function, targets or timing) and fix it in the bots, with a test that fails before.
2. Rerun the generated baseline (T-206's sizing) and write `docs/balance/<date>-removal.md` with each spell's plays before and after.

## Acceptance

- [ ] `crew check`, `pnpm test:perf` and `pnpm test:soak` green
- [ ] The generated run's card list shows each removal and wipe spell played in above 30% of draws

## Out of scope

- Tuning the cards' numbers (T-225 to T-228).
- The bot-level bars, which stay off while the human balances the levels (D77).

## Notes

The bots import only `protocol`, never `core`. Planner-vs-greedy bars stay off (D77).
