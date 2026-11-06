---
id: T-203
title: Planner bot against the early Chaos waves
milestone: M5
depends_on: [T-183]
branch: agent/T-203-planner-bot-against-the-early-chaos-wave
model: sonnet
effort: high
scope:
  - packages/bots/**
  - tools/sim-cli/src/**
  - tools/sim-cli/test/*.ts
context:
  - packages/bots/README.md
  - tools/sim-cli/README.md#Decks
---

# T-203 — Planner bot against the early Chaos waves

## Goal

After T-183 the early Chaos waves are bigger, and the planner soak is red: the planner wins 5 of 40 games (12.5%) against greedy's 12/7/16, and games end in a median of 5 rounds instead of 11. Make the planner cope with those waves so the soak passes again, without loosening it.

## Interfaces

The planner is `packages/bots/src/planner-bot.ts`. The soak is the planner-against-greedy test in `tools/sim-cli/test/` (it wants 3× the planner's wins above the 35 it sets).

## Deliverables

1. A change to the planner (or the shared bot code it uses) that survives the early Chaos waves.
2. The soak green with its thresholds unchanged.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm test:soak` green, planner soak included
- [ ] The report gives the planner and greedy win counts and the median game length before and after

## Out of scope

- Changing the Chaos waves or card data: that is T-183's tuning. If the waves are the problem, ask the lead.
- Loosening any soak threshold or timeout.

## Notes

T-183 raised some sim-cli soak timeouts because games run about 2× slower; leave them as they are unless a soak times out again.
