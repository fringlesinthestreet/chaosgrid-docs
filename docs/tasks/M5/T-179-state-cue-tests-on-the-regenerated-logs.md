---
id: T-179
title: State cue tests on the regenerated logs
milestone: M5
depends_on: []
branch: agent/T-179-state-cue-tests-on-the-regenerated-logs
model: haiku
effort: low
scope:
  - apps/web/src/match/battlefield/scene.test.ts
context:
  - apps/web/README.md#Tests
---

# T-179 — State cue tests on the regenerated logs

## Goal

Main is red: five tests in `scene.test.ts › createBattlefield › state cues` fail with `no cues:undefined`. T-162 wrote them on the old logs, where `planned` had placed squads. T-178 regenerated the logs, made `planned` the model before round 1's first tick, where no squad is placed yet, and added `placed` for one with squads. It fixed the tests on its own branch, but T-162 merged first, so its tests still look for a squad in `planned` and find none. Point them at `placed`.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// apps/web/src/match/battlefield/scene.test.ts
const planned = beforeTick(1); // Round 1 starts: no squad is placed yet
const placed = beforeTick(2); // Round 2 starts: squads placed
const fighting = beforeTick(60);

// :483, describe('state cues')
const wide = {
  ...Object.values(planned.squads).find((squad) => !squad.retired)!, // undefined now
  size: [4, 2] as [number, number],
};
const empty = { ...planned, units: {} };
// drawn(change, resources, units) draws `empty` with `wide` changed and returns node(root, `cues:${squad.squad}`)
```

The five failing tests:

- "glows a squad with Charge 2 and two attached resources, not one"
- "does not glow a rested charged squad"
- "shows Durability, retiring at 0, the card keywords and no level 1"
- "shows the keywords of the squad's units over the card's"
- "leaves out the badges that do not fit, from the end"

## Deliverables

1. `wide` and `empty` in `describe('state cues')` come from `placed`, so the five tests pass again with their expectations as they are. "draws a rested permanent muted, at alpha 0.6" passes on `planned` and stays on it.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test scene` passes, all 30 tests. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `git diff --stat main...HEAD` lists only `scene.test.ts`.

## Out of scope

- The logs and `scene.ts`. If a test still fails on `placed`, its expectation meets a log it wasn't written for: report it instead of changing what it checks.
