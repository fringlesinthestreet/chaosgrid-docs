---
id: T-012
title: Pathfinding and movement
milestone: M1
depends_on: [T-008]
branch: agent/T-012-movement
scope:
  - packages/core/src/movement/**
  - packages/core/test/fixtures/movement/**
---

# T-012 — Pathfinding and movement

## Goal

Move units toward their targets across the arena. That means shortest paths around blocked cells, speed in cells per second turned into steps per tick, and waiting when no path exists.

## Read first

- docs/CORE.md (coordinates, time, defaults) and packages/core/README.md
- docs/RULES.md: Simulation rules (Movement), Units (Speed, Static, Flying)

## Deliverables

1. A path search on the world grid: A* with 8-way steps and the Chebyshev metric, or a flow field. Tie-breaking is deterministic, with no RNG.
2. `stepToward(state, unit, goal, range)` for one tick:
   - accumulates `millicellsPerTick(speed)` in integers (T-008's `time/`, so there's no float drift) and moves whole cells
   - stops once the goal is within `range`
   - waits when the way is blocked
   - never moves a Speed 0 unit
3. Blocking per CORE.md defaults: one unit per cell, flying or not. Flying units block ground units and ground units block them; `Unit.layer` matters only for targeting.
4. A `movement` slice for each unit's progress (accumulator, cached path), keyed by unit id.
5. A helper that moves a unit to the nearest free cell in a direction. The push effect (T-018) uses it.
6. Performance: a 4-player arena with 120 units moving for 1000 ticks runs in under a second on a laptop. Check it with a test that has a generous time limit, and note the measured time in the PR.
7. Tests:
   - straight and diagonal paths, and paths around walls and other units
   - no path means the unit waits
   - Speed 1 against Speed 2 timing
   - static units, and flying and ground units blocking each other
   - determinism

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green

## Out of scope

- Choosing targets (T-013), and the order things happen within a tick (T-020).
