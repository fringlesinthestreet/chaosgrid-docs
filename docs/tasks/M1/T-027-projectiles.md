---
id: T-027
title: Projectiles
milestone: M1
depends_on: [T-008, T-025, T-026]
branch: agent/T-027-projectiles
scope:
  - packages/core/src/projectiles/**
  - packages/core/test/fixtures/projectiles/**
  - packages/core/src/state/state.ts
  - packages/core/src/state/create.ts
  - packages/core/src/state/state.test.ts
  - packages/core/src/state/ids.ts
  - packages/core/src/state/ids.test.ts
  - packages/core/src/modules.test.ts
---

# T-027 — Projectiles

## Goal

Ranged and Artillery attacks become projectiles that fly across the arena and deal their damage only when they land. This module keeps them in flight. Combat (T-020) launches them, applies what lands and emits the events.

## Read first

- docs/tasks/M1/README.md (the Projectiles default, Interfaces, Ids, Time, Events) and packages/core/README.md
- docs/RULES.md › Simulation rules (Attacking, Projectiles, Damage and death)
- docs/PROTOCOL.md (the projectile events, T-025) and packages/cards/README.md (the `projectile` field, T-026)
- packages/core/src/movement/ (T-012): integer millicell progress and line stepping

## Deliverables

1. A `projectiles` slice: every projectile in flight, with its id (`j…`), kind, speed, source unit, owner, world cell and progress, the damage it will deal, and either the target it homes on or the cell it's aimed at with its Trample area. Register the slice in `state/state.ts` (`Slices`) and `state/create.ts`, add `projectile: 'j'` to `ID_PREFIX` with a `ProjectileId` type in `state/ids.ts`, add `projectiles` to the slice lists in `state/state.test.ts` and `modules.test.ts`, and test the new prefix in `state/ids.test.ts`. Those are the only changes outside `projectiles/`.
2. `launchProjectile(state, attacker, target, { damage, trample })`:
   - creates a projectile on the attacker's cell, with the kind and speed from the attacker's card (T-026)
   - `damage` is the attacker's effective Attack at launch, from the caller
   - a projectile without Trample homes on its target. One with Trample is aimed at the target's cell at launch, the nearest cell for a footprint.
   - returns the `projectile.launched` payload
3. `stepProjectiles(state, cellsOf)` runs one tick:
   - Each projectile adds `millicellsPerTick(speed)` to its progress and moves whole cells along the line to its goal. Nothing blocks it. The goal is the target's current nearest cell, or the aim cell.
   - A homing projectile lands when it reaches a cell of its target. If the target died or left the arena first, it lands as a miss where it is.
   - An aimed projectile lands when it reaches its aim cell, whether its target is still there or not.
   - It returns the moves (`projectile.moved` payloads) and the landings. Each landing has the projectile, the cell, whether it hit, the target, the damage and its source, and the Trample area for an aimed one.
   - Landed projectiles are removed.
4. `clearProjectiles(state)`, for the end of Simulate.
5. A test that the protocol's `ProjectileKind` and the cards' `PROJECTILE_KINDS` list the same kinds.
6. Tests:
   - flight time from speed and distance, with no drift
   - homing onto a target that moves
   - a miss when the target dies in flight
   - a shell landing on its aim cell after its target walked away
   - determinism, and a JSON round trip mid-flight
   - 200 projectiles in flight at once

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green
- [ ] 200 projectiles stepped for 1000 ticks take under 200 ms (measured time in the PR)

## Out of scope

- When units attack, applying damage and triggers, and emitting events (T-020).
- Drawing projectiles (M3).

## Notes

- Like movement, this module returns values and never emits (M1 README › Events).
- Kill credit goes to the projectile's owner at launch, even when the unit that fired it dies first.
