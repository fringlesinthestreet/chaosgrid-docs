---
id: T-091
title: Projectile speed cap
milestone: M3
depends_on: [T-046]
branch: agent/T-091-projectile-speed-cap
model: sonnet
effort: medium
scope:
  - packages/protocol/src/**
  - docs/PROTOCOL.md
  - packages/core/src/projectiles/**
context:
  - docs/PROTOCOL.md#Projectiles
  - docs/PROTOCOL.md#Versioning
---

# T-091 — Projectile speed cap

## Goal

T-046 left this question open: should the protocol cap projectile speed? The human said yes, at 60 cells per second (D30). At 100 ticks per second that's 0.6 cells a tick, so a projectile never moves more than one cell in a tick. Every `projectile.moved` then goes to the next cell on the projectile's line, and the UI can draw each move as a one-cell step. Cards already print 5 to 30 cells per second, so no real game changes and no golden round changes.

## Interfaces

What exists (copied from the code on 2026-10-22):

```ts
// packages/protocol/src/event.ts:342
export const ProjectileLaunchedEvent = z.strictObject({
  // …
  /** Cells per second, from the unit's card: faster than any unit walks. */
  speed: z.number().positive(),
  // …
});
// packages/protocol/src/event.ts:364. Its comment says "A fast one can cross several cells in one event."
export const ProjectileMovedEvent = z.strictObject({ type, projectile, from: WorldCell, to: WorldCell });
// packages/protocol/src/version.ts:6
export const PROTOCOL_VERSION = 10;
// packages/protocol/src/docs.test.ts:96 checks that PROTOCOL.md says "`PROTOCOL_VERSION` is N." and has "(version N)" in its title

// packages/cards/src/schema.ts:108: what a card may print (exported from @chaosgrid/cards)
export const PROJECTILE_SPEED = { min: 5, max: 30 } as const;

// packages/core/src/projectiles/flight.ts
export function launchProjectile(state, attacker, target, { damage, trample }): ProjectileLaunchedEvent;
//   copies card.projectile.speed (line 69); throws RangeError for a bad damage or trample
function fly(state, projectile, cellsOf): boolean | null;
//   progress += subcellsPerTick(projectile.speed); while (progress >= SUBCELLS_PER_CELL) { one step }
// packages/core/src/time/time.ts: SUBCELLS_PER_CELL = 10_000, subcellsPerTick(60) = 6_000

// packages/core/src/projectiles/flight.test.ts:212: the only test faster than 60 cells/s
it('moves several cells in one tick when it is fast, reported as one move', …); // sets speed = 300
```

New:

```ts
// packages/protocol/src/event.ts, above ProjectileLaunchedEvent
/** The fastest a projectile flies, in cells per second: 0.6 cells a tick, so never two cells in one tick (D30). */
export const MAX_PROJECTILE_SPEED = 60;
```

D30 (docs/DECISIONS.md): a projectile flies at most 60 cells per second (`MAX_PROJECTILE_SPEED`, protocol), 0.6 cells a tick. So it moves at most one cell in a tick, and every `projectile.moved` goes to the next cell on its line. The cards' own range (`PROJECTILE_SPEED`, 5 to 30) stays at or below the cap.

## Deliverables

1. **Protocol.**
   - Add `MAX_PROJECTILE_SPEED = 60` as shown above, exported from the package.
   - `ProjectileLaunchedEvent.speed` becomes `z.number().positive().max(MAX_PROJECTILE_SPEED)`, and its comment names the cap.
   - Change `ProjectileMovedEvent`'s comment to say that `to` is the next cell on the projectile's line, one cell from `from` (Chebyshev). Don't add a refinement: the schema stays a plain `strictObject`.
   - Bump `PROTOCOL_VERSION` to 11.
   - Add tests to `event.test.ts`: a `projectile.launched` at speed 60 parses, and one at 61 fails on `['speed']`.
2. **PROTOCOL.md.**
   - In the Projectiles table, `projectile.launched` says `speed` is in cells per second, more than 0 and at most `MAX_PROJECTILE_SPEED` (60).
   - In the same table, `projectile.moved` drops "(a fast one can cross several cells)". It says instead that `to` is always one cell from `from`: a projectile flies at most 0.6 cells a tick (D30).
   - Update the version in the title and the "`PROTOCOL_VERSION` is 11." sentence.
   - Add a Versioning row: "Protocol v11 (T-091): projectiles fly at most `MAX_PROJECTILE_SPEED` (60) cells per second (D30), so every `projectile.moved` goes one cell."
3. **Core.**
   - `launchProjectile` throws a `RangeError` when the card's projectile speed is above `MAX_PROJECTILE_SPEED`. The error names the unit and the card, and it's thrown before the state changes. Add this case to the doc comment's list of throws.
   - `fly` takes at most one step a tick: the `while` becomes an `if`. A one-line comment says why one is enough: at most 6,000 subcells are added a tick, and progress is below `SUBCELLS_PER_CELL` after a step.
   - Update `flight.test.ts`:
     - Replace the 300 cells/s test with one at `MAX_PROJECTILE_SPEED`. Until it lands, every move is one cell from `from`. It lands after `ceil(cells × SUBCELLS_PER_CELL / subcellsPerTick(60))` ticks.
     - Launching from a card whose projectile speed is 61 throws, and nothing is left in flight. Set the speed on the test state's catalog entry.
     - `PROJECTILE_SPEED.max` from `@chaosgrid/cards` is at most `MAX_PROJECTILE_SPEED`, so the card range can't pass the cap without failing a test.

## Acceptance

- [ ] `crew check` is green.
- [ ] `grep -n 'while (projectile.progress' packages/core/src/projectiles/flight.ts` prints nothing.
- [ ] `git diff --stat main...HEAD -- tools/sim-cli/test/golden` prints nothing: no golden changes.

## Out of scope

- The cards' range, `PROJECTILE_SPEED` (5 to 30), in `packages/cards`: it stays below the cap.
- Unit walking (`movement/step.ts`). Its loop also allows several steps a tick, but units walk far slower than projectiles fly.
- The perf and soak tests T-046 also asked about. The lead answers those separately.

## Notes

- From T-046's open question 3 (2026-10-22): the human chose 60 cells per second, twice the fastest card, so the cards' range has room to grow.
- This task runs before T-047. Both edit `packages/protocol/src/**`, `docs/PROTOCOL.md` and `packages/core/src/**`, so T-047 bases on it and bumps the version to 12.
- Default: throw at launch rather than clamp. A speed above the cap can only come from an unchecked catalog, which is a bug, and core throws on its own bugs.
