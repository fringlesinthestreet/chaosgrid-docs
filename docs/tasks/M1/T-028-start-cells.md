---
id: T-028
title: Unit start cells
milestone: M1
depends_on: [T-011]
branch: agent/T-028-start-cells
scope:
  - packages/core/src/arena/**
  - packages/core/test/fixtures/arena/**
---

# T-028 — Unit start cells

## Goal

Give every unit its own starting cell, including squads with more units than footprint cells and units an effect spawns. Casting, respawning, new rounds and spawn effects then all place units the same way.

## Read first

- docs/CORE.md › Cells during the simulation, and packages/core/README.md
- packages/core/src/arena/ (T-011): `placementWorldCells`, `canPlace`, `spawnCells`

## Deliverables

1. `unitStartCells(state, seat, placement, count)`: world cells for `count` units of a squad placed at `placement` this round.
   - The footprint's own cells come first: front row first, then left to right from the player's view.
   - When the footprint is too small, the rest go on the nearest free cells: by Chebyshev distance from the footprint, then in the same order.
   - It never uses another squad's footprint or a cell holding a living unit. It's deterministic, with no RNG.
2. `freeCellsNear(state, cell, count)`: the nearest free world cells around a cell, in a fixed order, for the `spawn` effect (T-018).
3. Tests:
   - a full footprint, a 1×1 squad of 3, and a crowded neighbourhood
   - grid edges and rotated footprints
   - every seat and round
   - determinism

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green

## Out of scope

- Casting squads (T-021), respawning and new rounds (T-023), and the spawn effect (T-018).
