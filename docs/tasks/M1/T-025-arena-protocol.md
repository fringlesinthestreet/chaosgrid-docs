---
id: T-025
title: Protocol v3
milestone: M1
depends_on: [T-009, T-011, T-017]
branch: agent/T-025-arena-protocol
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/bots/test/fixtures/**
---

# T-025 — Protocol v3

## Goal

Three additions to the protocol, in one version bump:

- the arena layout, so the UI and the bots know where every grid, Chaos strip and the central zone sit each round, without importing core's `arena/` (D3)
- projectiles in flight, so the UI can draw arrows, fireballs and shells where they are
- Durability changes, which no event reports today

Core fills the new fields and emits the new events later (T-020, T-022, T-023, T-018).

## Read first

- docs/PROTOCOL.md (Coordinates, Events, Snapshot, Versioning) and packages/protocol/README.md
- packages/core/src/arena/ (T-011): `arenaLayout`, `layoutOf`, `seatGrid` and the ASCII maps in `packages/core/test/fixtures/arena/`. The protocol's layout mirrors them.
- docs/tasks/M1/README.md: Ids, Coordinates, the Seat rotation and Projectiles defaults
- docs/RULES.md › Simulation rules (Attacking, Projectiles)

## Deliverables

1. An `ArenaLayout` schema, in world cells:
   - the arena's `width` and `height`
   - per seat, in seat order: the seat's grid this round, as the frame T-011 uses (`origin`, the world cell of grid cell `{ col: 0, row: 0 }`, plus the unit vectors `right` and `back`), and its neutral strip as a world rectangle
   - the central zone, as a world rectangle
   - a `WorldRect` (`x`, `y`, `width`, `height`) for the rectangles
2. `Snapshot.arena`: the layout for the snapshot's round.
3. `RoundStartedEvent.arena`: the layout for the round that starts, so an event log alone says where each grid is every round (seats rotate).
4. Projectiles:
   - `ProjectileId` (`j12`, M1 README › Ids) and `ProjectileKind`: `arrow`, `bolt`, `fireball`, `waterball`, `shell`, `orb`. packages/cards lists the same kinds (T-026).
   - `projectile.launched`: `projectile`, `kind`, `source` (the unit that fired), `owner`, `from` (world cell), `speed` (cells per second), `target` (what it was fired at), and `aim`: the world cell a Trample projectile flies to, or null for one that homes on its target
   - `projectile.moved`: `projectile`, `from`, `to` (world cells), whenever it enters a new cell
   - `projectile.landed`: `projectile`, `at` (world cell), `hit` (false when it missed because its target died or left the arena first). The damage it deals is reported by the existing damage events.
5. `squad.durabilityChanged`: `squad`, `durability` after the change. Core emits it when a Durability heal (Kettle) or Cleanup's −1 for a wiped squad changes a squad's Durability. `squad.leveled` and `squad.retired` stay as they are.
6. Every new event is visible to every seat.
7. `PROTOCOL_VERSION` goes to 3, with a row in docs/PROTOCOL.md › Versioning. The Snapshot and event tables describe the new fields and events.
8. Update the Snapshot fixtures in `packages/bots/test/fixtures/` so they parse under version 3. Don't change the bot itself.
9. Tests:
   - layouts for 2, 3 and 4 seats parse, survive a JSON round trip, and are rejected with a missing or repeated seat
   - each new event parses, and `projectile.launched` rejects an unknown kind
   - the new events and `round.started` are visible to every seat

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green

## Out of scope

- Filling `Snapshot.arena` (T-022) and `RoundStartedEvent.arena` (T-023), and emitting the projectile (T-020) and Durability events (T-018, T-023).
- Drawing the arena and projectiles (M3).

## Notes

- Decided by the human (2026-10-21): the arena layout reaches the UI through the protocol. Core's public entry doesn't export `arena/`.
- Keep the layout a plain copy of T-011's, so core fills it without converting anything.
- Projectile positions are whole world cells, like units'. The UI interpolates between ticks.
