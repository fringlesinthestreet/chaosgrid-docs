---
id: T-189
title: No Durability in core and the cards
milestone: M5
depends_on: [T-183, T-184, T-186, T-191]
branch: agent/T-189-no-durability-in-core-and-the-cards
model: opus
effort: high
scope:
  - packages/core/**
  - packages/cards/src/**
  - packages/cards/data/**
  - packages/cards/test/**
  - packages/cards/README.md
  - packages/protocol/src/snapshot.ts
  - packages/protocol/src/snapshot.test.ts
  - packages/protocol/src/version.ts
  - docs/PROTOCOL.md
  - apps/web/src/cards/CardFace.test.tsx
  - apps/web/src/cards/browser.test.tsx
  - tools/sim-cli/test/**
  - packages/protocol/src/card.ts
  - apps/web/src/i18n/en/cards.json
  - packages/db/test/fixtures/**
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Round structure
  - docs/RULES.md#Units
  - docs/RULES.md#Zone mechanics
  - docs/CORE.md#Defaults for open rules questions
  - packages/cards/README.md#Keywords
---

# T-189 — No Durability in core and the cards

## Goal

D67 replaces D48: there is no Durability. Units respawn at every Cleanup and killed artifacts, enchantments and traps stand again, however often they die, until an effect takes them off the grid (destroy, sacrifice, banish) or the new keyword **Fleeting** retires them at their first Cleanup. After this PR no card but an Emblem prints `durability`, core keeps none in its state, the five Durability-0 cards are Fleeting and Kettle is redesigned. The protocol keeps its Durability fields for now, always null, so the bots and the web build unchanged.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// packages/cards/src/schema.ts
export const UnitCardSchema = strict({ …common('unit'), …squadFields, durability: nonNegativeInt, levelUnlock, … }) // :245-:252
// :267-:268 the Leader: `durability: nonNegativeInt.optional()` ("RULES.md gives leaders no Durability")
// :304-:310 permanentSchema(): artifacts, enchantments, traps: `durability: nonNegativeInt.optional()`
// :394-:401 the Emblem Chaos card: `durability: positiveInt` — it stays: an Emblem's HP is its Durability
// :200-:205 squadFields: keywords: KeywordsSchema.default(() => ({})) — only squad cards carry keywords
// packages/cards/src/values.ts:79 KeywordsSchema = z.strictObject({ blocker, trample, reach, flying, static,
//   ignoresBlockers, seeksEmblems, consumed, shield, extraLife, ward }); KEYWORDS = its keys
// packages/cards/src/dsl.ts:296-:300
effect('heal', { ...unitsFields('heal', [...UNITS, 'ownPermanents']),
  /** What comes back, never above the printed value. Absent: `hp`. */
  stat: oneOf('stat', ['hp', 'durability']).optional(), amount: PositiveAmountSchema }),

// packages/core/src/state/state.ts:104 Squad.durability: number | null; :168 Permanent.durability: number | null
// packages/core/src/plan/squads.ts:20 printedDurability(card) (exported from plan/index.ts:41, used by level.ts:58)
// packages/core/src/plan/level.ts:58 a level-up resets squad.durability; :65 squad.leveled carries it
// packages/core/src/effects/health.ts:171-:225 printedDurability, restoreDurability, heal(…, 'durability')
// packages/core/src/effects/handlers/heal.ts:13-:41 the `"stat": "durability"` branches
// packages/core/src/effects/targets.ts:75-:92
export function ownPermanents(state, run, filter): EntityId[]
//   squads: owner's, `squad.durability !== null` (so no Leader, no token), on the board, `survived` filter
//   permanents: owner's artifacts and enchantments with `permanent.durability !== null` (free-standing ones)
// packages/core/src/round/cleanup.ts
function retire(ctx, squad): void            // :104: squad.retired, card to the discard pile, squad and units leave
function wearSquads(ctx): void               // :140: a wiped Consumed squad retires; a wiped one loses 1 Durability
                                             //   (squad.durabilityChanged); any squad at 0 retires (D48)
function restorePermanents(ctx): void        // :165: a destroyed permanent loses 1 Durability
                                             //   (permanent.durabilityChanged), goes to the discard pile at 0, else stands again
// Durability is also copied or set in round/rebuild.ts (:213-:351), effects/tokens.ts:61, effects/handlers/move.ts:47,
// effects/handlers/revive.ts:149/:170, chaos/spawn.ts:42/:102, zones/setup.ts:108, view/board.ts:60/:99,
// view/cards.ts:228 and state/testing.ts.

// packages/protocol/src/snapshot.ts:168-:176 the unit HandCard: `durability: Durability` (not nullable);
// SquadSnapshot.durability (:261) and PermanentSnapshot.durability (:286) are `Durability.nullable()` already,
// as are `squad.placed.durability` and `squad.leveled.durability` (event.ts:344, :546).
// packages/protocol/src/version.ts:6 PROTOCOL_VERSION = 31; docs/PROTOCOL.md › Versioning: one row a version.

// The five Durability-0 cards (packages/cards/data/units/): bone_thrall (text ""), carrion_moth ("Flying"),
// cinder_wisp ("Ignores Blockers"), dread_conscript ("If survives round: draw a card"), pallid_archer ("Ranged").
// packages/cards/data/leaders/kettle_chaos_broker.json (version 3): "Flying. If survives round, restores {level}
// durability to surviving permanents": onRoundEnd, condition survived, heal ownPermanents, stat durability.
```

The rules are updated already: RULES.md › Round structure (Cleanup), › Units (Fleeting, Respawn), › Zone mechanics, the sample tables without a Durability column, and Kettle's sample row: "Flying. If survives round, draw {level} card".

## Deliverables

1. **Fleeting.** `KeywordsSchema` gains `fleeting` (a flag). The card schema refuses it on a Leader and on a Chaos card ("a Leader can't be Fleeting (D67)"). The cards README's keyword table gets its row, from RULES.md › Units.
2. **No Durability on cards.** `durability` leaves the unit, Leader and permanent schemas; the Emblem keeps it. Every card JSON loses it, with `version` + 1. The five Durability-0 cards get `"keywords": { "fleeting": true }` (merged with their keywords) and their text starts with "Fleeting" ("Fleeting", "Fleeting. Flying", "Fleeting. Ignores Blockers", "Fleeting. If survives round: draw a card", "Fleeting. Ranged"). `heal` loses `stat`: it heals HP only.
3. **Kettle.** Its ability becomes `onRoundEnd`, condition `survived`, `draw` on `owner`, amount `{level}` (main-deck cards), its text "Flying. If survives round, draw {level} card", version 4. Same cost and stats.
4. **No Durability in core.** `Squad.durability` and `Permanent.durability` leave the state, with `printedDurability`, `restoreDurability`, the heal branches and every copy listed above. An Emblem's HP still comes from its card's `durability`. A level-up resets nothing. `ownPermanents` keeps the cards it reached: the owner's squads but its Leader and tokens, and its free-standing artifacts and enchantments; update its doc comment and the cards README's row.
5. **Cleanup.** `wearSquads` becomes: a wiped Consumed squad retires, as today; a Fleeting squad retires whether its units survived or not; no other squad retires. `restorePermanents` stands every destroyed permanent again (`permanent.respawned`), and attached cards still follow a squad that left. Core never emits `squad.durabilityChanged` or `permanent.durabilityChanged`. The order of Cleanup's steps (T-191's destroy, sacrifices, then the squads) doesn't change.
6. **The protocol, transitional.** The unit `HandCard`'s `durability` becomes `Durability.nullable()`; core sends null there and in every other Durability field (snapshots, `squad.placed`, `squad.leveled`). Say in each field's doc comment and in docs/PROTOCOL.md that it is always null since D67, and that the two `*.durabilityChanged` events are no longer sent. Bump `PROTOCOL_VERSION` to 32 with its row in docs/PROTOCOL.md › Versioning. The types stay so the bots and the web build: removing them is a later task's.
7. **Docs.** `packages/core/README.md` (the state's fields, the permanent and token events) and `packages/cards/README.md` (the card format, `heal`, `ownPermanents`, Fleeting) match the code.
8. **Tests.**
   - schema: a unit or a permanent with `durability` is refused; an Emblem without it is refused; Fleeting on a Leader is refused.
   - Cleanup: a squad wiped several rounds running respawns each time; a Fleeting squad retires after a round it survived and after one it didn't; a destroyed artifact stands again every round; a wiped Consumed squad still retires.
   - No `*.durabilityChanged` event in a whole game (`round/play.test.ts` or a soak).
   - Kettle draws `{level}` cards at round end when it survived, and none when it died.
   - Update every test and fixture that set or expected Durability (core's `test/fixtures/**`, `state/testing.ts`, the cards' set tests, the two web tests in the scope, sim-cli's fixtures). The web's planning and log fixtures keep their Durability numbers: they are still valid protocol data.
9. **The golden game.** sim-cli's golden game changes (no wear, Fleeting, Kettle): regenerate it the way `tools/sim-cli/test/golden.test.ts` says, and say why in the PR.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/core test` passes.
- [ ] `pnpm --filter @chaosgrid/cards test` passes.
- [ ] `pnpm cards:validate` passes.
- [ ] `pnpm test` passes.
- [ ] `pnpm test:soak` passes.
- [ ] `grep -rl '"durability"' packages/cards/data` lists only the three Emblem cards.
- [ ] On main and on the branch, `pnpm sim --games 20 --seed 1 --bots planner,greedy,turtle,random` runs; both reports go in the PR, with the median rounds per game and the median squads on the grid at the last round.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The bots and the web reading Durability: T-194 takes it out of the web next wave; the bots read none.
- Removing the protocol's Durability types and events: T-200.
- `CardFace.tsx`, `CardTable.tsx` and `filter.ts` in the web: they show a printed Durability only when the card has one, which is now an Emblem's. T-192 edits the face next wave.
- The art key `ui.durability` and the Fleeting badge: T-194.
- Charge and `attach`: T-193.

## Notes

- Lead default: Kettle draws main-deck cards, not resources, so the ramp stays with the green and Tide cards. If the hand limit eats the draw at Cleanup, say so in the PR rather than changing the order of Cleanup.
- Lead default: a Fleeting squad scores nothing and fires no On death when it retires (RULES.md › Units, Fleeting: "It isn't a death").
- Boards now only grow until removal answers them; T-201 adds the removal. If the soak's games run longer or end on the round cap more often, report the numbers instead of tuning.
- The deck lists in `packages/cards/decks/` name cards by id and don't change.
