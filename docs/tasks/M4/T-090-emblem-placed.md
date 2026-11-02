---
id: T-090
title: The emblem.placed, prize.placed and permanent.healed events
milestone: M4
depends_on: [T-078]
branch: agent/T-090-emblem-placed
model: sonnet
effort: high
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/core/src/chaos/**
  - packages/core/src/round/game.ts
  - packages/core/src/round/game.test.ts
  - packages/core/src/round/cleanup.ts
  - packages/core/src/round/cleanup.test.ts
  - packages/core/src/round/round.test.ts
  - packages/core/src/combat/prize.test.ts
  - packages/core/src/view/**
  - tools/sim-cli/test/golden/**
context:
  - docs/PROTOCOL.md#Board
  - docs/PROTOCOL.md#Card events
  - docs/PROTOCOL.md#Chaos and score
  - docs/PROTOCOL.md#`ChaosSnapshot` and `EmblemSnapshot`
  - docs/PROTOCOL.md#Visibility
  - docs/PROTOCOL.md#Versioning
  - docs/tasks/M4/README.md#The match
---

# T-090 — The emblem.placed, prize.placed and permanent.healed events

## Goal

The web's match model is built from events alone (T-081), so a replay from a log draws exactly what the events say. Two permanents appear without an event. An Emblem Chaos card stands an Emblem on the Chaos Grid: `placeEmblem` emits nothing, and `chaos.revealed` has no cell. Every seat's prize is placed when the game is created (`placePrize`, before `game.started`). Snapshots show both (`EmblemSnapshot.cell`, `Snapshot.prizes`), but an events-only replay can't draw them, or the hits that break them. And a prize that survives a round hurt is back at full HP after Cleanup without an event, so the web would have to copy that rule to draw it (D29). After this task core emits `emblem.placed` when an Emblem stands, `prize.placed` for each seat's prize at the start of the game, and `permanent.healed` when Cleanup heals a hurt prize.

## Interfaces

What exists (copied from the code on 2026-10-28, plus T-101 and T-078):

```ts
// packages/core/src/chaos/spawn.ts:87
/** …No event: its `chaos.revealed` says it's there, and snapshots show it. */
export function placeEmblem(ctx: EffectsCtx, card: CardInstanceId): Permanent; // arenaCell: spawnCells(state, 'central', 1)
// packages/core/src/chaos/reveal.ts:49 calls it for a Chaos card of kind `emblem`

// packages/core/src/zones/setup.ts:91, called by createGame for every seat, before any event
export function placePrize(state: GameState, seat: Seat): Permanent; // 2x2, centred, hp = config.prizeHp
// packages/core/src/round/game.ts:33
export function newGame(setup, cards): NewGameResult; // emits game.started, then card.drawn and resource.drawn

// packages/core/src/round/cleanup.ts:196, private, Cleanup's step 4
/** …A destroyed one reports `permanent.respawned`; a hurt one that survived heals silently… */
function restorePrizes(ctx: Ctx): void; // every prize: alive = true, hp = config.prizeHp

// @chaosgrid/protocol (v23, after T-101 and T-078)
export const EmblemSnapshot = z.strictObject({ permanent, cardId, hp: Hp, points: z.number().min(0), cell: WorldCell });
export const PrizeSnapshot = z.strictObject({ permanent, seat: Seat, cell: Cell, size: Size, hp: Hp, maxHp: Hp, alive: z.boolean() });
export const EmblemBrokenEvent; // emblem.broken { permanent, cardId, breaker }
export const SquadPlacedEvent;  // squad.placed { seat, squad, …, cell: Cell, size: Size, … }: events name a grid cell `cell`
export const UnitSpawnedEvent;  // unit.spawned { …, at: WorldCell, … }: and an arena cell `at`
export const UnitHealedEvent;   // unit.healed { unit, source: EntityId | null, amount: Hp, hp: Hp }
export const PermanentDamagedEvent; // permanent.damaged { permanent, source, amount, hp }: public
export const PROTOCOL_VERSION; // T-078 leaves it at 23
```

What this task adds:

```ts
// @chaosgrid/protocol, in › Chaos and score, before EmblemBrokenEvent
/** An Emblem Chaos card stood an Emblem on the Chaos Grid. */
export const EmblemPlacedEvent = z.strictObject({
  type: z.literal('emblem.placed'),
  permanent: PermanentId,
  cardId: CardId,
  at: WorldCell,                // the same cell as EmblemSnapshot.cell
  hp: Hp,                       // its printed Durability
  points: z.number().min(0),    // what its breaker scores, as printed
});

// @chaosgrid/protocol, in › Board
/** A seat's prize stands in the middle of its grid. Once per seat, at the start of the game. */
export const PrizePlacedEvent = z.strictObject({
  type: z.literal('prize.placed'),
  permanent: PermanentId,
  seat: Seat,
  cell: Cell,                   // its top-left cell on that seat's grid, as in PrizeSnapshot
  size: Size,
  hp: Hp,                       // its full HP, PrizeSnapshot.maxHp
});

// @chaosgrid/protocol, after PermanentDamagedEvent
/** A hurt non-unit permanent healed. In M4 only Cleanup heals one: a prize that survived the round hurt. */
export const PermanentHealedEvent = z.strictObject({
  type: z.literal('permanent.healed'),
  permanent: PermanentId,
  source: EntityId.nullable(),  // what healed it, or null for a rule (Cleanup)
  amount: Hp,
  hp: Hp,                       // HP after healing
});
```

## Deliverables

1. **Protocol.** The three events in the `Event` union, seen by all (`isVisibleTo` returns true). `PROTOCOL_VERSION` 23 → 24, "`PROTOCOL_VERSION` is 24." and a v24 row in PROTOCOL.md's version table. Samples in `test/fixtures/samples.ts`.
2. **PROTOCOL.md.**
   - A row for `emblem.placed` in the Chaos and score table, before `emblem.broken`.
   - A row for `prize.placed` in the Board table.
   - A row for `permanent.healed` in the Card events table, after `permanent.damaged`.
   - The `PrizeSnapshot` paragraph: a prize appears with `prize.placed`; at Cleanup a destroyed one stands again with `permanent.respawned`, and a hurt one heals with `permanent.healed`.
   - The version in the title and under Versioning.
   - The protocol's docs test checks the tables against the schemas.
3. **Core.**
   - `placeEmblem` emits `emblem.placed` right after its `chaos.revealed`, with the same values the permanent gets. Fix its doc comment.
   - `newGame` emits one `prize.placed` per seat, in seat order, right after `game.started` and before the first `card.drawn`, from the prizes `createGame` placed.
   - `restorePrizes` emits `permanent.healed` for a prize that survived with less than its full HP: `source` null, `amount` the HP it gains, `hp` its full HP. A prize at full HP emits nothing, and a destroyed one still gets only `permanent.respawned`. Fix its doc comment.
4. **Golden files.** If `pnpm --filter @chaosgrid/sim-cli test` fails because the golden game now has the new events, regenerate with `UPDATE_GOLDEN=1 pnpm --filter @chaosgrid/sim-cli test`, and check that the diff is only the new events (and the version, if the files hold it).
5. **Tests:**
   - protocol: a valid `emblem.placed`, `prize.placed` and `permanent.healed` parse; a missing `at`, a missing `cell`, a negative `hp` and a negative `amount` fail with their paths; `isVisibleTo` is true for every seat
   - core: revealing an Emblem Chaos card emits `chaos.revealed`, then `emblem.placed` whose `at` and `hp` match the permanent and the snapshot's `EmblemSnapshot`
   - core: `newGame`'s events are `game.started`, then four `prize.placed` that match `Snapshot.prizes` (`permanent`, `seat`, `cell`, `size`, and `hp` = `maxHp`), then the draws
   - core (`cleanup.test.ts`): a prize hurt in Simulate and alive at Cleanup gets one `permanent.healed` whose `amount` is the damage it took and whose `hp` is `prizeHp`; an unhurt prize gets none; a destroyed one gets `permanent.respawned` and no `permanent.healed`
   - core: every `emblem.broken`, and every `permanent.damaged` for an Emblem or a prize, follows a placement event for the same `permanent` (a short seeded game, or the hidden-information test's games)
   - core: in the same games, folding `prize.placed`, `permanent.damaged`, `permanent.destroyed`, `permanent.respawned` and `permanent.healed` gives every prize the `hp` and `alive` its `PrizeSnapshot` has after each round

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/protocol test` and `pnpm --filter @chaosgrid/core test` pass
- [ ] `pnpm test` passes in every package (sim-cli and bots parse every event)
- [ ] `git diff --stat main -- tools/sim-cli/test/golden` shows only the golden files (or nothing)

## Out of scope

- A cell on `chaos.revealed` or on Chaos units: their `unit.spawned` events already have one.
- Other heals of a permanent's HP: none exists today. One added later emits `permanent.healed` with its `source`.
- Drawing the Emblem or the prize (T-082).

## Notes

- Default: `emblem.placed` comes after `chaos.revealed`, so a log reads "Chaos: <card>" before the Emblem appears. Ask lead if core's order makes that awkward.
- Field names follow the events' rule: a grid cell is `cell` (`squad.placed`), an arena cell is `at` (`unit.spawned`). `EmblemSnapshot` keeps its `cell`.
- A prize's arena position changes every round as seats rotate; `cell` is on its seat's grid, and `round.started`'s `arena` says where that grid is.
- Why `permanent.healed` (lead, 2026-10-28): without it the match model (T-081) would reset a prize's HP at Cleanup itself, a copy of a rule (D29). It's shaped like `unit.healed`, and public like `permanent.damaged`: a face-down trap can't be hit, so it never heals.
- T-101 and T-078 also change the protocol and bump the version (to 22, then 23). This card waits for them so the bumps don't collide; rebase on them.
- The UI's fixture logs (T-081) are made after this task, so they hold the three events.
