---
id: T-013
title: Targeting
milestone: M1
depends_on: [T-008]
branch: agent/T-013-targeting
scope:
  - packages/core/src/targeting/**
  - packages/core/test/fixtures/targeting/**
---

# T-013 — Targeting

## Goal

Decide what each unit attacks and whether it's in range, following RULES.md: the nearest enemy permanent, Blocker taunts, Flying and Reach, range classes, and Artillery's minimum range.

## Read first

- docs/CORE.md and packages/core/README.md
- docs/RULES.md: Simulation rules (Targeting, Range classes, Blocker), Units (Flying and reach, Keywords), Chaos deck and Emblems

## Deliverables

1. `chooseTarget(state, unit, statsOf)`:
   - Candidates are enemy permanents of any kind: units, artifacts, enchantments and revealed traps, belonging to opponents or to Chaos. For a Chaos unit, the players it spawned for (`Squad.spawnedFor`, which T-019 sets) come first.
   - The nearest candidate wins. Ties go to the lowest HP, then the lowest id.
   - An enemy Blocker whose taunt range covers the unit overrides that (the nearest such Blocker), unless the unit ignores Blockers. A Blocker without Reach can't taunt a flying unit.
   - Emblems count only when no other enemy is in range, unless the unit seeks Emblems.
2. `canAttack(unit, target, statsOf)`:
   - Ranges: Melee 1, Ranged 3, Artillery 6 with a minimum of 2.
   - Ranged and Artillery units without Reach can't hit flying units. Flying units can hit ground units.
   - Effective stats arrive through `statsOf` (T-016 builds the real one), so range changes such as Dust Storm's −1 apply automatically. Tests pass in simple stand-ins.
3. A unit keeps its target while that target is alive and valid ("a unit without a living target picks…"). That target is stored in a `targeting` slice.
4. Tests for every rule above, including ties, overlapping taunts, flying against Reach, the minimum range, Emblems, and Chaos priorities.

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green

## Out of scope

- Moving toward the target (T-012) and attacking it (T-020).
