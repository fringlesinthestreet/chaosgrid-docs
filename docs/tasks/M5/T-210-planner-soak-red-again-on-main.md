---
id: T-210
title: Planner soak red again on main
milestone: M5
depends_on: []
branch: agent/T-210-planner-soak-red-again-on-main
model: opus
effort: high
scope:
  - packages/bots/**
  - tools/sim-cli/src/**
  - tools/sim-cli/test/*.ts
context:
  - packages/bots/README.md
  - tools/sim-cli/README.md#Decks
---

# T-210 — Planner soak red again on main

## Goal

`planner.soak.test.ts` fails on a clean `main` (`expected 27 to be greater than 31`), after T-203 had made it green. Find what turned it red again and make the planner pass the soak without loosening it.

## Interfaces

The planner is `packages/bots/src/planner-bot.ts`. The soak is `tools/sim-cli/test/planner.soak.test.ts`. Run it with `pnpm test:soak`.

## Deliverables

1. The cause, found with `git log` on the soak's inputs (T-203 merged as #238; T-189 and T-194 since changed Durability and Fleeting): say in the PR which change turned it red.
2. A fix in the planner or the shared bot code, with the soak thresholds unchanged.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm test:soak` green, planner soak included
- [ ] The report gives the planner and greedy win counts before and after

## Out of scope

- Loosening any soak threshold or timeout.
- Changing card data or the Chaos waves: if they are the cause, ask the lead.
- T-193 (Charge) changes the planner's inputs too; if it has merged by the time you start, rebase and measure again before fixing.

## Notes

The T-193 worker saw the same failure with the same numbers on a clean `origin/main`, so T-193 didn't cause it.
