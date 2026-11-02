---
id: T-038
title: TurtleBot
milestone: M2
depends_on: [T-035, T-036]
branch: agent/T-038-turtle-bot
model: sonnet
effort: medium
scope:
  - packages/bots/src/turtle-bot.ts
  - packages/bots/src/turtle-bot.test.ts
  - packages/bots/test/fixtures/turtle.ts
context:
  - packages/bots/README.md#Adding a bot
  - docs/PROTOCOL.md#`HandCard`
  - docs/PROTOCOL.md#`SquadSnapshot`
  - docs/PLAN.md#M2
---

# T-038 — TurtleBot

## Goal

Fill in T-035's stub `createTurtleBot`. It builds a defensive line: Blockers in front, then Artillery and other Static units behind them, and it attaches its spare resources to the Blockers (PLAN.md › M2). It only has to play legally and keep its character: these bots are placeholders, so there is no win-rate target.

## Interfaces

What exists after T-035 (in `packages/bots/src/`):

```ts
// turtle-bot.ts: the stub you replace. Keep these two signatures
export interface TurtleBotOptions { random: Random }
export function createTurtleBot(options: TurtleBotOptions): Bot; // name 'turtle'
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
// grid.ts
export function placedSize(size: Size, rotated: boolean): Size;
// targets.ts
export function pickTarget(spec: TargetSpec, view: TargetView, random: Random): Target | null;
// protocol
type Cost = { generic: number; colors: { E: number; T: number } };
type Keywords = Keyword[]; // 'blocker', 'static', …; Range is 'melee' | 'ranged' | 'artillery'
type Side = 'own' | 'opponent' | 'any';
```

Nothing new is exported.

## Deliverables

1. `turtle-bot.ts`. The bot plans only in the plan phase, as RandomBot does. A **turtle unit** is a unit card or Leader with `blocker`, or with `stats.range` `artillery`, or with `static`. Its decisions, in order:
   1. **Turtle casts.** Blockers first, then Artillery, then other Static units, highest total cost first within each group (`generic + E + T`; ties keep hand order). The Leader joins the group its keywords and range give it. Each one is cast if the pool still pays for it.
      - Blockers: `frontFirst(allSpots(own, size), size, <own ArenaSeat>, gridCenter(arena, seat))`, which puts them in the front row, centered.
      - Everything else: the same order, but only spots whose row is at or behind the **line**, the smallest back edge (`row` + placed height) among own Blocker squads, both those in the snapshot and those placed this plan. With no Blocker, or no spot behind the line that fits, use the Blocker order.
   2. **Level-ups.** Own squads with `unlocked` and `level < maxLevel`: Blockers first, then other turtle squads, then the rest, highest cost first within each group, while the pool pays.
   3. **Other cards**, highest cost first:
      - Permanents. Attached ones go on a Blocker first (highest level), then any squad. Free-standing ones go behind the line.
      - Sorceries, only those with no target or with `side: 'own'`. The bot skips `opponent` and `any`.
      - Targets come from `pickTarget`, the bot's only use of `random`.
   4. **Other units**, with whatever the pool still pays, behind the line.
   5. **Attaches.** Whatever is left in the pool goes to existing own Blocker squads first, then to any own squad, up to `stats.charge − attached` each.
   6. **Discard.** `discardDown`: cards that aren't turtle units first, then turtle units, lowest cost first within each.
   7. It never moves its Leader and never uses resource abilities.
2. `turtle-bot.test.ts`, with the same three checks as `random-bot.test.ts` (plans parse, the same seed gives the same plan, the referee finds no problems over many snapshots). Add tests for the groups' order, the line (including no Blocker, and a Blocker cast in the same plan), the sorcery filter, and the attach order, using small snapshots built in `test/fixtures/turtle.ts`.
3. In the PR body: the `rejected` lines from the two runs in Acceptance, and the table that `pnpm sim --tournament turtle,random --games 100 --seed 1` prints (reported, not gated).

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/bots test -- turtle` passes
- [ ] `pnpm sim --bots turtle,turtle,turtle,turtle --games 100 --seed 1` and the same with `--decks starter` finish with no errors, and their `rejected` lines show no rejected actions. A table of one bot is the only way to pin rejections on it, because they're counted for all seats together. If some remain after 3 fixes, report them by reason: T-039 finishes the job.

## Out of scope

- The README section on the turtle bot: T-039, once both bots pass the done-when
- GreedyBot: T-037 runs at the same time in `greedy-bot.ts`
- Changes to `draft.ts`, `placement.ts` or anything else in T-035. If you need one, send `lead` a `request`.

## Notes

- The rules behind the plan (RULES.md, no need to read it): an enemy within N cells of a Blocker (default 2) must target it. Static units have Speed 0. Artillery hits at range 6 but not closer than 2, so it can sit well behind the line.
- Row 0 is the front row, facing the center of the arena, so "behind" means a higher row.
- Decide the spends before the attaches, so only resources nothing paid for get attached. The plan still lists attaches before spends (T-035's plan order).
- Squads cast in this plan have no squad id yet, so attaches and attached permanents go only on squads already in the snapshot. They still count for the line.
