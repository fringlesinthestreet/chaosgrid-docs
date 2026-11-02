---
id: T-047
title: The 4-player battlefield
milestone: M3
depends_on: [T-091, T-092, T-093, T-063]
branch: agent/T-047-battlefield
model: sonnet
effort: high
scope:
  - packages/protocol/src/**
  - packages/protocol/test/**
  - docs/PROTOCOL.md
  - packages/core/src/**
  - packages/core/test/**
  - packages/core/README.md
  - packages/bots/src/**
  - packages/bots/test/**
  - tools/sim-cli/src/**
  - tools/sim-cli/test/**
  - tools/sim-cli/README.md
context:
  - docs/PLAN.md#M3
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Components and setup
  - docs/RULES.md#Simulation rules
  - docs/RULES.md#Chaos deck and Emblems
  - docs/RULES.md#Balance knobs
  - docs/PROTOCOL.md#Coordinates
  - docs/PROTOCOL.md#Arena layout
  - packages/core/README.md#Config
---

# T-047 — The 4-player battlefield

## Goal

The arena becomes RULES.md's battlefield (D20, D22).

- Exactly 4 players.
- A shared 50 × 50 Chaos Grid sits in the center, and each player has a 30 × 30 grid on one side (top, bottom, left, right), facing the Chaos Grid across a 10-cell gap.
- The gaps and the corners are free space. It isn't anyone's grid, but units cross it and fight in it.
- Chaos units sent against a player spawn on the Chaos Grid's edge facing that player. They then attack the nearest player permanent, whoever owns it. Ties go to the seat they were sent against, then to the lowest instance id.
- The sizes are config values, carried in the protocol's arena layout. The bots read them from there.

## Interfaces

What exists (copied from the code):

```ts
// packages/protocol/src/primitives.ts:89-96, 125
export const GRID_SIZE = 15;
export const GridIndex = z.int().min(0).max(GRID_SIZE - 1);
export const Size = z.tuple([z.int().min(1).max(GRID_SIZE), z.int().min(1).max(GRID_SIZE)]);
// packages/protocol/src/arena.ts:23-90
ArenaSeat { seat, origin, right, back, strip }   // strip: grid rows −1 to −3, where its Chaos spawns
ArenaLayout { width, height, seats /* 2–4 */, center } // gridRect(...) uses GRID_SIZE
// packages/core/src/state/config.ts:14-16: gridCols and gridRows default to 15.
// packages/core/src/arena/layout.ts:22 STRIP_DEPTH = 3, :28 CENTER_SIZE = 15, :31 MIN_SEATS = 2
// packages/core/src/zones/setup.ts:46,90: createGame accepts 2 to 4 seats.
// packages/core/src/arena/spawn.ts:40: Chaos units spawn in `position.strip`.
// packages/core/src/targeting/choose.ts:145-150: a Chaos unit prefers the seats in `spawnedFor`.
// Bots use GRID_SIZE in src/grid.ts (the Grid class), src/placement.ts:30, src/targets.ts:67 and
// :75-76, and test/referee.ts:33.
```

What this task changes:

```ts
export const MAX_GRID_SIZE = 64; // replaces GRID_SIZE; GridIndex and Size are bounded by it
export const SEATS = 4;          // protocol: a game has exactly 4 seats
ArenaSeat { seat, origin, right, back, chaosEdge } // chaosEdge: the Chaos Grid's edge facing this seat
ArenaLayout { width, height, cols, rows, seats /* exactly 4 */, chaosGrid } // chaosGrid replaces center
// core config: gridCols = gridRows = 30, chaosGridSize = 50, gap = 10, chaosEdgeDepth = 3
// bots: new Grid(cols, rows), built from the snapshot's arena layout
export const PROTOCOL_VERSION = /* T-091's + 1 */;
```

## Deliverables

1. **Layout.** With the defaults, the battlefield is 130 × 130 cells.
   - The Chaos Grid is `x, y ∈ [40, 90)`.
   - The grids are top `x ∈ [50, 80), y ∈ [0, 30)`, bottom `x ∈ [50, 80), y ∈ [100, 130)`, left `x ∈ [0, 30), y ∈ [50, 80)` and right `x ∈ [100, 130), y ∈ [50, 80)`.
   - Each grid's row 0 faces the Chaos Grid and col 0 is on its player's left, as today.
   - The size comes from the config: `2 × (rows + gap) + chaosGridSize` each way, with every grid centered on its side.
   - Seat rotation stays as `arena/rotation.ts` does it now: seat 0 always keeps the bottom side, and in round r seats 1–3 sit r−1 places clockwise from their round-1 sides (left, top, right).
2. **Exactly 4 seats.** `createGame` throws for any other count, and so does the arena. Remove `MIN_SEATS` and the 2- and 3-seat layouts and samples. Tests that played 2 or 3 seats now play 4. Fill the extra seats with a player whose plans are empty, through a helper in `state/testing.ts`, so each test keeps what it checks.
3. **Free space.** Every cell of the bounding box is open battlefield: units may move through grids, the gaps, the corners and the Chaos Grid. Placement is still only on the seat's own grid. Movement and targeting don't treat free space differently.
4. **Chaos.**
   - A Chaos `units` card's squads spawn in the `chaosEdge` facing the seat they're sent against. The edge is the band of the Chaos Grid, `chaosEdgeDepth` cells deep, on the side nearest that seat's grid. They spawn across it, centered.
   - Emblems and Chaos artifacts stand in the middle of the Chaos Grid.
   - A Chaos unit's new target is the nearest player permanent, of any owner: drop the `spawnedFor` preference in targeting. Ties between equally near permanents go to the seat in `spawnedFor` (the one the unit was sent against), then to the lowest card instance id; this replaces lowest-HP ties for Chaos. `spawnedFor` also stays on the squad for events and scoring.
5. **Protocol.**
   - `MAX_GRID_SIZE` and `SEATS`.
   - `cols`, `rows` and `chaosGrid` in `ArenaLayout`, and `chaosEdge` in `ArenaSeat`. `gridRect` reads the layout.
   - A layout fails to parse without exactly 4 seats, or when a grid, an edge or the Chaos Grid leaves the box.
   - Bump `PROTOCOL_VERSION`. The samples have one 4-seat layout with the defaults and one with smaller sizes.
6. **Bots.** The grid, placement, targets and the referee read the sizes from the snapshot. Their tests cover the default and a small layout.
7. **Perf.**
   - `pnpm --filter @chaosgrid/core test -- perf` stays green on the default battlefield.
   - In the PR, report seconds per game from `pnpm sim --bots greedy,greedy,greedy,greedy --games 20 --seed 1 --decks starter`, before and after.
   - Also report the first tick at which units of two seats fight (the first `unit.damaged` from an attack), and the first tick at which Chaos does.
   - If pathing is too slow on 130 × 130, make it cheaper, as T-046 › Deliverable 3 describes.
8. **sim-cli.**
   - Raise soak test timeouts only if needed, regenerate the goldens and update the timings in the README.
   - `--bots` takes exactly four names.
   - `--tournament` still takes 2 to 4 bots, but every matchup now plays at 4 seats: the lineup repeats to fill them, with seat `s` playing `lineup[(s + i) % n]` as today. Update its README section and its tests.
9. **Docs.** docs/PROTOCOL.md › Coordinates and › Arena layout get the new fields and a diagram copied from RULES.md, plus a line in › Versioning. packages/core/README.md › Config lists the battlefield values.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `grep -rn "GRID_SIZE\|STRIP_DEPTH\|CENTER_SIZE\|MIN_SEATS" packages tools --include='*.ts' | grep -v MAX_GRID_SIZE` prints nothing
- [ ] An ASCII map test (`packages/core/test/fixtures/arena/`) of the default battlefield in round 1 and round 2 (rotated)
- [ ] A core test: a Chaos squad sent against seat 0 spawns on the Chaos Grid's bottom edge (seat 0's side), but attacks seat 1's unit when that unit is nearer
- [ ] A core test: with a seat 0 unit and a seat 1 unit equally near, a Chaos unit sent against seat 0 attacks seat 0's; with two seat 1 units equally near, the lower id
- [ ] The PR body has seconds per game and the first-contact ticks, before and after

## Out of scope

- The prize in the middle of each grid: T-048
- Scaling ranges, speeds or the round timer: report the first-contact ticks. `lead` raises the round timer to fit them, and M5 balances it (RULES.md › Balance knobs)
- Lobbies that pick sizes or fill seats: M6. The host and sim-cli fill seats with bots.

## Notes

- `MAX_GRID_SIZE` only bounds what the protocol accepts. It isn't a rule.
- Default: the edge band is inside the Chaos Grid, 50 × 3. Cells on the Chaos Grid aren't anyone's, so no player can place there.
- Default: with the new layout, opposite grids are 70 cells apart front to front, and neighbours about 21 across a corner. If first contact comes much later than before, say so in the PR and to `lead`.
