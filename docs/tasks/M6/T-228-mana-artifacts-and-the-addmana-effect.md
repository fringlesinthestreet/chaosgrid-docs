---
id: T-228
title: Mana artifacts
milestone: M6
depends_on: [T-235, T-236]
branch: agent/T-228-mana-artifacts-and-the-addmana-effect
model: sonnet
effort: high
scope:
  - packages/cards/src/schema.ts
  - packages/cards/src/schema.test.ts
  - packages/cards/README.md
  - packages/cards/data/artifacts/**
  - packages/cards/decks/**
  - packages/cards/test/sets/mana.test.ts
  - packages/bots/src/**/*.test.ts
  - packages/bots/test/**
  - apps/web/src/match/planning/FloatingMana.test.tsx
  - apps/web/test/fixtures/planning/**
  - packages/cards/data/spells/sow.json
  - packages/cards/data/spells/bountiful_growth.json
  - tools/sim-cli/src/decks.test.ts
  - apps/web/src/host/host.test.ts
  - packages/core/src/plan/abilities.ts
  - packages/core/src/plan/abilities.test.ts
  - tools/sim-cli/src/game.test.ts
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Resources and mana
  - docs/PROTOCOL.md#Snapshot
  - packages/cards/README.md#Effects
  - packages/bots/README.md
---

# T-228 — Mana artifacts

## Goal

Six Unique artifacts whose Plan ability rests them for one floating mana (D83), with the rule that such a card is Unique and costs at least 2; every one-color starter deck plays its color's artifact, and the bots and the mana pips treat its mana like a resource's.

## Interfaces

After T-235 and T-236 (grep the names, the lines move).

- The DSL effect `addMana` (`packages/cards/src/dsl.ts`): `{ "trigger": "onUse", "rest": true, "spell": "utility", "effect": "addMana", "target": "owner", "gives": ["R"] }` floats one unit of mana for the round; `gives` has a resource's shape (`["R"]`, `"any"`, or `[]` for generic only, D70). Core keeps the round's mana as units `{ source, gives }` in the snapshot's `mana`, and `payable` reads them (D72).
- Plan abilities on artifacts work (`plan/abilities.ts`); a rested artifact's can't be used.
- The bots count every mana unit as a payer and use a Plan ability that adds mana when a spend needs it (`packages/bots/src/pool.ts`, each bot's draft).
- `FloatingMana.tsx` draws one pip per unit, colored by `gives`, named by its source.

## Deliverables

1. **Validation.** An artifact with an `addMana` ability is Unique, and its casting cost's mana value is at least 2; the error cites D83. Spells, units and leaders are free of it.
   - **Spells.** Sow gives 3 mana (`amount: 3`, text "+3 mana this round"). Bountiful Growth gives 8 mana (`amount: 8`, text "+8 mana this round") and is `unique: true`. Bump both cards' `version`. The rule is under Artifacts in the cards README.
2. **The six cards**, each `unique: true`, free-standing 1×1, text "Rest: add one <color> mana":

   | Id | Name | Cost | Gives |
   | --- | --- | --- | --- |
   | `artifact.ember_brazier` | Ember Brazier | `1R` | `["R"]` |
   | `artifact.tide_font` | Tide Font | `1T` | `["T"]` |
   | `artifact.verdant_idol` | Verdant Idol | `1E` | `["E"]` |
   | `artifact.bone_reliquary` | Bone Reliquary | `1D` | `["D"]` |
   | `artifact.sun_altar` | Sun Altar | `1L` | `["L"]` |
   | `artifact.clockwork_dynamo` | Clockwork Dynamo | `2` | generic only ("Rest: add one generic mana") |

3. **Starter decks.** Each one-color starter plays its color's artifact (one copy) in place of one card of its choice, and stays 90 legal cards.
4. **Tests:** the validator rejects an `addMana` card that isn't Unique or costs 1; a bot with an Ember Brazier on its grid and one Volcano casts a `1R` card, and never uses the Brazier when nothing needs its mana (bots tests only; if a bot needs code for it, ask the lead); `FloatingMana` renders one Ember pip for a Brazier's unit; a rested Brazier can't add mana again that round.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check soak` green
- [ ] `pnpm cards:validate` green

## Out of scope

- Core and the protocol: `addMana` and the mana units exist (T-235).
- The resources' own mana and the search panel (T-235, T-236).

## Notes

- Lead default: the artifact rests for its mana, so it rests through Simulate too, which costs it nothing: it has no other ability.
