---
id: T-133
title: Bots use traps, Leader moves and Rest
milestone: M5
depends_on: [T-130]
branch: agent/T-133-bot-plays
model: sonnet
effort: high
scope:
  - packages/bots/**
context:
  - docs/RULES.md#Round structure
  - docs/RULES.md#Resources and attaching
  - docs/RULES.md#Non-unit permanents and spells
  - packages/bots/README.md
---

# T-133 — Bots use traps, Leader moves and Rest

## Goal

Greedy and turtle never move their Leader and never use a resource's Rest ability. They set traps as if they were units, and turtle never uses Plan abilities. After this PR:

- both move the Leader to where they would cast it now;
- both rest spare resources for their abilities;
- both set traps where the enemies come from;
- turtle uses its own Plan abilities.

Their payment model also learns which resources have a Rest ability, as core's does.

## Interfaces

The plan actions, and which bot uses which once T-130 is merged:

| Plan action | random | greedy | turtle |
| --- | --- | --- | --- |
| `castUnit`, `castLeader` | 75% each, random spot | dearest first, toward its aim | Blockers in the front row, the rest behind the line |
| `moveLeader` | 30% of rounds, a random free spot | never | never |
| `levelUp` | every unlocked squad | dearest first | Blockers first |
| `attach` | 75% per squad | most Charge first | Blockers first |
| `castPermanent`, traps included | random spot or squad | dearest first; a trap goes where a unit would | dearest first, behind the line, traps too |
| `castSpell` | random target | by value (T-130) | no target or an own-side one, by value |
| `useResource` | 50% | never | never |
| `useAbility` | 50% | when `abilityScore` is 0 or more | never |

T-112 removes `discard`. That leaves nine actions, applied in the order the plan lists them.

What exists, copied from main on 2026-10-29. T-112, T-114 and T-130 change these files, so re-read greedy-bot.ts, turtle-bot.ts, draft.ts and pool.ts when you start:

```ts
// packages/protocol/src/plan.ts
{ action: 'moveLeader'; cell: Cell }                                  // free, onto empty cells; the Leader keeps its rotation
{ action: 'useResource'; resource: CardInstanceId; target?: Target }  // rests it and casts its Rest spell
// packages/protocol/src/snapshot.ts
PoolResource { card, cardId, gives, rested, attachedTo, spell: SpellClass | null, target?: TargetSpec }
//   spell: the class of its Rest ability's spell, null for none; target: what that ability needs
// a free-standing permanent in the hand:
{ card, cardId, type: 'trap' | 'artifact' | 'enchantment', cost, colors, mode: 'freeStanding', size, uses }
AbilityUse { ability, cost, rest, spell, target?, usable }

// packages/bots/src/random-bot.ts
// moveLeader (:136-150): frees the Leader's cells, picks a free spot with its rotation that isn't its
//   cell, sets leader.cell and marks the new cells. useResources (:165-182): a resource with a spell
//   that `forbids` allows and that is still in the pool; aim, setAside, addSpell, reserveTarget.
// packages/bots/src/draft.ts
export interface CastChoices { spots(size: Size): readonly Spot[]; target(spec: TargetSpec): Target | null; squad(squads): SquadSnapshot | undefined } // :37-44
class PlanDraft {
  place(cost: Cost, size: Size, spots: (size: Size) => readonly Spot[]): Spot | null; // :117
  castLeader(leader: LeaderCard, choices: CastChoices): PlanAction | null;            // :129
  castCard(card: HandCard, choices: CastChoices): PlanAction | null;                   // :138
  useAbility(holder: AbilityHolder, use: AbilityUse, aim: (spec: TargetSpec) => Target | null): PlanAction | null; // :170
  forbids(spell: SpellClass | null): boolean;          // :188
  addSpell<T extends PlanAction>(action: T): T;        // :196
  setAside(cards: readonly CardInstanceId[]): void;    // :108
  // the constructor (:72-92) builds its payers as { card, gives }, without hasRest
}
// packages/bots/src/pool.ts
export interface Payer { card: CardInstanceId; gives: Gives; hasRest?: boolean } // :16-24: core pays with Rest resources last
export function keepAttaches(wanted: readonly AttachAction[], holds: (reserved: readonly CardInstanceId[]) => boolean): AttachAction[]; // :143
// packages/bots/src/greedy-bot.ts
// abilityScore(holder, use) (:72-75) = total(use.cost) − (use.rest && holder.squad ? attackValue(squad) : 0),
//   attackValue (:77) = stats.attack × attackSpeed × units. attach (:274): most Charge first, up to each squad's room.
// packages/bots/src/turtle-bot.ts
// turtleGroup (:65-70): 0 Blocker, 1 Artillery, 2 Static. spots (:144-153) reads `front` and `line`.
//   otherCards (:233-246) sets front = false, so traps go behind the line.
// From T-130: value.ts (totalCost, chaosAgainst, …), placement.ts (aimFor, backFirst, …),
//   targets.ts (pickByValue, ValueContext). planFor in both bots: a first pass, keepAttaches trials,
//   a final planner.
```

What this task adds:

```ts
// packages/bots/src/draft.ts
export interface CastChoices {
  /** `card`: the hand card being cast. Left out for a Leader and for a revive. */
  spots(size: Size, card?: HandCard): readonly Spot[];
  // target and squad as before
}
class PlanDraft {
  /**
   * Moves the own Leader to the first of `spots` that fits its footprint as it stands, with its
   * own cells free while it looks. Null, and nothing changes, when no Leader is on the grid or the
   * first spot is where it stands.
   */
  moveLeader(spots: (size: Size) => readonly Spot[]): PlanAction | null;
  /**
   * Rests `resource` for its Rest ability (setAside, addSpell, reserveTarget). Null, and nothing
   * changes, when it has no ability, `forbids` its class, it isn't in the pool, or it needs a
   * target `aim` can't find.
   */
  useResource(resource: PoolResource, aim: (spec: TargetSpec) => Target | null): PlanAction | null;
}

// packages/bots/src/placement.ts
/**
 * Where enemies come from: the mean cell of the living Chaos units sent against the seat
 * (chaosAgainst), else the centre of the nearest opponent's grid (ties to the lowest seat).
 */
export function threatCell(snapshot: Snapshot): WorldCell;

// packages/bots/src/value.ts: moved from greedy-bot.ts, same result
export function abilityScore(use: AbilityUse, squad: SquadSnapshot | null): number;

// packages/bots/src/pool.ts
/**
 * The Rest uses that can stay in a plan, checked like keepAttaches: each one is kept only if
 * `holds` with it, the ones kept before it and `reserved` all set aside.
 */
export function keepRests(
  wanted: readonly CardInstanceId[],
  reserved: readonly CardInstanceId[],
  holds: (reserved: readonly CardInstanceId[]) => boolean,
): CardInstanceId[];
```

## Deliverables

1. **The payers.** PlanDraft's payers get `hasRest: resource.spell !== null`. The bot then pays as core does (pool.ts › Payer).
2. **PlanDraft.** `moveLeader`, `useResource`, and the `card` argument of `spots`: `castCard` passes the card it places.
3. **Traps.** When `card.type` is `'trap'`, greedy's and turtle's `spots` return `frontFirst` toward `threatCell(snapshot)`. Turtle's line doesn't apply to traps.
4. **Leader moves.** Each planner starts with `draft.moveLeader`, using its own spots. Greedy's Leader then leans toward its aim, or goes back-first under Chaos pressure (T-130). Turtle's goes to the front row when it's a Blocker and behind the line otherwise, as `turtleCasts` places a Leader.
5. **Rest uses.**
   - After the attaches, every resource still in the pool with a Rest ability rests for it. Its target comes from `pickByValue`, with the bot's ValueContext.
   - `planFor` keeps them with `keepRests`, after `keepAttaches` and with the same `holds`.
   - The final planner makes the Rest uses first, with `PlanDraft.useResource`, then sets the attaches' resources aside. A trial planner only sets both aside. Either way the spends see the same pool.
6. **Turtle's abilities.** Right after `otherCards`, turtle uses each Plan ability that has no target or an own-side one, when `abilityScore` is 0 or more. Targets come from `pickByValue`.
7. **Plan order.** `moveLeader`, the Rest uses, the attaches, then the spends.
8. **Tests.** Next to the code, with the existing fixtures. Every plan goes through `referee`.
   - payers: a pool with a Rest resource and a plain one of the same color pays with the plain one.
   - `moveLeader`: it moves to the first spot. It returns null when that spot is its own cell. A later cast in the same plan can use its old cells.
   - `useResource`: it rests a resource that has a Rest ability. It returns null for one without, for one already set aside, and for a defensive one under `noSpells`.
   - `threatCell`: the mean of the Chaos units sent against the seat; with none, the nearest opponent's grid centre.
   - greedy: a trap goes front-first toward the Chaos units. The Leader moves when its best spot has changed. A spare Harvest Cycle rests for its draw; one that pays or attaches doesn't.
   - turtle: a Blocker Leader moves to the front row. A free ability with no target is used. A trap goes toward the threat, not behind the line.
9. **README.** The plan-action table above, as it stands after this PR. The note that PlanDraft leaves out `hasRest` goes.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/bots test` passes, with the tests above
- [ ] `pnpm test:soak` passes
- [ ] `pnpm sim --games 20 --bots greedy,greedy,turtle,turtle --decks starter --target 30 --check` exits 0
- [ ] `pnpm sim --games 20 --bots greedy,turtle,greedy,turtle --target 30 --check` exits 0 (generated decks)

## Out of scope

- Traps that share cells with units. Core allows it, but the bots' grids (`gridsOf`) and the referee keep every footprint apart.
- Choosing between attaching a resource and resting it: Rest uses take only what the attaches leave.
- Rest-this-unit abilities that ramp (Seedling Scout, Root Tender, Elder Mycelium): T-137's ramp style.
- The random bot, and the planner (T-135).
- Protocol changes.

## Notes

- A hand trap shows only its size, cost and colors. The bot can't tell Spike Pit from Flare Mine, so every trap goes toward the threat. Opponents' traps are face down and hidden by design, so the bots don't try to avoid them.
- A 5×5 trap that finds no free block isn't cast: the planner moves on, as it does for a unit that doesn't fit.
- A Rest use takes only a resource nothing else uses, so it costs the plan nothing. A card it draws arrives during Plan. But the bot planned from one snapshot, so it can't play that card this round. The Discard step trims the hand (T-114).
- Ramp abilities score below 0, because they rest a squad that attacks. They stay unused here.
- The `hasRest` fix can change which resource pays in a few existing tests. Core's rule (`packages/core/src/zones/pay.ts`) is the reference. Update such a test, and list it in the handoff.
- `moveLeader` is the plan's first action, so only the snapshot's squads, permanents and prizes take cells when core applies it.
- D8: the same seed still gives the same plan.
- Soaks: m3-done-when and plan-abilities allow no rejected plan action from greedy or turtle. Leader moves, Rest uses and traps must stay legal. D33's greedy-versus-random count can move: report it to `lead`, don't loosen it. Turtle's abilities can raise plan-abilities' `ownRests`.
