---
id: T-035
title: Shared plan draft for bots
milestone: M2
depends_on: [T-017]
branch: agent/T-035-plan-draft
model: opus
effort: medium
scope:
  - packages/bots/**
  - tools/sim-cli/src/bots.ts
  - tools/sim-cli/src/command.test.ts
context:
  - packages/bots/README.md
  - docs/PROTOCOL.md#Plans
  - docs/PROTOCOL.md#Arena layout
---

# T-035 — Shared plan draft for bots

## Goal

Move the bookkeeping every bot needs (its copy of the pool and the grids, the cards it casts, the hand-limit discard) out of `RandomPlanner` into a shared `PlanDraft`, and add the placement helpers M2's bots share. Also export stub `createGreedyBot` and `createTurtleBot`, registered in sim-cli. Then T-036, T-037 and T-038 can run side by side without sharing a file. RandomBot's plans don't change.

## Interfaces

What exists (copied from the code):

```ts
// src/bot.ts
export interface Bot { readonly name: string; plan(snapshot: Snapshot): Plan }
export type Random = () => number;
// src/pool.ts
export interface Payer { card: CardInstanceId; gives: Gives }
export function payment(pool: readonly Payer[], cost: Cost): CardInstanceId[] | null;
// src/grid.ts
export function placedSize(size: Size, rotated: boolean): Size;
export class Grid { fits(cell: Cell, size: Size): boolean; mark(cell: Cell, size: Size, taken = true): void; anchors(size: Size): Cell[] }
export function gridsOf(snapshot: Snapshot): Map<Seat, Grid>;
// src/targets.ts
export interface TargetView { seat: Seat; seats: readonly Seat[]; squads: readonly SquadSnapshot[]; grids: ReadonlyMap<Seat, Grid> }
export function pickTarget(spec: TargetSpec, view: TargetView, random: Random): Target | null;
export function reserveTarget(target: Target, view: TargetView): void;
// src/random-bot.ts: class RandomPlanner keeps view, own, squads, ownSquads, pool and cast, with
// pay, place, spot, castLeader, castCard, moveLeader, useResources, attach and discard.
// tools/sim-cli/src/bots.ts
const FACTORIES = { random: (random: Random): Bot => createRandomBot({ random }) } satisfies Record<string, (random: Random) => Bot>;
```

What this task adds. The names are binding, because T-037 and T-038 build on them. Small signature changes are fine if you list them in the PR body.

```ts
// src/draft.ts
export interface Spot { cell: Cell; rotated: boolean } // moved from random-bot.ts

/** Where a bot wants things to go. PlanDraft calls these only once it knows the cost is payable. */
export interface CastChoices {
  spots(size: Size): readonly Spot[]; // candidate spots for a footprint, best first; the first that fits wins
  target(spec: TargetSpec): Target | null; // null: don't cast
  squad(squads: readonly SquadSnapshot[]): SquadSnapshot | undefined; // home for an attached permanent
}

/** One plan in the making: the bot's own copy of the pool, the grids and the hand. */
export class PlanDraft {
  constructor(snapshot: Snapshot);
  readonly snapshot: Snapshot;
  readonly view: TargetView; // squads are copies, so reserveTarget and moves can change them
  readonly own: Grid; // the seat's grid, with this plan's placements marked
  readonly ownSquads: readonly SquadSnapshot[];
  pool(): readonly Payer[]; // unrested, unattached, not yet spent or set aside
  pay(cost: Cost): boolean; // takes a payment out of the pool; false, and no change, if it can't
  setAside(cards: readonly CardInstanceId[]): void; // resources this plan attaches or rests
  place(cost: Cost, size: Size, spots: (size: Size) => readonly Spot[]): Spot | null; // pays, then marks the first spot that fits
  castLeader(leader: LeaderCard, choices: CastChoices): PlanAction | null;
  castCard(card: HandCard, choices: CastChoices): PlanAction | null; // records the card as cast
  kept(): CardInstanceId[]; // hand cards this plan doesn't cast, in hand order
  discardDown(pick: (kept: CardInstanceId[], count: number) => CardInstanceId[]): PlanAction[]; // [] when within handLimit
}

// src/placement.ts
export function toWorld(place: ArenaSeat, cell: Cell): WorldCell; // PROTOCOL.md › Arena layout
export function gridCenter(arena: ArenaLayout, seat: Seat): WorldCell; // the world cell of { col: 7, row: 7 }
export function allSpots(grid: Grid, size: Size): Spot[]; // every free spot, unrotated ones first; a square size only once
export function frontFirst(spots: readonly Spot[], size: Size, place: ArenaSeat, toward: WorldCell): Spot[];
// lowest row first, then the footprint's center nearest `toward` (squared world distance), then lowest col
export function pointLeader(snapshot: Snapshot): Seat; // the opponent with the most shown points; ties: lowest seat

// src/greedy-bot.ts, filled in by T-037
export interface GreedyBotOptions { random: Random }
export function createGreedyBot(options: GreedyBotOptions): Bot; // stub: name 'greedy', plans []
// src/turtle-bot.ts, filled in by T-038
export interface TurtleBotOptions { random: Random }
export function createTurtleBot(options: TurtleBotOptions): Bot; // stub: name 'turtle', plans []
```

`src/index.ts` exports both bots and their options types. `PlanDraft` and the helpers stay internal to the package.

## Deliverables

1. `src/draft.ts` with `PlanDraft`, `Spot` and `CastChoices`, plus `src/draft.test.ts`. The tests cover pay (including when it can't), place (nothing changes when the cost can't be paid or no spot fits), setAside, castCard for each hand card type, and discardDown.
2. `src/placement.ts`, plus `src/placement.test.ts`. The tests cover `toWorld` and `gridCenter` against a 4-seat layout from `test/fixtures/snapshots.ts`, `frontFirst`'s ordering for a seat whose `right` isn't `{ x: 1, y: 0 }`, and `pointLeader` with ties and when the bot itself leads.
3. `RandomPlanner` rebuilt on `PlanDraft`. It keeps only its random choices: `ODDS`, and which card, where, whether, and in what order.
4. Stub `greedy-bot.ts` and `turtle-bot.ts`, exported from `src/index.ts`, and `greedy` and `turtle` added to sim-cli's `FACTORIES`.
5. README: the Files table lists the new files. "Adding a bot" shows a bot built on `PlanDraft` and `CastChoices`.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] RandomBot's plans are unchanged. Run `pnpm sim --games 20 --seed 1 --log <scratch>/before.json` before your first change and `--log <scratch>/after.json` at the end. The two reports match except for the timing line, and `cmp` finds the two logs identical.
- [ ] `grep -n 'payment(\|anchors(' packages/bots/src/random-bot.ts` finds nothing: the bookkeeping lives in `draft.ts`
- [ ] `pnpm sim --bots greedy,turtle --games 2` finishes with `errors: none`

## Out of scope

- What the greedy and turtle bots actually decide: T-037 and T-038
- README sections describing those two bots: T-039
- Tournaments: T-036

## Notes

- RandomBot only stays identical if the random draws happen in the same order. Today `place` checks payment before it draws a spot, a sorcery picks its target before it pays, and an attached permanent picks its squad before it pays. `PlanDraft` must keep that order, which is why `place` takes `spots` as a function.
- Plan order stays as it is now: the Leader's move, then resource uses, attaches, spends (level-ups and casts), and the discard last. Attached and rested resources can't pay, so listing them before the spends keeps core from spending them.
- `SquadSnapshot.attached` is a count, not a list.
- Squads cast in this plan don't have a squad id until core casts them, so attaches and attached permanents can only go on squads that are already in the snapshot.
