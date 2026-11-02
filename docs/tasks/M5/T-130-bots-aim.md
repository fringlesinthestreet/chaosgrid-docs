---
id: T-130
title: Bots aim for points
milestone: M5
depends_on: [T-114]
branch: agent/T-130-bots-aim
model: sonnet
effort: high
scope:
  - packages/bots/**
context:
  - docs/RULES.md#Scoring and winning
  - docs/RULES.md#Chaos deck and Emblems
  - docs/RULES.md#Simulation rules
  - packages/bots/README.md
---

# T-130 — Bots aim for points

## Goal

Today greedy places its casts toward the point leader's prize and picks most spell targets at random. Turtle picks all of its targets at random. No bot looks at Emblems, at Chaos units or at prizes nobody defends. After this PR:

- greedy's casts lean toward a standing Emblem, else toward a prize nobody defends (D44), else toward the point leader as before;
- greedy keeps its units back when the Chaos sent against it outclasses it, and aims its enemy spells at that Chaos;
- greedy and turtle pick spell and ability targets by value: the most kill points, the right squad to buff, the cheapest squad to sacrifice.

The helpers go in a new `value.ts` and in `placement.ts` and `targets.ts`, so T-133 and the planner (T-135) can reuse them.

## Interfaces

What exists, copied from main on 2026-10-29. T-112 deletes `PlanDraft.discardDown` and T-114 adds `chooseDiscards`, so the line numbers move: re-read greedy-bot.ts, turtle-bot.ts and draft.ts when you start.

```ts
// packages/bots/src/greedy-bot.ts
function planFor(snapshot: Snapshot, random: Random): Plan; // :48-58: a first GreedyPlanner decides the
//   spends, keepAttaches tries each wanted attach on fresh planners (their spendKeys must match the
//   first's), and a last planner makes the plan
function total(cost: Cost): number;                         // :61; turtle-bot.ts:72 has a copy
class GreedyPlanner implements CastChoices {                // :90
  // constructor (:96-104) sets this.toward = pointTarget(snapshot).aim
  spots(size: Size): readonly Spot[];  // :144: frontFirst(allSpots(this.draft.own, size), size, this.place, this.toward)
  target(spec: TargetSpec): Target | null; // :155-161: a copy takes bestSpell, a revive pickRevival,
  //   everything else pickTarget at random
  // abilityTarget(spec) (:267-271): pickRichestSquad for a squad spec, else target(spec)
}
// turtle-bot.ts: TurtlePlanner.target(spec) (:155) is pickTarget at random. otherCards (:233-246)
//   casts only spells with no target or an own-side one.

// packages/bots/src/placement.ts
export function toWorld(place: ArenaSeat, cell: Cell): WorldCell;          // :17
export function gridCenter(arena: ArenaLayout, seat: Seat): WorldCell;     // :25
export function frontFirst(spots: readonly Spot[], size: Size, place: ArenaSeat, toward: WorldCell): Spot[]; // :47
export const PRIZE_VALUE = 2;                                               // :76
export function pointTarget(snapshot: Snapshot): { seat: Seat; aim: WorldCell }; // :84

// packages/bots/src/targets.ts
export interface TargetView { seat; seats; squads; loose; cols; rows; grids; discardPile; spells } // :74-96
export function seatsOn(view: TargetView, side: Side): Seat[];             // :99
// aimable (:115) and allows (:140) apply Ward and noLeader: keep using them.
export function pickTarget(spec: TargetSpec, view: TargetView, random: Random): Target | null; // :174
export function pickRichestSquad(spec, view, points: ReadonlyMap<Seat, number>): Target | null; // :234, greedy only
// draft.ts: PlanDraft's constructor (:72-92) builds `view`. grid.ts: Grid.fits(cell, size) is false
//   when a cell is taken.

// packages/protocol/src/snapshot.ts (T-112's v26 leaves these as they are)
SquadSnapshot { squad, seat, leader, cell, rotated, cost, size, units, stats, keywords, level, … }
//   cost: the level-up cost, which is the printed cost unless a cost change applies; stats: printed, level 1
UnitSnapshot { unit, squad, owner, cell: WorldCell, hp, maxHp, alive, keywords } // Plan: its start or spawn cell
SpawnedSquadSnapshot { squad, owner, kind: 'chaos' | 'token', stats, keywords, level }
EmblemSnapshot { permanent, cardId, hp, points, cell: WorldCell }
PrizeSnapshot { permanent, seat, cell, size, hp, maxHp, alive }
ArenaSeat { seat, origin, right, back, chaosEdge: WorldRect } // snapshot.arena.seats; Chaos sent against the seat spawns in chaosEdge
UnitStats { hp, attack, attackSpeed, speed, range, charge }
// Keyword includes 'seeksEmblems', 'blocker' and 'ward'.
```

What this task adds:

```ts
// packages/bots/src/value.ts (new)
/** Total pips of a cost: generic plus every color. Replaces greedy's and turtle's `total`. */
export function totalCost(cost: Cost): number;
/** One unit's damage per second: attack × (1 + 0.5 × (level − 1)) × attackSpeed (RULES.md › Leveling). */
export function unitDps(stats: UnitStats, level: number): number;
/** What killing the whole squad scores: totalCost(cost) × level, plus max(3, totalCost(cost)) for a Leader. */
export function killPoints(squad: SquadSnapshot): number;
export interface Force { dps: number; hp: number }
/** A force's strength in a fight: dps × hp. */
export function power(force: Force): number;
/** The living units of these squads, on a grid or spawned. A grid squad with no unit listed counts `units` units at its level's full HP. */
export function forceOf(snapshot: Snapshot, squads: readonly SquadId[]): Force;
/** The Chaos squads sent against `seat`: those with a living unit inside its chaosEdge. */
export function chaosAgainst(snapshot: Snapshot, seat: Seat): SpawnedSquadSnapshot[];
/**
 * The power of the Chaos sent against the planning seat ÷ the power of its grid squads plus
 * `casting` (each at level 1). 0 when no Chaos is sent against it; Infinity when it fields nothing.
 */
export function chaosPressure(snapshot: Snapshot, casting: readonly { stats: UnitStats; units: number }[]): number;

// packages/bots/src/placement.ts
/** Spots sorted back first: the highest row, then the footprint's centre nearest `toward`, then the lowest col. */
export function backFirst(spots: readonly Spot[], size: Size, place: ArenaSeat, toward: WorldCell): Spot[];
/** The Emblem with the most points per HP; ties to the one nearest the seat's grid centre, then the lowest permanent id. Null with none. */
export function bestEmblem(snapshot: Snapshot): EmblemSnapshot | null;
/** A standing opponent prize whose seat has no squad on its grid; the nearest, ties to the lowest seat. Null with none. */
export function undefendedPrize(snapshot: Snapshot): PrizeSnapshot | null;
/** Where greedy's casts lean: bestEmblem, else undefendedPrize, else pointTarget. For an Emblem, `seat` is pointTarget's seat. */
export function aimFor(snapshot: Snapshot): { seat: Seat; aim: WorldCell };

// packages/bots/src/targets.ts
// TargetView gains:
  /** Every seat's prize (snapshot.prizes). */
  prizes: readonly PrizeSnapshot[];
export interface ValueContext {
  /** The opponent the bot goes for. */
  aimSeat: Seat;
  /** Who an own-side buff goes to: the hardest hitter, or the prize's guard. */
  buff: 'attacker' | 'guard';
  /** A Chaos squad that outclasses the seat: enemy-squad spells hit it first. Null for none. */
  chaosTarget: SquadId | null;
}
/** A target by value (Deliverables › 3), or pickTarget at random for a spec it doesn't rank. */
export function pickByValue(spec: TargetSpec, view: TargetView, context: ValueContext, random: Random): Target | null;
```

## Deliverables

1. **value.ts.** The functions above. Greedy and turtle use `totalCost` and drop their own `total`.
2. **placement.ts.** `backFirst`, `bestEmblem`, `undefendedPrize` and `aimFor`. `pointTarget` doesn't change. Distances are squared world distances, as in `frontFirst`.
3. **pickByValue.** PlanDraft fills `TargetView.prizes`, and so does `viewOf` in targets.test.ts, which builds views by hand. The rules, by spec:

   | Spec | Pick |
   | --- | --- |
   | `squad`, `opponent` | `chaosTarget` when `aimable` lists it. Else the opponents' grid squad with the most `killPoints` that `allows` passes. Ties go to the most dps (`unitDps(stats, level) × units`), then to the owner with the most points, then to the lowest seat. With no grid squad: the token or Chaos squad of the highest level, ties to the first `aimable` lists. |
   | `squad`, `own`, `noLeader` | The fewest `killPoints`: the cheapest to sacrifice. Ties to the first in the list. |
   | `squad`, `own`, buff `attacker` | The most dps (`unitDps(stats, level) × units`). Ties to the first. |
   | `squad`, `own`, buff `guard` | A Blocker first, then the footprint centre nearest its own prize. Ties to the first. |
   | `row`, `opponent` | The row with the most kill points: the sum of `killPoints` of the squads whose footprint covers it. Ties to `aimSeat`, then the lowest row, then the lowest seat. If every row scores 0: `aimSeat`'s row through the top of its prize (`prize.cell.row`). |
   | `area`, `own` | The anchor, with the whole area on the grid, that covers the most taken cells of the own grid in `view.grids`, minus the prize's cells. Those are squads and permanents, this plan's casts included. Ties to the lowest row, then the lowest col. |
   | `seat`, `opponent` | `aimSeat` |
   | anything else | `pickTarget(spec, view, random)` |

   Delete `pickRichestSquad` and its tests once nothing uses it.
4. **Greedy.**
   - `planFor` runs one extra GreedyPlanner first, with pressure 0, only to learn what it casts. `chaosPressure` reads those casts. The first pass, the keepAttaches trials and the final planner all get that pressure, so their spend keys still match. GreedyPlanner's constructor takes the pressure.
   - `spots(size)`: while the pressure is above 1, `backFirst` toward the centre of its own prize. Otherwise `frontFirst` toward `aimFor(snapshot).aim`.
   - `target` and `abilityTarget` merge into one `target(spec)`. A copy and a revive stay as they are. Everything else goes through `pickByValue` with `{ aimSeat: aimFor(snapshot).seat, buff: 'attacker', chaosTarget }`. `chaosTarget` is the strongest squad of `chaosAgainst` (`power(forceOf(…))`, ties to the lowest squad id) while the pressure is above 1, else null.
5. **Turtle.** `target(spec)` goes through `pickByValue` with `{ aimSeat: pointTarget(snapshot).seat, buff: 'guard', chaosTarget: null }`. Its placement and attaches don't change.
6. **Tests.** Next to the code, with the existing fixtures (`test/fixtures/greedy.ts`, `turtle.ts`, `snapshots.ts`). The bots' tests run `referee` on every plan, as they do now.
   - value: `killPoints` of a level-2 squad costing 2R is 6, and of a level-1 Leader costing 3RR it's 10. `unitDps` of attack 2 and attack speed 0.5 at level 3 is 2. `chaosPressure` is 0 with no Chaos, and Infinity with Chaos against an empty grid and nothing cast.
   - placement: `backFirst` puts the highest row first. `bestEmblem` takes 5 points and 10 HP over 2 points and 6 HP. `undefendedPrize` skips an opponent that has a squad. `aimFor` takes an Emblem over an undefended prize, and that over `pointTarget`.
   - targets: one test per row of the table. Ward and `noLeader` still rule squads out.
   - greedy: under Chaos that outclasses it, it casts in the back rows and aims a banish at that Chaos squad. With an Emblem standing, its front-row casts lean toward it. Scorch Line goes to the row with the most kill points.
   - turtle: an own-squad buff goes to a Blocker.
7. **README.** The greedy and turtle sections say how they aim and pick targets. Files lists `value.ts`. The README calls `pointTarget` `pointLeader`: fix that while you're there.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/bots test` passes, with the tests above
- [ ] `pnpm test:soak` passes
- [ ] `pnpm sim --games 20 --bots greedy,greedy,turtle,turtle --decks starter --target 30 --check` exits 0
- [ ] `grep -c "pickTarget(" packages/bots/src/greedy-bot.ts` prints 0

## Out of scope

- Traps, Leader moves and Rest (T-133).
- Looking ahead with round previews (T-129, and the planner in T-135).
- Bot styles per starter deck (T-137).
- Turtle's placement and attaches, and the random bot.
- Protocol changes. The gaps in Notes stay gaps: tell `lead` if one blocks you.

## Notes

- What the snapshot doesn't show (after T-112):
  - Chaos kill points: they're printed on the Chaos card. Tokens show no cost either. So Chaos squads and tokens count 0 kill points.
  - A spell's effect: only its class and its TargetSpec. So pickByValue ranks by the spec alone, and Scorch Line, Flash Flood and Chilling Tide pick rows the same way.
  - `prizePoints`: it isn't in GameSettings, so `PRIZE_VALUE` stays 2.
  - An Emblem's buff: Emblems rank by points per HP.
- "Points per cost": a spell costs the same whatever it targets, so the best target is the one with the most kill points.
- Own-side squad specs: in the card data every `noLeader` one is a sacrifice (Blood Pact, Soul Drain), and the others are buffs (Overclock, Fan the Flames). Default: rank them so.
- `SquadSnapshot.cost` is the level-up cost. It's the printed cost unless a cost change applies (Ancient Cache's buff), which is close enough for kill points.
- D34: during Plan, other seats' grids show as they were when Plan began. "Undefended" means no squad then, so in round 1 every prize is undefended.
- An Emblem always beats a prize on points per HP (2 points for 6 HP at worst, against 2 for 20), which is why `aimFor` takes an Emblem first. Only a unit with `seeksEmblems` attacks one while other enemies are in range. The others start near it and go for it once nothing else is in range.
- Round 1: against an empty grid, any Chaos would outclass the seat. That's why `chaosPressure` counts the casts.
- D8: the same seed still gives the same plan. pickByValue draws from `random` only when it falls back to pickTarget. The extra pass draws too, which shifts later draws: that's fine.
- Soaks:
  - m3-done-when: tables of all greedy and all turtle may have no rejected plan action and at most 5% games with no winner. Targets by value must stay legal: Ward, `noLeader`, a whole area on the grid.
  - m3-done-when also checks D33: greedy must beat random in more than 55 of 100 games. If that count drops, report the numbers to `lead`. Don't loosen the test: D33 names a bot change as a reason to revisit.
  - plan-abilities: no rejections for its greedy and turtle table. `ownRests` and `wakes` stay above 0.
  - settle only checks how a settle is built. done-when, smoke, game.test and tournament.test play random bots only. The golden game is scripted.
- In the handoff, give the summary's `points` line from `pnpm sim --games 50 --bots greedy,greedy,greedy,greedy --decks starter --target 30`, before and after the change.
