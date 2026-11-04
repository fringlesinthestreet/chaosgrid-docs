---
id: T-173
title: Faster projectiles
milestone: M5
depends_on: [T-169, T-170]
branch: agent/T-173-faster-projectiles
model: sonnet
effort: medium
scope:
  - packages/cards/data/**
  - packages/cards/src/**
  - packages/cards/test/**
  - packages/cards/README.md
  - packages/core/src/**/*.test.ts
  - packages/core/test/**
  - packages/bots/src/**/*.test.ts
  - tools/sim-cli/test/**
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Simulation rules
  - packages/cards/README.md#Projectiles
  - tools/sim-cli/README.md#Usage
  - tools/sim-cli/README.md#JSON report
---

# T-173 — Faster projectiles

## Goal

D62 replaces D61: units and projectiles move twice as fast. T-164 doubled every unit's Speed and left projectile speeds alone. The human's review of T-164 (2026-11-04) answered its question "Should the floor go up?" with "yes, increase projectile speed too".

At the old speeds a homing projectile trails the units that buffs make fast, and lands late: Vask's Ember units have Speed 10 at level 9, and Overspeed doubles every Speed. After this task every printed projectile speed is doubled, and the schema takes 10 to 60 cells per second.

## Interfaces

What exists (copied on 2026-11-04):

```ts
// packages/cards/src/schema.ts:152
/**
 * Projectile speed in cells per second. The floor is above the fastest printed unit (Speed 4), so a
 * projectile catches the target it follows. Granted Speed can exceed it (Vask at level 9 gives 10),
 * and a homing projectile then trails its target until that unit stops.
 */
export const PROJECTILE_SPEED = { min: 5, max: 30 } as const;
/** `{ "kind": "arrow", "speed": 15 }` */
export const ProjectileSchema = strict({ kind: ..., speed: z.number().min(...).max(...) });

// packages/cards/src/node/load.test.ts:238
it('prints no unit, Leader or Chaos unit with a Speed above 4 (D61)', ...);
```

The card data prints 26 projectiles, at speeds 8 to 20 (8 at 12, 7 at 14). Core has no projectile speed of its own: it reads the card's.

packages/cards/README.md is out of date since T-164. These lines need changing:

- :180, the speed row: "from 5 to 30 (`PROJECTILE_SPEED`): always faster than any unit, whose Speed tops out at 2";
- :194 and :197, the example arrow and "speeds from 8 to 20";
- :239, :279–280, :561 and :879, the example cards and texts: Vask's "0.5+{level}*0.5" Speed and the Speed 1 and 2 stats;
- :1453, "speeds 8 to 20".

## Deliverables

1. **Every printed projectile speed doubles**: 8 becomes 16, 20 becomes 40. Bump each changed card's `version`.
2. **`PROJECTILE_SPEED` becomes `{ min: 10, max: 60 }`.**
   - Its comment says the floor is 2.5 times the fastest printed Speed, 4, and keeps the note on granted Speed, citing D62.
   - The doc example's arrow flies at 30.
   - The load test's name cites D62.
3. **packages/cards/README.md follows D62:**
   - Speed tops out at 4, and projectiles fly at 10 to 60.
   - The sample cards fly at 16 to 40.
   - Every example card and text is copied from its file as it is now.
4. **Tests and goldens.**
   - Regenerate the sim-cli goldens with their own command, never by hand.
   - A test whose numbers came from a projectile's speed gets the new numbers, written as literals. Never loosen one.
   - New: speed 9 fails the schema and 10 passes, and 60 passes and 61 fails.
5. **The PR carries a before/after table** from the same `pnpm sim` run as T-164's:
   - first contact: median, p10 and p90;
   - median rounds;
   - round end reasons;
   - median ticks a projectile flies, if the JSON report has it.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm cards:validate` passes.
- [ ] `pnpm test:soak` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- A homing projectile that speeds up to stay faster than its target: D62 leaves that to a later decision.
- Projectile art: the battlefield draws a projectile where the model says it is, so its frames need nothing.

## Notes

- After doubling, no printed projectile flies above 40, so the cap of 60 leaves room for new cards.
- The schema's error message reads its numbers from `PROJECTILE_SPEED`, so it follows.
