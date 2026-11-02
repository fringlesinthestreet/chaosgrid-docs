---
id: T-042
title: Plan abilities and rested units
milestone: M3
depends_on: [T-041]
branch: agent/T-042-plan-abilities-rest
model: sonnet
effort: high
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/cards/src/**
  - packages/cards/test/**
  - packages/cards/README.md
  - packages/core/src/**
  - packages/core/test/**
  - packages/bots/src/**
  - packages/bots/test/**
  - tools/sim-cli/src/**
  - tools/sim-cli/test/**
context:
  - docs/RULES.md#Units
  - docs/RULES.md#Non-unit permanents and spells
  - docs/RULES.md#Round structure
  - packages/cards/README.md#Triggers
  - packages/cards/README.md#`draw`, `reveal` and `rest`
  - packages/cards/README.md#Targets
  - packages/cards/README.md#Caster choices
  - packages/cards/README.md#Spell classes
  - docs/PROTOCOL.md#Plans
---

# T-042 — Plan abilities and rested units

## Goal

Units, Leaders, artifacts and enchantments can print Plan abilities, any number of them (RULES.md › Units › Plan abilities). Each has a cost in resources, "rest this unit", or both, and an effect that casts a spell of its class. A player uses each one at most once per round. A rested unit stays in its cell for the whole Simulate and doesn't move or attack, but it can still be hit (› Rested). Units get rested by their own Plan abilities, or by enemy spells and abilities through the `rest` effect, which now reaches enemy units. Everything unrests at Cleanup.

## Interfaces

What exists (copied from the code):

```ts
// packages/cards/src/dsl.ts:23. `onRest` is a resource's "Rest: …" ability.
export const TRIGGERS = ['static', 'onEnter', 'onAttack', 'onDeath', 'onKill', 'onDestroyed', 'every', 'at', 'onRoundEnd', 'onRest', 'onDraw'] as const;
// packages/cards/src/dsl.ts:188, in every ability's envelope
/** With `onRest`, and only there, where it's required: the class of the spell it casts. */
spell: SpellClassSchema.optional(),
// packages/cards/src/dsl.ts:249
effect('rest', { target: targetOf('rest', ['self']) }),
// packages/protocol/src/plan.ts:90
export const UseResourceAction = z.strictObject({ action: z.literal('useResource'), resource: CardInstanceId, target: Target.optional() });
// packages/protocol/src/snapshot.ts, PoolResource: resources only, so far
rested: z.boolean(),
```

What this task adds:

```ts
// cards: a Plan ability is an ability with trigger 'onUse'; a card has any number of them
TRIGGERS: + 'onUse'
// in the ability's envelope, with 'onUse' and only there (at least one of cost and rest):
cost?: Cost                                         // the resources it costs
rest?: true                                         // using it rests the unit (units and Leaders)
spell: SpellClass                                   // required with 'onUse', as with 'onRest'
UNIT_TARGETS: + 'chosenEnemyUnit'                   // one enemy squad, picked by the caster
effect('rest', { target: /* self, chosenEnemyUnit, attackTarget, triggeringUnit, nearestEnemy, enemies, allUnits */ })

// protocol
export const UseAbilityAction = z.strictObject({ action: z.literal('useAbility'), card: CardInstanceId, ability: z.int().min(0), target: Target.optional() });
// ability: the index of an 'onUse' ability in the card's `abilities`
SquadSnapshot.rested: z.boolean()                   // rests itself this round
HandCard / SquadSnapshot / PermanentSnapshot: uses: { ability, cost, rest, spell, usable }[] // [] when none
UnitRestedEvent { type: 'unit.rested', unit, by: CardInstanceId | null }
export const PROTOCOL_VERSION = /* T-041's + 1 */;
```

## Deliverables

1. **Cards.**
   - A Plan ability is an ability with `"trigger": "onUse"`, and a card may have any number of them, or none. The ability's envelope says what using it takes: `cost`, `rest: true`, or both, and its `spell` class, which is required as with `onRest`.
   - `onUse` abilities are allowed on `unit`, `leader`, `artifact` and `enchantment` cards. An `onUse` ability needs `cost`, `rest` or both, and `cost` and `rest` are valid only with `onUse`. `rest` is for units and Leaders only.
   - `cost` parses like a casting cost. The `spell` class rules (README › Spell classes) apply to each `onUse` ability as they do to a spell card's.
   - The new target `chosenEnemyUnit` is every unit of one squad of another player. It is a caster choice with plan target `squad`, on the opponent side. Chaos squads and other seats' tokens can't be chosen yet: the snapshot doesn't show where they are. T-064 adds their positions and lifts this.
   - `rest` also accepts `chosenEnemyUnit`, `attackTarget`, `triggeringUnit`, `nearestEnemy`, `enemies` and `allUnits`, the groups with a scope and a filter as usual.
2. **Plan.**
   - `useAbility` names the card instance of a squad, Leader, artifact or enchantment on the seat's grid, and the index of one of its card's `onUse` abilities. Core pays the ability's `cost` like any cost, rests the squad if the ability has `rest`, and casts the spell: utility resolves at once, defensive and offensive at tick 0, in the same order as spell cards.
   - Each ability is used on its own: using one doesn't use up the card's others.
   - Fog of War ("No defensive or offensive spells this round, from cards or abilities") rejects a defensive or offensive `useAbility` and `useResource` as it rejects `castSpell` (`forbidden`, through `forbiddenByRules`). Utility abilities are still allowed. Today only the spell card's cast action is checked.
   - Spell traps react to every enemy spell (RULES.md › Non-unit permanents and spells › Traps). Mirror Snare's check (`sorceryTargetsArea`, renamed by T-040) accepts the spell of an `onUse` or `onRest` ability, not only a spell card. Its redirect is keyed by the spell (the card and the ability's index), so two abilities of one card don't share one.
   - `mirroredTarget` turns seat and squad choices around too, as RULES.md › Sample cards › Traps says: a seat becomes the caster's seat, and a squad (`chosenEnemyUnit`) becomes the caster's squad nearest the chosen squad's top-left grid cell, ties to the lowest squad id. With no squad, the spell does nothing. Today seat and squad choices stay unchanged.
   - It is rejected with `plan.rejected` when the index isn't an `onUse` ability of the card, that ability was already used this round, it can't be paid, the card is a rested artifact, or (with `rest`) the squad is already rested, by a rest ability used earlier in the same Plan too. A permanent placed this Plan may use its abilities in the same Plan.
3. **Rested units.**
   - A rested unit stays in its cell for the whole Simulate. It doesn't move or attack, and its `onAttack`, `every` and `at` abilities don't fire. Its keywords, `static` abilities and `onDeath` still work, and it can still be targeted and hit.
   - A rest from a spell at tick 0 lasts the whole round. A rest during the simulation (a trap, an `onAttack`) starts on the next tick.
   - Resting a rested unit does nothing. The prize can't be rested: T-048 adds the prize, and `rest` should skip any non-squad permanent.
   - Each rest emits `unit.rested`, with `by` set to the card that caused it, or `null` when the unit rested itself.
   - Cleanup unrests every unit, squads and resources alike.
4. **Snapshots.**
   - `SquadSnapshot.rested` is set when the squad rested itself this Plan. An ability's `rest` rests every unit of its squad. A `rest` effect rests the units its target names: one for `nearestEnemy`, the whole squad for `chosenEnemyUnit`. Each rested unit gets its own `unit.rested`.
   - Cards list their Plan abilities in `uses`, one entry per `onUse` ability: its index, `cost`, `rest`, `spell` and `usable` (on the grid, not used yet this round, payable, and with `rest` a squad that isn't rested), so the UI can grey each one out.
5. **Bots.**
   - The random bot can pick `useAbility` like any other legal action.
   - The greedy bot scores a Plan ability like a spell card of the same class, minus the unit's attack value when it rests the unit.
   - `chosenEnemyUnit` gets a target in the bots' target picking, with a test: the random bot picks any enemy squad, and the greedy bot the one worth the most points.
6. **Tests:**
   - cards: validation of `onUse`: accepted with `cost`, `rest` or both, two `onUse` abilities on one card, neither `cost` nor `rest`, `cost` or `rest` on another trigger, `rest` on an artifact, the wrong card type, and enemy targets for `rest` under each class
   - core plan: under Fog of War a defensive Plan ability and an offensive Rest ability are rejected and a utility one isn't, pay and rest, once per round per ability, two abilities of one card in one Plan, a second rest ability rejected once the unit is rested, rejected uses, a utility ability whose draw is usable in the same Plan, and a defensive ability at tick 0
   - core sim:
     - a rested unit doesn't move or attack over a whole round, but still takes damage and can die
     - an `onAttack` rest stops the target from the next tick
     - everything unrests at Cleanup
     - Mirror Snare turns an offensive `onUse` spell aimed at a squad back at the caster's nearest squad, and an offensive Rest ability aimed at a seat back at the caster's seat
   - protocol: the new action, fields and event, round-tripped
   - a determinism test: the same seed and plans, with abilities in them, give the same events
7. **Docs.**
   - packages/cards/README.md: `onUse` in › Triggers, its `cost` and `rest` fields in › Ability fields, `chosenEnemyUnit` in › Targets and › Caster choices, and the new `rest` targets with an example ("Rest this unit: draw a resource").
   - docs/PROTOCOL.md: `useAbility` in › Plans, `rested` and `uses` in › Snapshot, `unit.rested` in the events, and a line in › Versioning.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm cards:validate` passes. Existing cards don't change: resources keep `onRest`.
- [ ] A golden-style core test: a ramp unit with a draw-a-resource ability `{ "trigger": "onUse", "rest": true, "spell": "utility", … }` draws during Plan and stays put for the whole Simulate
- [ ] A sim-cli vitest plays 20 seeded games with `runGame` and fixture cards that have Plan abilities (passed in as the `cards` argument), and no game throws

## Out of scope

- Real cards with Plan abilities: T-054 (Earth's ramp units) and T-060
- Ability costs in the Leader's color allowance, and the card's color for a spell an ability casts: T-043
- Copying an ability: T-053
- The UI's ability button: M4

## Notes

- A card can have any number of Plan abilities (RULES.md › Plan abilities), so each `onUse` ability carries its own `cost` and `rest`, and the plan action names one by its index in `abilities`.
- Decision (lead, 2026-10-22): every enemy spell sets off spell traps, and Fog of War blocks defensive and offensive spells from abilities as well as cards (RULES.md › Traps, › Sample Chaos deck and Emblems).
- Default: `useResource` stays separate. A resource's Rest ability is not a Plan ability in this sense, though both cast spells the same way. Share the code, not the action.
- Default: `rest` on a group (`enemies`) rests every unit in it. Offensive classes only, as the side rules already say. `allUnits` rests every unit, the caster's own too (RULES.md › Rested).
