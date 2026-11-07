---
id: T-212
title: No Charge in core and the cards
milestone: M5
depends_on: [T-195, T-196, T-197, T-198, T-213, T-214, T-215]
branch: agent/T-212-no-charge-in-core-and-the-cards
model: opus
effort: high
scope:
  - packages/cards/src/**
  - packages/cards/data/**
  - packages/cards/test/**
  - packages/cards/README.md
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/core/**
  - packages/db/test/fixtures/**
  - packages/bots/**
  - tools/sim-cli/test/**
  - apps/web/src/match/model/**
  - apps/web/src/match/overlays/log.ts
  - apps/web/src/match/overlays/log.test.ts
  - apps/web/src/match/planning/draft.ts
  - apps/web/src/i18n/en/overlays.json
  - apps/web/src/**/*.test.ts
  - apps/web/src/**/*.test.tsx
  - apps/web/test/fixtures/**
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Units
  - docs/RULES.md#Resources and mana
  - docs/RULES.md#Leaders
  - docs/CORE.md#Defaults for open rules questions
  - docs/PROTOCOL.md#Plans
  - docs/PROTOCOL.md#Versioning
  - packages/cards/README.md#Effect DSL
---

# T-212 — No Charge in core and the cards

## Goal

D74 replaces D68: Charge goes, and a unit spends mana during Plan only on its level-ups and its Plan abilities. The 13 cards that printed Charge keep each "If charged" effect behind a Plan ability that costs their old Charge in generic mana, and a new effect, `grantAbility`, gives a unit an ability until Cleanup for the effects that are statics or triggers. After this PR no card, schema, plan action, event or snapshot field says Charge. `attach` stays until T-200, but switches nothing on.

## Interfaces

What exists on main (copied on 2026-11-06; grep the names, the lines move):

```ts
// packages/cards/src/schema.ts:184 UnitStatsSchema = strict({ ...combatStats, charge: nonNegativeInt })
//   :252-:263 checkCharge(): Charge above 0 exactly when the card has a `charged` ability, called at :278 and :295
// packages/cards/src/dsl.ts:49-:52 CONDITIONS = ['charged', 'survived'] ("If charged" and "If survives")
// packages/cards/data: 120 unit and Leader files print `stats.charge` (most 0); the 13 below have `"condition": "charged"`
// The model for the new effect: Seraphine's Plan ability, a defensive grant for the round:
//   { "trigger": "onUse", "cost": "2L", "spell": "defensive", "effect": "grantKeyword", "target": "self",
//     "keyword": "extraLife", "value": 1, "duration": "round" }
//   and core's packages/core/src/effects/handlers/grantKeyword.ts, effects/registry.ts, effects/modifiers.ts

// packages/protocol/src/plan.ts:52-:59 ChargeAction { action: 'charge', squad }, in PlanAction and PlanActionType ('charge')
// packages/protocol/src/event.ts:551-:557 SquadChargedEvent ('squad.charged'), in the union; :219 a reason's doc names Charge
// packages/protocol/src/snapshot.ts:268-:271 SquadSnapshot.charged (optional since T-193)
// packages/protocol/src/card.ts:94 a unit card's stats: charge: z.int().min(0)
// packages/protocol/src/visibility.ts:71 case 'squad.charged'; index.ts exports ChargeAction and SquadChargedEvent

// packages/core/src/plan/apply.ts:65-:81 the `charge` step (payFor the Charge in generic mana, squad.charged = true,
//   emits squad.charged), listed in the steps at :104
// packages/core/src/effects/sources.ts:217-:242 isCharged() (squad.charged || squad.attached.length >= stats.charge)
//   and the `charged` condition's case; view/board.ts:64 SquadSnapshot.charged; state/state.ts:110 Squad.charged;
//   plan/squads.ts:60; zones/resources.ts:207 Cleanup clears it; effects/stats.ts:49-:79 and view/cards.ts:54-:57
//   the stats' `charge`; comments in plan/context.ts:19, plan/index.ts:30, state/level.ts:6, view/units.ts:40;
//   state/testing.ts:76-:84 a test card with Charge 2 and a `charged` ability

// packages/bots/src/random-bot.ts:35 ODDS.charge, :70 `charged`, :91 charges(); random-bot.test.ts:162;
//   rules.test.ts:78 and test/referee.ts:269 their `charge` cases; `charge:` in the stats of test literals
// tools/sim-cli/test/scripted.ts:181 case 'charge'; test/fixtures/golden/cards: Vask, Oriel and Dominic with
//   `charged` abilities, units with `charge`; golden-script.ts:171 an `attach` (T-200 removes it)
// apps/web/src/match/overlays/log.ts:75, :231 ('overlays.log.squadCharged'), :384; planning/draft.ts:115, :175
//   ("Charge {squad}"); model/apply.ts:521 case 'squad.charged'; model/types.ts:187; en/overlays.json "log.squadCharged"
// packages/db/test/fixtures/cards/units/flame_lancer.json and invalid/units/*.json: `charge` in stats
```

T-197 has removed the web's Charge glow, its Charge row and every attach control before you start; T-196 has removed the greedy and turtle bots' attaching.

## Deliverables

1. **The DSL.** `charged` leaves `CONDITIONS`, and `stats.charge` leaves the unit and Leader schemas with `checkCharge`. A new effect, `grantAbility`, takes `ability` (one ability, written as a card writes it) and `duration`: its targets have that ability as if their card printed it until the duration ends, so on a Plan ability `"round"` lasts until Cleanup. The granted ability may be a static, a timed or a triggered ability, not a Plan, Rest or When played ability and not another grant: the schema refuses those.
2. **The cards.** Every unit and Leader file drops `charge`, Brass Arbiter (T-198) included. The 13 cards turn their "If charged" ability into a Plan ability (`onUse`) that costs their old Charge in generic mana and has no `rest`, write the text below, and bump `version`:

   | Card | Text after this PR | Plan ability |
   | --- | --- | --- |
   | Harpoon Diver | Reach. 1: this squad's units gain "On attack: push the target 1 cell away" this round | defensive `grantAbility` of the old `onAttack` push |
   | Brannoch, Emberroot | 1: draw a resource. 2R: deal 3 damage to an enemy unit | utility `draw` of 1 resource |
   | Oriel of the Still Deep | Reach. Static. Blocker (3). 2: this unit gains "On attack: the target's Attack speed is halved for {level} seconds" this round | defensive `grantAbility` of the old `onAttack` debuff |
   | Sethra, Ashen Reaver | 1: this unit gets +2 Attack this round. 2D: revive a unit card from your discard pile | defensive `buff`, `duration: "round"` |
   | Seraphine, Dawnwarden | Shield (2). 1: this unit has Ward this round. 2L: this unit gets Extra life (1) this round | defensive `grantKeyword` ward, `duration: "round"` |
   | Ilvane, Tidebright | 1: this unit has Ward this round. 2T: draw a card | defensive `grantKeyword` ward, `duration: "round"` |
   | Jaksho, Cultivator | 1: draw a resource | utility `draw` of 1 resource |
   | Thessaly, Rootmother | 1: draw a resource. 2E: rest an enemy squad | utility `draw` of 1 resource |
   | Morvane, Gravecaller | 1: this unit gets +2 Attack this round. 2D: revive a unit card from your discard pile | defensive `buff`, `duration: "round"` |
   | Marrow, Tidewalker | 1: draw a resource. 2T: draw a card | utility `draw` of 1 resource |
   | Dominic, Fire Marshal | Reach. 1: this unit gains "When killing/assisting on a kill on an enemy, spawn {level} cinder grunt(s) (destroyed at end of round)" this round | defensive `grantAbility` of the old `onKill` spawn |
   | Grimbark, the Hollow | 1: draw a resource. 2D: revive a unit card from your discard pile | utility `draw` of 1 resource |
   | Vask, Pyre Marshal | Reach. Every 3 seconds: deal 2 to every enemy within 2 cells. 1: this unit gains "Your Ember units have 1+{level} Speed" this round | defensive `grantAbility` of the old static aura |

   The cards' other abilities don't change.
3. **Core.** The `charge` step, `Squad.charged`, `isCharged`, the `charged` condition and the stats' `charge` go. `squad.attached` still fills from `attach` until T-200, and nothing reads it to switch an ability on. The `grantAbility` handler gives each target unit the ability from the moment the spell resolves until the duration ends: a static is on while it lasts, a trigger fires on its trigger, `{level}` reads the unit's level as a printed ability does, and it ends at Cleanup, or earlier when the unit's squad leaves the grid. Previews and the rebuild see the grants as they see the other round effects. The draws during Plan stay as CORE.md › Defaults says: Wild Grove still draws its extra resource at once.
4. **The protocol.** `ChargeAction` and `'charge'` in `PlanActionType`, `SquadChargedEvent`, `SquadSnapshot.charged`, the card stats' `charge` and their visibility case go. Bump `PROTOCOL_VERSION` (36, after T-215's 35), with docs/PROTOCOL.md's title, Plans, Board events, Snapshot and card sections, and a Versioning row naming D74.
5. **The rest of the repo follows.**
   - The random bot stops charging (its every-type test follows `PlanActionType`); `rules.test.ts` and the referee lose their `charge` cases.
   - The web: the log's `squad.charged` line, `draft.ts`'s `charge` cases, the model's case and the `log.squadCharged` string go.
   - Every test literal and fixture drops `charge` and `charged`.
   - sim-cli: the golden fixture cards take the shapes above, and the golden script uses Vask's grant, so the golden streams cover `grantAbility`. Regenerate the streams as `golden.test.ts` says, and say why in the PR.
   - The web's two event logs: if they no longer parse, regenerate them with the commands in `apps/web/test/fixtures/logs/README.md`, then Prettier.
6. **Docs.** packages/cards/README.md: the `stats` row, Conditions, the effects table, and a `grantAbility` example with Vask's card in place of the `charged` examples. packages/core/README.md: its Charge lines, and the grant where the README lists the round effects. packages/bots/README.md, wherever it still names Charge.
7. **Tests.**
   - cards: the schema refuses `stats.charge`, the `charged` condition, and a grant of a Plan, Rest or When played ability; `pnpm cards:validate` accepts the 13 cards.
   - core: Vask's grant raises an Ember unit's Speed for the round and not the next; Harpoon Diver's push fires on both units' attacks; Oriel's debuff and Dominic's spawn fire on their triggers; no grant survives Cleanup; a grant's Plan ability without the floating mana is `unaffordable`; Jaksho's draw adds a resource at once, and a later `restForMana` in the same plan rests it.
   - protocol: a `charge` plan action is refused as an unknown action, and no event is `squad.charged`.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm test` passes.
- [ ] `pnpm test:soak` passes.
- [ ] `pnpm cards:validate` passes.
- [ ] `grep -rnE "stats\.charge|'charge'|squad\.charged|isCharged|chargePayable" packages apps tools` finds nothing but tests that check Charge is gone (a negative assertion such as `not.toContain('charge')` stays), and `grep -rln '"charge":\|"charged"' packages tools apps/web/test` finds nothing.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- `attach`, `attachedTo`, `SquadSnapshot.attached` and Durability: T-200, in the next wave, which also makes T-195's optional fields required.
- Balance: the cards keep their costs and stats. T-206 measures them.
- The card view's actions and the inactive state: T-199 and T-202.

## Notes

- This PR runs alone in its wave because it touches every package's literals. Rebase on main just before you start.
- Lead defaults: a grant, a buff and a keyword are defensive, so they resolve at tick 0; the draws are utility and resolve at once; no new ability rests its unit. Harpoon Diver's grant reaches both units of its squad, as its charge did: use the target that says so, and if none does, say what you picked.
- The snapshot doesn't list grants. The live stats and keywords it already reports show a grant's effect where it changes them.
- Attached artifacts and enchantments (equipment and auras, `mode: 'attached'`, `attachedUnit`) stay: D74 removes only resources attaching.
