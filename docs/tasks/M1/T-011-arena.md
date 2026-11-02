---
id: T-011
title: Arena layout and placement
milestone: M1
depends_on: [T-008]
branch: agent/T-011-arena
scope:
  - packages/core/src/arena/**
  - packages/core/test/fixtures/arena/**
---

# T-011 — Arena layout and placement

## Goal

Build the shared battlefield: where each player's 15×15 grid sits around the center for 2, 3 and 4 players, how grid cells map to world cells as seats rotate each round, and whether a footprint fits on a grid.

## Read first

- docs/CORE.md (coordinates and defaults) and packages/core/README.md
- docs/RULES.md: Components and setup (Arena layout), Units (Size), Non-unit permanents, Chaos deck and Emblems (where Chaos spawns)

## Deliverables

1. Arena layouts for 2, 3 and 4 seats. Each layout gives:
   - each grid's position and facing
   - a neutral strip in front of each grid, where that player's Chaos units spawn
   - a central zone, for Emblems and Chaos artifacts

   The layout sizes are named constants.
2. `gridToWorld` and `worldToGrid` for a seat in a given round, with row 0 facing the center.
3. Seat rotation per round (CORE.md default), as a pure function of the round and the seat count.
4. Placement:
   - footprints come from `footprintCells` and `placementCells` in `state/` (T-008); don't redefine them
   - `canPlace(state, seat, footprint)`: the footprint is on the grid and overlaps no other unit's or free-standing permanent's footprint. Traps may overlap permanents (RULES.md › Units).
   - `spawnCells(state, seat or central, count)`, for Chaos
5. An `arena` state slice, if the layout needs one (for example, this round's rotation).
6. Tests:
   - every 2–4 seat layout has grids and zones that don't overlap
   - the grid and world transforms invert each other
   - rotation changes each seat's neighbours
   - placement accepts and rejects the right footprints, including rotated ones and ones at the grid edges

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green
- [ ] An ASCII map of each layout in `packages/core/test/fixtures/arena/`, checked by a test

## Out of scope

- Movement and pathing (T-012) and the Chaos deck (T-019).

## Notes

- The round timer must let a Speed 1 unit cross the arena (RULES.md › Balance knobs). Keep the distance from a grid's front row to the opposite grid well under 100 cells.
