---
id: T-023
title: Round loop and public API
milestone: M1
depends_on: [T-014, T-018, T-019, T-020, T-021, T-022, T-025, T-028, T-034]
branch: agent/T-023-round-loop
scope:
  - packages/core/src/round/**
  - packages/core/test/fixtures/round/**
---

# T-023 — Round loop and public API

## Goal

Put the modules together into rounds and games, behind a small, pure API that the sim CLI calls now and the GameHost will call later.

## Read first

- packages/core/README.md, and every module's `index.ts`
- docs/RULES.md: Round structure (all four steps, including Cleanup), Scoring and winning
- docs/PLAN.md › Runtime shape: how GameHost will call this

## Deliverables

1. The public API in `round/` (re-exported by `src/index.ts`):
   - `newGame(setup, cards)` returns the state (through `zones.createGame`) and a `game.started` event
   - `beginRound(state)` runs Reveal (Chaos) and the round's draws, and returns the state, the events and a Snapshot per seat
   - `playRound(state, plans)` runs Plan, Simulate and Cleanup, and returns the state, the events and the winners

   `playRound` passes effects' hooks to `applyPlans` (T-021): no sorceries, level-up costs, and `settlePlanDraws` (T-018).

   Each one clones its input, so all three are pure: the same state, plans and seed always give the same output (D8).
2. Cleanup, in RULES.md's order:
   1. scoring (kills, survival, Emblems)
   2. surviving Chaos despawns
   3. fired traps go to the graveyard
   4. dead units respawn at full HP, on `unitStartCells` (T-028). A squad that died entirely loses 1 Durability (`squad.durabilityChanged`), and at 0 it goes to the graveyard.
   5. resources return and unrest
   6. hands are discarded down to the limit
   7. level unlocks are checked
   8. extra Chaos is checked
   9. the winner check
3. Events for every phase change and for the end of the round. `round.started` carries the round's `arena` layout (T-025).
4. Seats rotate every round (M1 README › Seat rotation), and `arena/` derives the rotation from `state.round`. When a round begins, put every squad's units back on their start cells for the new round (`unitStartCells`, T-028), before Reveal.
5. Tests:
   - a full game of several rounds with scripted plans
   - replaying the same inputs gives byte-identical events
   - a game ends when someone passes the target
   - in a 3- or 4-seat game, a squad stands on its seat's new grid position after the round changes

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green

## Out of scope

- Running many games and the event log files (T-024).
