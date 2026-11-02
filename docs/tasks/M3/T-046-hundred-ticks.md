---
id: T-046
title: 100 ticks per second
milestone: M3
depends_on: [T-045]
branch: agent/T-046-hundred-ticks
model: opus
effort: high
scope:
  - packages/core/src/**
  - packages/core/test/**
  - packages/core/README.md
  - packages/protocol/src/**
  - packages/protocol/test/**
  - docs/PROTOCOL.md
  - tools/sim-cli/test/**
  - tools/sim-cli/src/*.test.ts
  - tools/sim-cli/README.md
context:
  - docs/PLAN.md#M3
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Balance knobs
  - packages/core/README.md#Time
  - packages/core/README.md#Tests
  - tools/sim-cli/README.md#Tests
---

# T-046 — 100 ticks per second

## Goal

D18: one tick is 0.01 s. Simulate runs 10,000 ticks by default, every per-second value from card text converts to whole ticks, and positions count in subcells (10,000 to a cell), so movement stays exact integer math. Games must play the same in simulated seconds and stay about as fast in wall-clock time.

## Interfaces

What exists (copied from the code):

```ts
// packages/protocol/src/primitives.ts since T-045; core's time.ts imports it.
export const TICKS_PER_SECOND = 10;
export function secondsToTicks(seconds: number): number; // Math.round(seconds * TPS)
export function attackInterval(attackSpeed: number): number; // max(1, round(TPS / attackSpeed))
export function cellsPerTick(speed: number): number;
export const MILLICELLS_PER_CELL = 1000;
export function millicellsPerTick(speed: number): number; // round(speed * 1000 / TPS)
// Users of millicells: movement/state.ts:10, movement/step.ts:71-85, projectiles/state.ts:29,
// projectiles/flight.ts:186-188. Users of ticks: combat/attacks.ts:137, combat/traps.ts:46,
// effects/modifiers.ts:77, effects/stats.ts:112, effects/triggers.ts:172.
// packages/core/src/state/config.ts:13: roundTicks defaults to 1000.
// Perf budgets: combat/perf.test.ts (a 4-player round with 120 units under 2 s; 1000 ticks of
// 120 units fighting under 5 s), movement/perf.test.ts and projectiles/perf.test.ts (LIMIT_MS).
// sim-cli soak tests: test/done-when.test.ts and test/m2-done-when.test.ts, timeout 300_000.
```

What this task changes:

```ts
export const TICKS_PER_SECOND = 100;
export const SUBCELLS_PER_CELL = 10_000; // replaces MILLICELLS_PER_CELL
export function subcellsPerTick(speed: number): number; // Math.round(speed * SUBCELLS_PER_CELL / TPS): speed × 100, exact for two decimals
// roundTicks defaults to 10_000; PROTOCOL_VERSION + 1 (tick numbers mean 0.01 s now)
```

## Deliverables

1. `time.ts` as above, and every millicell user moved to subcells. Delete `millicellsPerTick`, `MILLICELLS_PER_CELL` and `cellsPerTick` if nothing else uses it. `roundTicks` defaults to 10,000.
2. Tests: `time.test.ts` covers the conversions at 100 ticks per second, including Speed 0.25, 0.3 and 2.75 moving a whole number of subcells, Attack speed 3 (33 ticks) and 0.3 (333 ticks). Tests that hardcode tick numbers move to the new scale: prefer `secondsToTicks(…)` over a literal.
3. Performance, measured before and after on the same machine, in the PR:
   - `pnpm --filter @chaosgrid/core test -- perf` stays green with the same budgets. Its 1000-tick test becomes 10,000 ticks (the same 100 seconds).
   - seconds per game from `pnpm sim --bots greedy,greedy,greedy,greedy --games 20 --seed 1 --decks starter`
   If ten times as many ticks makes Simulate too slow, make the per-tick work cheaper rather than raising budgets: units re-path only when they enter a new cell, their goal moves, or a cell on their path fills, and targets are re-chosen when they die or leave range, not every tick.
4. sim-cli: raise the soak tests' `timeout` if they need it, never play fewer games or tables. Update the timings in tools/sim-cli/README.md › Tests.
5. Protocol: bump `PROTOCOL_VERSION`; `TickEvent`'s comment and PROTOCOL.md say a tick is 0.01 s, with a line in › Versioning. packages/core/README.md › Time describes ticks and subcells.
6. Goldens: regenerate them, and say in the PR what changed beyond the tick numbers.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/core test -- perf` passes with the budgets unchanged
- [ ] The PR body has seconds per game before and after, and the perf tests' times before and after
- [ ] `grep -rn -i millicell packages tools --include='*.ts'` prints nothing

## Out of scope

- The grid size: T-047 (perf measured here is still on 15 × 15 grids)
- Changing a rule's timing to save CPU, such as attacking or moving less often than card text says. If the budgets can't be met without that, stop and send `lead` a `question` with the numbers.

## Notes

- Doubles hold integers exactly up to 2^53. Subcell positions on the largest arena stay below 10^7 and their squares below 10^14, so no decimal or bigint library is needed (D18).
- Card Speeds and Attack speeds have at most two decimals today. If a card has more, the rounding in `subcellsPerTick` and `attackInterval` decides; list the card in the PR.
- Time out per-tick work with the perf tests, not the whole suite.
