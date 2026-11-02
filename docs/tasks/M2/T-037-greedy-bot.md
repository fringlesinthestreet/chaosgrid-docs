---
id: T-037
title: GreedyBot
milestone: M2
depends_on: [T-035, T-036]
branch: agent/T-037-greedy-bot
model: sonnet
effort: medium
scope:
  - packages/bots/src/greedy-bot.ts
  - packages/bots/src/greedy-bot.test.ts
  - packages/bots/test/fixtures/greedy.ts
context:
  - packages/bots/README.md#Adding a bot
  - docs/PROTOCOL.md#`HandCard`
  - docs/PROTOCOL.md#`SquadSnapshot`
  - docs/PLAN.md#M2
---

# T-037 — GreedyBot

## Goal

Fill in T-035's stub `createGreedyBot`. Every round it spends as much as it can on the most expensive cards, puts its units in the front row nearest the opponent with the most points, levels squads when they unlock, and attaches spare resources to the squads with the most Charge (PLAN.md › M2). It only has to play legally and keep its character: these bots are placeholders, so there is no win-rate target.

## Interfaces

What exists after T-035 (in `packages/bots/src/`):

```ts
// greedy-bot.ts: the stub you replace. Keep these two signatures
export interface GreedyBotOptions { random: Random }
export function createGreedyBot(options: GreedyBotOptions): Bot; // name 'greedy'
// draft.ts
export interface Spot { cell: Cell; rotated: boolean }
export interface CastChoices {
  spots(size: Size): readonly Spot[];
  target(spec: TargetSpec): Target | null;
  squad(squads: readonly SquadSnapshot[]): SquadSnapshot | undefined;
}
export class PlanDraft {
  constructor(snapshot: Snapshot);
  readonly snapshot: Snapshot; readonly view: TargetView; readonly own: Grid; readonly ownSquads: readonly SquadSnapshot[];
  pool(): readonly Payer[]; pay(cost: Cost): boolean; setAside(cards: readonly CardInstanceId[]): void;
  place(cost: Cost, size: Size, spots: (size: Size) => readonly Spot[]): Spot | null;
  castLeader(leader: LeaderCard, choices: CastChoices): PlanAction | null;
  castCard(card: HandCard, choices: CastChoices): PlanAction | null;
  kept(): CardInstanceId[];
  discardDown(pick: (kept: CardInstanceId[], count: number) => CardInstanceId[]): PlanAction[];
}
// placement.ts
export function gridCenter(arena: ArenaLayout, seat: Seat): WorldCell;
export function allSpots(grid: Grid, size: Size): Spot[];
export function frontFirst(spots: readonly Spot[], size: Size, place: ArenaSeat, toward: WorldCell): Spot[];
export function pointLeader(snapshot: Snapshot): Seat;
// targets.ts
export function pickTarget(spec: TargetSpec, view: TargetView, random: Random): Target | null;
// protocol
type Cost = { generic: number; colors: { E: number; T: number } };
type Keywords = Keyword[];
```

Nothing new is exported.

## Deliverables

1. `greedy-bot.ts`. The bot plans only in the plan phase, as RandomBot does. Its decisions, in order:
   1. **Casts.** The Leader (if it's in hand) and the unit cards, highest total cost first (`generic + E + T`; ties keep hand order), each one if the pool still pays for it. Spots: `frontFirst(allSpots(own, size), size, <own ArenaSeat>, gridCenter(arena, pointLeader(snapshot)))`.
   2. **Level-ups.** Own squads with `unlocked` and `level < maxLevel`, highest cost first, while the pool pays.
   3. **Other cards.** Sorceries and permanents, highest cost first. Targets come from `pickTarget`, the bot's only use of `random`. An attached permanent goes on the own squad with the highest level (ties: highest cost, then hand order of the squad list). A free-standing one uses the same spots as units.
   4. **Attaches.** Whatever is left in the pool goes to existing own squads, highest `stats.charge` first, up to `charge − attached` each.
   5. **Discard.** `discardDown`, lowest-cost cards first.
   6. It never moves its Leader and never uses resource abilities.
2. `greedy-bot.test.ts`, with the same three checks as `random-bot.test.ts` (plans parse, the same seed gives the same plan, the referee finds no problems over many snapshots). Add one test per decision above, using small snapshots built in `test/fixtures/greedy.ts`.
3. In the PR body: the `rejected` lines from the two runs in Acceptance, and the table that `pnpm sim --tournament greedy,random --games 100 --seed 1` prints (reported, not gated).

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/bots test -- greedy` passes
- [ ] `pnpm sim --bots greedy,greedy,greedy,greedy --games 100 --seed 1` and the same with `--decks starter` finish with no errors, and their `rejected` lines show no rejected actions. A table of one bot is the only way to pin rejections on it, because they're counted for all seats together. If some remain after 3 fixes, report them by reason: T-039 finishes the job.

## Out of scope

- The README section on the greedy bot: T-039, once both bots pass the done-when
- TurtleBot: T-038 runs at the same time in `turtle-bot.ts`
- Changes to `draft.ts`, `placement.ts` or anything else in T-035. If you need one, send `lead` a `request`.

## Notes

- Decide the spends before the attaches, so only resources nothing paid for get attached. The plan still lists attaches before spends (T-035's plan order). The referee test catches it if core would pay differently.
- Squads cast in this plan have no squad id yet, so attaches and attached permanents go only on squads already in the snapshot.
- A unit's footprint is `size` (`[width, height]`). It turns when `rotated` (see `placedSize`). `frontFirst` already handles rotated spots.
- If the pool can't pay for the most expensive card, skip it and try the next one. Don't stop.
