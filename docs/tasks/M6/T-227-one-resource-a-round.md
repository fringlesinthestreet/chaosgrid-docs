---
id: T-227
title: One resource a round
milestone: M6
depends_on: [T-224]
branch: agent/T-227-one-resource-a-round
model: sonnet
effort: medium
scope:
  - packages/core/src/state/config.ts
  - packages/core/src/state/config.test.ts
  - packages/core/src/round/*.test.ts
  - packages/core/src/effects/players.test.ts
  - packages/core/src/view/*.test.ts
  - packages/core/README.md
  - packages/bots/src/**/*.test.ts
  - packages/bots/test/**
  - tools/sim-cli/test/**
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Resources and mana
  - packages/core/README.md#Config
  - tools/sim-cli/README.md#Tests
---

# T-227 — One resource a round

## Goal

Each Plan draws one resource instead of two (D60), so the economy grows by one mana a round.

## Interfaces

- `packages/core/src/state/config.ts`: `resourcesPerRound: count.default(2)` becomes 1. It is the base of the `resourceDraw` player stat (`effects/players.ts`), which `drawPlan` uses; `drawRound` is in `zones/draw.ts`.
- Tests that assume 2, found on `main`: `round/begin.test.ts` (two `resource.drawn` per seat, `toHaveLength(2)`, `resourceCount: 2`, eight `resource.played`), `effects/players.test.ts` (Good Harvest and Wild Grove expect 3 on a base of 2), `state/config.test.ts`. Probably also whole-game tests: `round/play.test.ts`, `round/check.test.ts`, `view/hidden.test.ts`, `view/snapshot.test.ts`, the bots' `test/referee.test.ts`, sim-cli's `smoke.test.ts` and `snapshot-positions.test.ts`.
- `tools/sim-cli/test/golden-script.ts` sets `startingResources: 2`, and its rests assume 4 and then 6 resources.
- `packages/core/README.md` › Config gives the default.

## Deliverables

1. The default is 1, and the README says so.
2. The golden script pins `resourcesPerRound: 2` next to its `startingResources: 2`, so the golden game and its streams don't change: it tests the engine, not the defaults.
3. Every test that counted on 2 now counts on 1, or pins 2 in its own config where the test is about something else.
4. **Numbers in the PR**, for `pnpm sim --seed 1 --games 20` before and after: the median, p10 and p90 rounds.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check perf` green
- [ ] `crew check soak` green
- [ ] `git diff --quiet origin/main -- tools/sim-cli/test/golden` (the streams don't change)

## Out of scope

- Card costs (T-225 adds cheap units) and the bots' code.

## Notes

- A soak bar that fails because games got longer: report it in the PR with its seed, and don't tune a bot for it.
