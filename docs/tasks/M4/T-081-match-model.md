---
id: T-081
title: Match model and the event-log fixtures
milestone: M4
depends_on: [T-068, T-078, T-090]
branch: agent/T-081-match-model
model: sonnet
effort: high
scope:
  - apps/web/src/match/model/**
  - apps/web/test/fixtures/logs/**
context:
  - docs/tasks/M4/README.md#The match
  - docs/tasks/M4/README.md#Web layout and ownership
  - docs/PROTOCOL.md#Coordinates
  - docs/PROTOCOL.md#Events
  - docs/PROTOCOL.md#Visibility
---

# T-081 — Match model and the event-log fixtures

## Goal

The battlefield, the scoreboard and the round log all draw from the same event stream, the live one from the host or a sim-cli log in the replay viewer. After this task `match/model/` folds events into a `MatchModel`, a plain description of the board and the score that the screens draw, and `test/fixtures/logs/` holds sim-cli logs that every match and replay test uses.

## Interfaces

What exists (copied from the code on 2026-10-28, protocol v21, plus T-078, T-090 and T-101):

```ts
// @chaosgrid/protocol
export type Event; export type EventType;         // the Event union, discriminated on `type`
export function isVisibleTo(event: Event, seat: Seat): boolean;
// Positions in events are whole cells: `Cell` on a seat's grid, `WorldCell` in the arena (PROTOCOL.md › Coordinates).
// Sub-cell positions stay inside core (T-046); the UI never sees them.
// round.started carries the round's ArenaLayout; squad.placed is an upsert keyed by squad;
// unit.spawned has `at`, `layer`, `hp`; emblem.placed (T-090) has the Emblem's `at`, `hp`, `points`;
// prize.placed (T-090) has the prize's `seat`, `cell`, `size`, `hp`, once per seat after game.started;
// permanent.healed (T-090) { permanent, source: null, amount, hp }, like unit.healed: a prize healed at Cleanup.
// simulate.ending (T-101) { tick, reason }: the end condition held; the round settles until simulate.ended (D38).
// Chaos squads and tokens have no footprint on a grid: their units get unit.spawned, never squad.placed.
// M3 state events: unit.feared (`until`, a tick) and unit.fearEnded; unit.shielded (`shieldLeft`);
// unit.saved (`livesLeft`, back at full HP); squad.sacrificed, squad.revived, squad.despawned (a token);
// permanent.durabilityChanged, permanent.respawned, permanent.retired; card.banished (from the grid:
// its `squad` or `permanent` leaves at once, with no unit.died), cards.dumped, cards.discarded.

// tools/sim-cli (README › Event logs): `--log FILE` saves game 1's log, a JSON array of Events,
// one per line, every seat's events included.
```

What this task adds (`apps/web/src/match/model/`, exported from `index.ts`):

```ts
export interface MatchModel {
  seats: Seat[];
  settings: GameSettings | null;
  round: number;                         // 0 before round.started
  phase: Phase | null;
  tick: number;                          // the latest `tick` event of this Simulate, 0 outside it
  arena: ArenaLayout | null;             // this round's
  points: Record<Seat, number>;          // shown points: points.scored adds, round.ended's scores set
  squads: Record<SquadId, SquadModel>;   // from squad.placed (seat, card, cardId, leader, cell, rotated, size, level, durability, sacrificed, retired)
  units: Record<UnitId, UnitModel>;      // squad, owner, cardId, at, from, layer, hp, maxHp, alive, rested,
                                         // fearedUntil (tick | null), shieldLeft and livesLeft (null until an event says)
  projectiles: Record<ProjectileId, ProjectileModel>; // kind, owner, at, from, target
  permanents: Record<PermanentId, PermanentModel>;    // traps, artifacts, enchantments, Emblems and prizes:
                                         // kind, owner, cardId (null for a prize), where, faceDown, hp, maxHp, durability, alive
  chaos: ChaosModel[];                   // this round's chaos.revealed, in order
  simulateEnding: number | null;         // this round's simulate.ending tick (T-101): the settle starts
  simulateEnded: { tick: number; reason: SimulateEndReason } | null;
  winners: Seat[] | null;
  log: LogEntry[];                       // the events the round log shows, oldest first
}
export interface LogEntry { round: number; tick: number | null; event: Event } // event is one of LOGGED_EVENT_TYPES
export type SimulateEndReason = SimulateEndedEvent['reason']; // the protocol has no name for it
export type ChaosModel = Omit<ChaosRevealedEvent, 'type'>;     // card, cardId, kind, extra, targets
export const LOGGED_EVENT_TYPES: readonly EventType[];
export const EMPTY_MODEL: MatchModel;
/** Pure: returns a new model and never changes its input. */
export function applyEvents(model: MatchModel, events: readonly Event[]): MatchModel;
export function applyEvent(model: MatchModel, event: Event): MatchModel; // applyEvents(model, [event])
```

## Deliverables

1. **The fold.** One `switch` over `event.type` with a `never` check, so a new event type fails `typecheck` here until it's handled. Every event either changes the model or is listed as changing nothing.
   - Game and round: `game.started` sets `seats`, `settings` and zero points; `round.started` sets `round` and `arena`, clears `chaos`, `tick`, `simulateEnding` and `simulateEnded`; `phase.changed`, `tick`, `simulate.ending` (sets `simulateEnding` to its tick), `simulate.ended`, `game.ended`.
   - Board: `squad.placed` upserts; `unit.spawned` adds with `maxHp = hp` (a Chaos or token unit too, whose `squad` isn't in `squads`); `unit.moved` sets `from` and `at`; `unit.damaged` and `unit.healed` set `hp` (a heal above `maxHp` raises it); `unit.died` and `unit.respawned`; `unit.rested`, cleared at `round.ended`; `squad.leveled` and `squad.durabilityChanged`; `squad.retired` sets the squad's `retired: true` and removes its units, so the round log and the summary can still name it (T-088); `chaos.despawned` removes what it lists.
   - M3 unit state: `unit.feared` sets `fearedUntil`, `unit.fearEnded` clears it; `unit.shielded` sets `shieldLeft`; `unit.saved` sets `livesLeft` and `hp = maxHp`. `shieldLeft` and `livesLeft` clear at `round.ended`. Fear doesn't: Cleanup ends every fear with a `unit.fearEnded` (core's `endAllFears`).
   - M3 squads: `squad.sacrificed` marks the squad (it retires at Cleanup); `squad.revived` changes nothing itself, as its `squad.placed` and `unit.spawned` follow; `squad.despawned` removes a token squad and its units; `card.banished` with a `squad` removes the squad and its units, and with a `permanent` removes the permanent.
   - Projectiles: launched, moved, landed (removed).
   - Permanents: `trap.set`, `trap.revealed`, `permanent.placed`, `emblem.placed`, `prize.placed`; `permanent.damaged` and `permanent.healed` set `hp` (Cleanup heals a hurt prize with `permanent.healed`, T-090); `permanent.destroyed` sets `alive: false` and `permanent.respawned` brings it back with its `hp`; `permanent.durabilityChanged`; `permanent.retired` and `emblem.broken` remove it.
   - Score: `points.scored`, `round.ended`.
   - Events with no lasting state (`unit.attacked`, `ability.triggered`, `spell.resolved`, `trap.fired`, `card.drawn`, `resource.drawn`, `cards.dumped`, `cards.discarded`, `plan.rejected`, `plan.checked`, `plans.revealed`) change nothing but the log. Piles, the void and the hand come from the seat's snapshot (T-086, T-100). The battlefield animates events from each step's events (T-082).
2. **The log.** `LOGGED_EVENT_TYPES`: `chaos.revealed`, `plans.revealed`, `unit.died` (Leaders only: the squad's `leader`), `squad.retired`, `trap.fired`, `emblem.broken`, `points.scored` (non-zero), `plan.rejected`, `simulate.ended`, `round.ended`, `game.ended`, and from M3 `squad.sacrificed`, `squad.revived`, `card.banished`, `unit.saved`, `cards.dumped` and `cards.discarded` (both non-empty). Entries keep the event; the round log (T-088) writes the sentences.
3. **Robust to a filtered stream.** The live stream leaves out what the seat can't see (`isVisibleTo`), so an event can name a unit, squad or permanent the model doesn't have. Skip it; never throw.
4. **Speed.** `applyEvents` copies the model once per call and updates the copy, so a whole round (tens of thousands of events at 100 ticks a second) folds in well under a second. `applyEvent` is `applyEvents` with one event.
5. **Fixtures** (`apps/web/test/fixtures/logs/`), made with sim-cli after T-090 has merged:
   - `starter-2-rounds.json`: `pnpm sim --games 1 --seed 1 --bots greedy,greedy,turtle,random --decks starter --rounds 2 --log apps/web/test/fixtures/logs/starter-2-rounds.json`
   - `emblem.json`: the same with the first `--seed` whose game reveals an Emblem Chaos card in its first two rounds (search seeds from 1 with a short script, and don't commit the script)
   - `README.md`: what each file is, the exact command, and "regenerate both after a protocol change that changes a payload"
   - Each file under 3 MB. If one is larger, drop to `--rounds 1` and say so in the handoff.
   - In the handoff, list which M3 event types the two logs hold. The hand-built tests cover the rest.
6. **Tests:**
   - every fixture event parses with the protocol's `Event` schema (a protocol change that breaks the fixtures fails here first)
   - folding each fixture never throws; after each `round.ended`, `points` equal its `scores`
   - folding a fixture filtered with `isVisibleTo(event, 0)` never throws, and seat 0's squads and units equal those of the full fold
   - hand-built events: `squad.placed` twice moves the squad; damage, death and respawn; `squad.retired` keeps the squad with `retired: true` and drops its units; `chaos.despawned`; an Emblem placed, damaged and broken; a prize placed, destroyed and respawned, and a hurt one healed by `permanent.healed`; a projectile launched, moved and landed; `unit.rested` cleared at `round.ended`; `simulate.ending` sets `simulateEnding`, and the next `round.started` clears it
   - hand-built M3 events: a fear that starts and ends; a Shield hit and an Extra life save; a sacrificed squad that retires; a revive (`squad.revived`, `squad.placed`, `unit.spawned`); a squad and a permanent banished from the grid; a token spawned and despawned; a permanent destroyed, losing Durability and respawned, and one retired
   - `applyEvents` doesn't change its input (deep-freeze the model and the events)
   - `emblem.json` has an `emblem.placed`, and both logs have four `prize.placed`

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test -- model` passes
- [ ] `ls -l apps/web/test/fixtures/logs/` shows both logs under 3 MB

## Out of scope

- Drawing anything (T-082), playback timing (T-083), the round log's text (T-088).
- The hand, the pool, the Leader in the command zone: the planning panel reads them from the seat's snapshot (T-086).

## Notes

- Default: `maxHp` is the HP a unit spawned or respawned with, raised by a heal that goes above it. Events carry no max HP (only `UnitSnapshot.maxHp` does, and the fold reads no snapshots); ask lead if a buffed unit's bar looks wrong in a fixture.
- Default: `shieldLeft` and `livesLeft` stay null until the unit's first `unit.shielded` or `unit.saved`. The battlefield (T-082) draws a printed Shield or Extra life from the card while they're null.
- Default: records keyed by id, not `Map`s, so tests can compare models with `toEqual` and the replay can store them.
- Default: a retired squad stays in `squads` with `retired: true` for the rest of the game, and its units leave `units`. The round log and the summary (T-088) name it from there; the battlefield draws no retired squad.
- The fixtures are the UI's test data for the rest of M4: T-082, T-083 and T-088 read them. A later task that changes a payload regenerates them, and its card lists this folder in its scope.
