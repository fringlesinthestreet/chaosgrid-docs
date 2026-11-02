---
id: T-020
title: Tick loop and combat
milestone: M1
depends_on: [T-011, T-012, T-013, T-016, T-018, T-025, T-026, T-027]
branch: agent/T-020-combat
scope:
  - packages/core/src/combat/**
  - packages/core/test/fixtures/combat/**
---

# T-020 — Tick loop and combat

## Goal

Run Simulate: sorceries at tick 0, then every tick in RULES.md's order until the round ends, with all units acting at the same time.

## Read first

- docs/tasks/M1/README.md (simultaneity, and the Movement in range and Projectiles defaults) and packages/core/README.md
- docs/RULES.md: Round structure (Simulate, end conditions), all of Simulation rules, Non-unit permanents (Traps)
- the arena, movement, targeting, effects and projectiles modules (T-011, T-012, T-013, T-016, T-018, T-027)

## Deliverables

1. `simulate(ctx)`:
   - **Tick 0:** every queued sorcery resolves at once. When two conflict, the kill happens first.
   - **Every tick after that**, in this order:
     1. triggers and traps whose condition became true last tick fire
     2. abilities off cooldown fire
     3. units with a target in range attack, and the others move:
        - a Melee hit lands at once; a Ranged or Artillery attack launches a projectile (T-027)
        - a unit whose target is in range never moves, even while its attack cools down. The others move toward their target, passing their effective range to `stepToward`, so they stop as soon as it's in range and move again when it leaves.
        - projectiles in flight then advance, and those that land add their hits to this tick's damage
     4. damage is applied, units at 0 HP die, and their On death triggers queue for the next tick
2. Simultaneity: every attack in a tick is decided on the state at the start of the attack step, and an attack on a unit that died misses. Melee hits and projectiles landing in the same tick are applied together.
3. Combat details:
   - attack cooldowns come from attack speed
   - Trample splashes. A Melee Trample hit splashes around the unit hit. A Trample projectile splashes the area around the cell it was aimed at when it lands, whoever is there.
   - On attack abilities fire when the hit lands: at once for Melee, when the projectile hits for Ranged and Artillery. A projectile that misses triggers nothing.
   - targeting's `statsOf` is built from the effective stats and keywords (T-016, T-018), so granted Reach and Ignores Blockers count
   - Blocker taunts, through targeting
   - kills are credited in the form scoring takes as input
4. Traps: each face-down trap's trigger is checked every tick (an enemy enters its area, its attached unit is hit or dies, a sorcery targets its area, after N seconds). A trap fires once and is then revealed.
5. End conditions, whichever comes first:
   - the round timer runs out (config: 1000 ticks)
   - only one player has units left, and no Chaos remains
   - Chaos has killed every player's permanents
6. Events for every move, attack, projectile (launched, moved, landed), damage, death and trap, plus a `tick` event every tick.
7. Tests:
   - the tick order, and simultaneous kills
   - attacks on a unit that just died
   - cooldown timing
   - a Ranged unit stops at its range and doesn't creep closer while its attack cools down, and moves again when its target leaves range
   - projectile damage lands after the flight time, a projectile whose target died misses, and a shell hits whoever is in its area after its target walked away
   - every trap trigger and every end condition
   - a small scripted battle whose event stream is checked exactly

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green
- [ ] A 4-player round with 120 units finishes in under 2 seconds (measured time in the PR)

## Out of scope

- Applying plans (T-021) and Cleanup (T-023).
