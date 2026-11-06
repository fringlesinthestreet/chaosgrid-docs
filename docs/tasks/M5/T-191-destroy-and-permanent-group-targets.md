---
id: T-191
title: Destroy and permanent group targets
milestone: M5
depends_on: []
branch: agent/T-191-destroy-and-permanent-group-targets
model: opus
effort: high
scope:
  - packages/cards/src/dsl.ts
  - packages/cards/src/dsl.test.ts
  - packages/cards/README.md
  - packages/core/src/effects/**
  - packages/core/src/round/cleanup.ts
  - packages/core/src/round/cleanup.test.ts
  - packages/core/test/fixtures/effects/**
  - packages/core/README.md
  - packages/cards/src/spells.ts
  - packages/cards/src/spells.test.ts
context:
  - docs/RULES.md#Zone mechanics
  - docs/DECISIONS.md#Decision log
  - packages/cards/README.md#`banish` and `sacrifice`
  - packages/cards/README.md#Targets
  - packages/cards/README.md#Scopes and filters
---

# T-191 — Destroy and permanent group targets

## Goal

D67 adds a sixth zone mechanic, **Destroy**: a permanent goes to its owner's discard pile, whoever's card does it, and scores nothing unless the card says so (RULES.md › Zone mechanics). This PR adds the `destroy` effect to the DSL and core, and two group targets for non-unit permanents, so the removal and wipe spells the human asked for after the 2026-11-05 playtest (T-201) can be written as data.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// packages/cards/src/dsl.ts
export const UNIT_TARGETS = ['self', 'attackTarget', 'killer', 'attachedUnit', 'triggeringUnit',
  'nearestEnemy', 'chosenOwnUnit', 'chosenEnemyUnit'] as const;                      // :62
export const UNIT_GROUP_TARGETS = ['enemies', 'ownUnits', 'allUnits', 'killerUnits'] as const; // :74
export const PLAYER_TARGETS = ['owner', 'opponents', 'allPlayers', 'destroyer'] as const;      // :77
/** Permanents that aren't (only) units. */
export const PERMANENT_TARGETS = ['ownPermanents', 'chosenOpponentTraps'] as const;           // :80
const SACRIFICE_TARGETS = ['self', 'chosenOwnUnit', 'ownPermanents'] as const;                // :118
export const FilterSchema = strict({ color, range, hpAtMost, excludeSelf, survived })        // :148
effect('banish', {                                                                            // :374
  ...unitsFields('banish', [...UNITS, ...PERMANENT_TARGETS, ...PLAYER_TARGETS]),
  from: oneOf('from', BANISH_PILES).optional(),
  amount: PositiveAmountSchema.optional(),
  scores: z.literal(true, { error: 'scores is true: banishing scores as if each unit were killed' }).optional(),
}),
effect('sacrifice', { target: targetOf('sacrifice', SACRIFICE_TARGETS), filter: FilterSchema.optional() }), // :385

// packages/core/src/effects/handlers/sacrifice.ts:59 — marks each target in state.effects.sacrificed and
// kills it with no killer and the cause 'sacrifice' (a squad's living units: On death fires, then
// `squad.sacrificed`; a permanent: `kill(ctx, null, id, 'sacrifice')`). Nobody scores.
// packages/core/src/round/cleanup.ts:117 — Cleanup's step 4: a squad sacrificed this round retires
// (`squad.retired`) instead of respawning, and a sacrificed permanent goes to the discard pile.
// packages/core/src/effects/handlers/banish.ts:29 banishHandler; :51 gridTargets(state, ability, run, ctx)
// collects the squads and permanents a grid banish takes; `scores` → scoreBanish (scoring/points.ts).
// packages/core/src/effects/registry.ts:61 banish: banishHandler, :62 sacrifice: sacrificeHandler
// packages/core/src/effects/targets.ts: unitTargets, ownPermanents (:71), playerTargets
// packages/core/src/effects/coverage.test.ts — every ability of every sample card runs on a small board.
// packages/core/README.md:107 "Banish and sacrifice (T-049): effects/ handles both. …"

// The protocol's plan targets (packages/protocol/src/target.ts:29): seat, row, area, squad,
// squadToCell, discardPileCard, spell. There is no permanent target, and this PR adds none.
```

Existing removal, for scale: Exile (4L, banish an enemy unit), Oblivion (6D, the same), Radiant Purge (6L), Banishing Rune (a 4L trap), Soul Drain (3D: sacrifice one of your units, deal 6 to all enemy units).

## Deliverables

1. **The `destroy` effect.** `effect('destroy', { …unitsFields('destroy', [...UNITS, ...PERMANENT_TARGETS]), scores?: true })` in the DSL, with the error texts in the house style. The core handler, `effects/handlers/destroy.ts`, follows RULES.md › Zone mechanics:
   - a squad's living units die at once with the cause `destroy` (On death fires), and Shield, Extra life and effects that stop a unit dying don't stop it;
   - an artifact, enchantment or trap is destroyed at once; a face-down trap too;
   - at Cleanup the card goes to its owner's discard pile instead of respawning or standing again: reuse step 4, which does this for sacrificed cards, with destroyed ones marked beside them;
   - a Leader can't be destroyed: it dies instead, and respawns as usual;
   - the prize and Emblems are never destroyed;
   - nobody scores, unless `scores` is set: then the destroyer scores each living unit of an opponent's squad as a kill, as `banish` does with `scores`.
2. **Two group targets for permanents.** `PERMANENT_TARGETS` gains `enemyPermanents` (every artifact, enchantment and trap of every other seat, attached ones included) and `allPermanents` (every seat's, the caster's included). Neither takes the prize or an Emblem. Both work with the existing scopes (`radius`, `zone: "chosenOpponentRow"`) and with a new filter field, `type`: one card type or a list (`"artifact"`, `["artifact", "enchantment"]`, `"trap"`). The filter's other fields keep reading units only; say so in its error text if `type` is combined with a unit-only field. `banish` takes the new targets too, since it spreads `PERMANENT_TARGETS`.
3. **No protocol change.** Destroy reports through the events a death and a sacrifice already use: `unit.died`, `permanent.destroyed`, then `squad.retired` or `permanent.retired` at Cleanup. Choices stay the existing plan targets: "destroy an enemy unit" is `chosenEnemyUnit` (a `squad` pick), and "destroy what stands in one row of an opponent's grid" is `enemyPermanents` with `zone: "chosenOpponentRow"` (a `row` pick).
4. **Docs.** The cards README: a `destroy` entry beside `banish` and `sacrifice`, the two targets in › Targets, `type` in › Scopes and filters. The core README's line on banish and sacrifice names destroy.
5. **Tests.**
   - DSL: `destroy` parses with each target kind, `scores`, the new targets and `type`; the errors read well.
   - Core:
     - destroying a squad fires its On death, its units are dead, and at Cleanup its card is in the discard pile and the squad is gone;
     - Shield and Extra life don't save a destroyed unit;
     - destroying an artifact: destroyed at once, in the discard pile at Cleanup, not standing again;
     - a Leader dies and respawns;
     - no points without `scores`, kill points with it;
     - `allPermanents` with `type: "trap"` destroys face-down traps of every seat and nothing else;
     - `enemyPermanents` in a chosen row takes only that row's permanents.
   - `coverage.test.ts` runs a sample `destroy` ability with each new target. No card uses it yet, so add test-only abilities there if the test needs a card.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/cards test dsl` passes.
- [ ] `pnpm --filter @chaosgrid/core test effects cleanup` passes.
- [ ] `pnpm test` passes.
- [ ] `pnpm test:soak` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The cards that use Destroy, the wipes and the cheaper Dark cards: T-201.
- A plan target for one chosen permanent: the protocol and every planner would need it, so the lead left it out. Single-permanent removal is a row pick or a trap pick for now.
- Durability: T-189 takes it out next wave, so don't change what Cleanup does with it.

## Notes

- Destroy is a sacrifice anyone can cast, with optional scoring: the sacrifice code is the place to start.
- Lead default: `allPermanents` and `allUnits` include the caster's own, so a wipe hits its caster too, as RULES.md's "every player's included" means. A card that spares its caster uses `enemies` or `enemyPermanents`.
- T-183 runs beside you in core's `chaos/` only, and T-184 edits six card files; nothing you touch.
