---
id: T-170
title: Live unit stats in core and protocol
milestone: M5
depends_on: [T-157, T-163, T-164]
branch: agent/T-170-live-unit-stats-in-core-and-protocol
model: opus
effort: high
scope:
  - packages/protocol/src/**
  - packages/protocol/README.md
  - packages/core/src/**
  - packages/core/README.md
  - docs/PROTOCOL.md
  - apps/web/src/match/model/**
  - apps/web/test/fixtures/**
  - tools/sim-cli/test/golden/**
  - apps/web/src/match/battlefield/pick.test.ts
  - apps/web/src/match/CardView.test.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - packages/protocol/test/fixtures/samples.ts
  - packages/core/test/fixtures/combat/setup.ts
context:
  - docs/PROTOCOL.md#Conventions
  - docs/PROTOCOL.md#Board
  - docs/PROTOCOL.md#Visibility
  - docs/PROTOCOL.md#Versioning
  - packages/core/README.md#Events
  - packages/core/README.md#Previews
  - tools/sim-cli/README.md#Usage
---

# T-170 — Live unit stats in core and protocol

## Goal

The human's playtest (2026-11-04): "on simulation, when clicking permanents show current stats: HP, speed, attack, etc.. not the static MAX HP, etc.. if buffs were applied then stats change".

Clients see a unit's printed stats and nothing of what buffs, levels and auras make of them: the web guesses max HP from spawns and heals. Its keywords are in the round-start snapshot only, so a keyword granted mid-round (Rising Tide's Reach) never shows, and the web model holds none. After this task core sends a public `unit.statsChanged` whenever a unit's effective stats or keywords change, and the web model keeps them. T-171 shows them in the card view; T-162 draws the keywords as badges.

## Interfaces

What exists (copied on 2026-11-04):

```ts
// packages/core/src/effects/stats.ts:33. A unit's stats now, in card units.
export interface EffectiveStats {
  hp: number; // maximum HP
  attack: number;
  attackSpeed: number; // hits per second, 0 can't attack
  speed: number; // cells per second
  range: number; // cells
  minRange: number; // cells
  damageTaken: number; // ×1 by default
  rangeClass: Range; // printed, never changes
  charge: number; // never changes
}
export function makeStatsOf(state: GameState, toWorld?: ToWorld): (unit: Unit) => EffectiveStats; // :283, one moment's statics worked out once
// packages/core/src/effects/keywords.ts:149. Printed, plus static grants, plus lasting grants.
export function effectiveKeywords(state, unit, changes = staticKeywordChanges(state)): EffectiveKeywords;

// combat/simulate.ts:83 endTick(ctx, board) ends every Simulate tick; combat/settle.ts:85 settleTick.
// combat/state.ts:24 CombatState, in GameState.combat: plain JSON only.
// round/preview.ts:62 a preview's ctx.emit only counts events for its tally.

// packages/protocol/src/snapshot.ts:325 UnitSnapshot: maxHp ("with level and buffs") and
// keywords ("printed plus granted, each once"), sent at round start only.
// packages/protocol/src/card.ts:84 UnitStats: a card's printed level-1 stats, per second.

// apps/web/src/match/model/types.ts:51 UnitModel.maxHp: "The HP it spawned or respawned with,
// raised by a heal that goes above it". apply.ts:469 switches over every event type (`never`).
```

docs/PROTOCOL.md › Conventions: "The only per-second numbers are a unit card's printed stats (`UnitStats`), copied from the card data as printed."

## Deliverables

1. **The event.** `UnitStatsChangedEvent`, `unit.statsChanged`: `{ unit, stats, keywords }`. `stats` is a new `LiveUnitStats`: every stat in `UNIT_STATS`, as `EffectiveStats` holds them: `maxHp`, `attack`, `attackSpeed`, `speed`, `range`, `minRange`, `damageTaken`. `keywords` is the protocol's `Keywords`, listed as `UnitSnapshot.keywords` lists them. It's public, as every unit event is. Bump `PROTOCOL_VERSION` to 30, the next after T-157's 29.
2. **docs/PROTOCOL.md:**
   - The event's row in › Board.
   - Its line in › Visibility, if that lists events.
   - Version 30 in › Versioning.
   - The time rule names the live stats as the second per-second exception: Attack speed and Speed are rates, not times. The protocol README follows wherever it lists events.
3. **Core sends it.** Core keeps, per unit, the stats and keywords it last sent. It checks every living unit at the end of every Simulate tick and settle tick, and once after Cleanup. When a unit's stats or keywords differ from the last ones sent, core sends `unit.statsChanged`, in unit id order. A unit with nothing sent yet always differs, so the first tick of the first Simulate sends every unit's, and a spawned unit's go out at the end of its spawn tick. A dead unit sends nothing until it respawns.
   - Where to keep what was sent: in the state, plain JSON, kept from round to round. Say where in the PR.
   - Make `makeStatsOf` and the keyword changes once per check, not once per unit. The packages/core README's › Events gets a line on the event.
4. **Previews skip it.** No preview sends `unit.statsChanged` or does its work. Say in the PR how the preview path turns it off.
5. **The web model keeps it.**
   - `UnitModel.stats` (`LiveUnitStats | null`) and `UnitModel.keywords` (`Keywords | null`) are null until the unit's first `unit.statsChanged`, then hold the latest.
   - The event also sets `maxHp` to `stats.maxHp`. Update `maxHp`'s doc comment.
6. **Fixtures and goldens.** Regenerate the sim-cli goldens and the web's fixtures with the commands that make them: never by hand.
7. **Tests:**
   - protocol: the event parses; a negative stat fails; `isVisibleTo` gives it to every seat.
   - core:
     - the first tick sends every living unit's, in id order;
     - a tick in which nothing changed sends none;
     - a timed buff sends the new value in the tick it lands, and its end sends the old one;
     - a granted keyword (Rising Tide's or Lighthouse's Reach) is in the unit's `keywords`;
     - a unit spawned mid-round gets its own at the end of its spawn tick;
     - after Cleanup, a unit whose timed buff ended gets its own again;
     - a preview sends none.
   - web model: the event sets `stats`, `keywords` and `maxHp`. A unit with none has `stats` and `keywords` null.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm test:soak` passes.
- [ ] `pnpm test:perf` passes, and the PR lists `round/perf.test.ts`'s preview times before and after, which should stay within 5%.
- [ ] One full 4-seat round (`playRound`, as the soaks play it) takes at most 12% longer than before; the PR gives both times and how they were measured.
- [ ] `pnpm --filter @chaosgrid/web test model` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Showing the stats: T-171 (the card view) and T-162 (the badges).
- Live stats in the snapshot: clients get them from the events, and a snapshot comes only at round start.
- Non-unit permanents: prizes and other permanents with HP already send their HP events.

## Notes

- Defaults: the type is called `LiveUnitStats`.
- Stats change from more than buffs: a static aura that covers by position switches on and off as units move. The check at each tick's end catches it; if that sends many events, say how many per round in the PR.
- The rates go out per second, like `UnitStats`, so a client shows them as the cards print them. The lead approves the extra exception to the time rule; times stay in ticks.
