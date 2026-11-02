---
id: T-009
title: Protocol v2
milestone: M1
depends_on: [T-002]
branch: agent/T-009-protocol-v2
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
---

# T-009 — Protocol v2

## Goal

Replace the M0 stubs with the real contract between core, bots and the UI: what a seat can do in a plan, every event the simulation reports, and the snapshot a seat plans from. Then document it in docs/PROTOCOL.md.

## Read first

- docs/tasks/M1/README.md: ids, coordinates, events
- docs/RULES.md: Round structure (Plan), Simulation rules, Resources and attaching, Non-unit permanents, Scoring and winning, Chaos deck and Emblems
- docs/DECISIONS.md: D3, D7, D12, and the `PROTOCOL_VERSION` rule under Working rules
- packages/protocol/README.md

## Deliverables

1. `Plan`: an ordered list of actions, as a discriminated union on `action`:
   - `castUnit` (hand card instance, grid cell, rotated), `castLeader` (cell, rotated), `moveLeader` (cell)
   - `levelUp` (squad), `attach` (squad, resource instances)
   - `castPermanent`, for artifacts, enchantments and traps: a hand card plus a grid cell for a free-standing card, or a squad for an attached one
   - `queueSorcery` and `castRitual`: a hand card, plus a target when the card needs one (a seat, a grid row, a grid area or a squad)
   - `useResource` (a resource's rest ability, such as Harvest Cycle's) and `discard` (hand cards)

   Paying is automatic: core pays from unrested resources, so no action lists them.
2. Events, all in the past tense, carrying ids and world cells (M1 README):
   - **Game and round:** `game.started`, `round.started`, `phase.changed`, `round.ended` (points per seat), `game.ended`, `tick`
   - **Planning:** `card.drawn`, `resource.drawn`, `plan.rejected` (seat, action index, reason), `plans.revealed`
   - **Board:** `squad.placed`, `unit.spawned`, `unit.moved`, `unit.attacked`, `unit.damaged`, `unit.healed`, `unit.died`, `unit.respawned`, `squad.leveled`, `squad.retired` (Durability reached 0)
   - **Cards:** `sorcery.resolved`, `ritual.resolved`, `ability.triggered`, `trap.set`, `trap.revealed`, `trap.fired`, `permanent.placed`, `permanent.destroyed`
   - **Chaos and score:** `chaos.revealed`, `chaos.despawned`, `emblem.broken`, `points.scored` (seat, amount, reason)
3. `isVisibleTo(event, seat)`. Events are the full record, so private events are visible only to their owner: a drawn card, a face-down trap, a ritual before the round starts.
4. `Snapshot` for one seat:
   - round, phase, tick, and the config a planner needs (the point target)
   - for every seat: shown points, hand and deck counts, resource counts
   - the seat's own hand (card instance, card id, type, cost, size, and unit stats) and resource pool (instances, rested or not)
   - every grid's squads and visible permanents (a face-down trap only for its owner)
   - the current Chaos cards and the Emblems
5. `PROTOCOL_VERSION` bumped to 2, and the README updated.
6. `docs/PROTOCOL.md`, written from the types: every command, action, event and snapshot field, the visibility rules, and the versioning rule.
7. Tests:
   - every action and event accepts a valid sample and rejects an invalid one
   - `isVisibleTo` hides private events from other seats
   - a Snapshot survives a JSON round trip

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green
- [ ] docs/PROTOCOL.md covers every exported schema

## Out of scope

- Producing events and snapshots: that's core (T-016 to T-023). Bots are T-017.

## Notes

- Bots import only the protocol (import rule 3). So a hand entry has to carry everything a planner needs: cost, type, size and unit stats.
- T-008 builds core at the same time, with the same ids and coordinates from the M1 README. Use them exactly.
