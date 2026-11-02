---
id: T-026
title: Projectiles in card data
milestone: M1
depends_on: [T-010]
branch: agent/T-026-projectile-cards
scope:
  - packages/cards/**
  - packages/core/src/state/testing.ts
  - packages/core/test/fixtures/targeting/board.ts
  - packages/core/test/fixtures/effects/cards.ts
  - packages/db/test/fixtures/cards/units/flame_lancer.json
  - packages/db/test/fixtures/invalid/units/flame_lancer.json
---

# T-026 — Projectiles in card data

## Goal

Ranged and Artillery units say what they fire and how fast, so core can fly their projectiles (T-027) and the UI can draw each kind.

## Read first

- packages/cards/README.md (card format and DSL)
- docs/RULES.md › Simulation rules (Attacking, Projectiles)
- docs/tasks/M1/README.md › Projectiles

## Deliverables

1. `PROJECTILE_KINDS`, exported: `arrow`, `bolt`, `fireball`, `waterball`, `shell`, `orb`. The protocol lists the same kinds (T-025).
2. A top-level `projectile` field on units, Leaders and Chaos units: `{ "kind": "arrow", "speed": 15 }`, with `speed` in cells per second, from 5 to 30, so projectiles always outrun units (Speed tops out at 2).
   - It's required when `stats.range` is `ranged` or `artillery`, and not allowed on `melee`. The validator says which.
   - It stays out of `stats`, so the protocol's `UnitStats` doesn't change.
3. Every Ranged and Artillery sample card gets one: today `chaos.hex_caster`, `chaos.scavenger_drone`, `chaos.void_maw`, `leader.kettle_chaos_broker`, `leader.oriel_of_the_still_deep`, `unit.current_mage`, `unit.flame_lancer`, `unit.reef_archer`, `unit.storm_drake` and `unit.tide_mortar`. Pick kinds that fit each card (Reef Archer fires arrows, Tide Mortar shells) and speeds from 8 to 20, with Artillery slower than Ranged.
4. `src/dsl.test.ts` stops hard-coding the number of sample cards (62), so T-029 can add cards without touching it.
5. README: the field in the format tables, with an example that `readme.test.ts` keeps valid.
6. Fixtures: the new valid shape, and invalid ones for a Melee unit with a projectile, a Ranged unit without one, an unknown kind and a speed out of range.

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green
- [ ] `pnpm cards:validate` passes for every sample card and rejects the new invalid fixtures
- [ ] A second `pnpm db:seed` in a row changes nothing (the DB stores card data as JSON, so there's no migration)

## Out of scope

- Flying projectiles (T-027, T-020), the protocol's copy of the kinds (T-025), and drawing them (M3).

## Notes

- Trample needs no new field. A Ranged or Artillery unit with Trample fires a projectile that splashes where it lands (M1 README › Projectiles).
- Card `version` stays 1: versioning starts in M4.
- Making `projectile` required breaks the Ranged and Artillery test cards outside `packages/cards`, and they can't change before this PR (the strict schema rejects the field on `main`). So the five test files in the scope get one `projectile` each, and nothing else changes in them.
- After this merges, any new Ranged or Artillery test card needs a `projectile`.
