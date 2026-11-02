---
id: T-022
title: Player view
milestone: M1
depends_on: [T-009, T-011, T-015, T-025]
branch: agent/T-022-player-view
scope:
  - packages/core/src/view/**
  - packages/core/test/fixtures/view/**
---

# T-022 — Player view

## Goal

Build the snapshot each seat plans from: everything that seat can see, and nothing it can't.

## Read first

- docs/PROTOCOL.md (Snapshot and visibility) and docs/tasks/M1/README.md
- docs/RULES.md on hidden information: Round structure (Plan), Non-unit permanents (traps), rituals

## Deliverables

1. `snapshotFor(state, seat): Snapshot`, which the protocol schema accepts in tests. Each hand card's and resource's `TargetSpec` comes from its caster choice in the card data (packages/cards/README.md › Caster choices).
   - `arena` is the layout for the snapshot's round, from `arena/` (T-011) in the protocol's `ArenaLayout` shape (T-025).
2. Hidden information stays hidden:
   - other seats' hands and decks appear only as counts
   - a face-down trap appears only for its owner
   - this round's rituals and plans stay hidden until they're revealed
3. Tests:
   - snapshots parse
   - for generated states, no other seat's hand card or face-down trap ever appears
   - the counts match

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green

## Out of scope

- Filtering events per seat: the protocol's `isVisibleTo` does that (T-009).
