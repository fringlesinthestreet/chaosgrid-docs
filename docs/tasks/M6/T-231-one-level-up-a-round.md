---
id: T-231
title: One level-up a round
milestone: M6
depends_on: [T-227, T-228]
branch: agent/T-231-one-level-up-a-round
model: sonnet
effort: high
scope:
  - packages/core/src/plan/**
  - packages/core/src/view/board.ts
  - packages/core/src/view/*.test.ts
  - packages/core/src/round/cleanup.ts
  - packages/core/src/round/cleanup.test.ts
  - packages/core/src/round/rebuild.ts
  - packages/core/src/round/rebuild.test.ts
  - tools/sim-cli/test/golden/**
  - tools/sim-cli/test/golden-script.ts
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Units
---

# T-231 — One level-up a round

## Goal

A squad gains at most one level a round (D84). Today nothing limits it: a Leader, which is always unlocked, levels again for every payment in one Plan, and a test locks that in.

## Interfaces

On `main` (grep the names, the lines move):

- `Squad` (`state/state.ts`) has `level`, `roundsOnGrid` (Cleanups survived on the grid, counted by `countRoundsOnGrid` in `round/cleanup.ts`) and `damageDealt` (counted live by `recordHit` in `effects/health.ts`).
- `isUnlocked(state, squad)` (`plan/level.ts`) reads the live counters; a card with no `levelUnlock` is always unlocked. The `levelUp` step (`plan/level.ts`, in `STEPS` in `plan/apply.ts`) checks `illegalTarget`, `forbidden`, `maxLevel`, `notUnlocked`, pays, then sets `squad.level += 1; squad.roundsOnGrid = 0; squad.damageDealt = 0` and emits `squad.leveled`. Overflow is already lost.
- The snapshot's copy of the unlock: `levelUnlocked(squad, unlock)` in `view/board.ts`, and `canLevelUp = own && unlocked && level < maxLevel` in `squadSnapshot`; `plan/level.test.ts` checks that the two agree.
- The once-a-round model to copy: `PlanState.used` (`plan/state.ts`) for Plan abilities, cleared in `unrestCards` at Cleanup.
- `round/rebuild.ts` rebuilds the counters from a snapshot's `unlocked` for previews.

## Deliverables

1. A squad that leveled this round isn't unlocked again until the next Cleanup, whatever its counters say and whether or not its card prints a condition. A second `levelUp` for it is rejected as `notUnlocked`, and its snapshot shows `unlocked: false`, so `levelUpPayable` and the web's button follow with no protocol change.
2. The rebuild keeps it: a preview of a squad that leveled this round can't level it again.
3. Tests in `plan/level.test.ts`: a Leader levels once in a Plan even with mana for three, and again next round; a unit whose condition is met twice over levels once, and its counters are 0 after; the snapshot and `isUnlocked` still agree. Replace "levels a Leader whenever its cost is paid".
4. If the golden streams change, rewrite them with `UPDATE_GOLDEN=1 pnpm --filter @chaosgrid/sim-cli test` and say why in one line.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check perf` green
- [ ] `crew check soak` green

## Out of scope

- The protocol, the bots (each already adds at most one `levelUp` a squad) and the web.
