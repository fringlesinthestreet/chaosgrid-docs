---
id: T-228
title: Mana artifacts and the addMana effect
milestone: M6
depends_on: [T-223, T-227]
branch: agent/T-228-mana-artifacts-and-the-addmana-effect
model: opus
effort: high
scope:
  - packages/cards/src/dsl.ts
  - packages/cards/src/dsl.test.ts
  - packages/cards/src/schema.ts
  - packages/cards/src/schema.test.ts
  - packages/cards/README.md
  - packages/cards/data/artifacts/**
  - packages/cards/test/sets/mana.test.ts
  - packages/core/src/effects/**
  - packages/core/src/zones/**
  - packages/core/src/view/snapshot.ts
  - packages/core/src/view/payable.ts
  - packages/core/src/view/mana.test.ts
  - packages/core/src/round/rebuild.ts
  - packages/core/src/round/rebuild.test.ts
  - packages/core/test/fixtures/**
  - packages/protocol/**
  - docs/PROTOCOL.md
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Resources and mana
  - docs/RULES.md#Units
  - docs/PROTOCOL.md#Snapshot
  - docs/PROTOCOL.md#Versioning
  - packages/cards/README.md#Artifacts (`artifact`) and enchantments (`enchantment`)
  - packages/cards/README.md#Effects
  - packages/cards/README.md#Resources (`resource`)
  - packages/core/README.md#Module map
---

# T-228 — Mana artifacts and the addMana effect

## Goal

Six Unique artifacts whose Plan ability rests them for one floating mana (D83). That needs the `addMana` effect, and floating mana that doesn't come from a resource card, in core and in the snapshot (protocol version 40).

## Interfaces

On `main` (grep the names, the lines move). Floating mana is a flag on a resource today:

- `ResourceStatus { rested, floating }` (`zones/state.ts`). `restForMana(state, seat, id)` (`zones/resources.ts`) sets both; `pay()` (`zones/pay.ts`) runs `planPayment(asPayers(floatingResources(...)), cost)` and then `spendMana(id)`; `canPayFromFloating` feeds the snapshot's `payable` (D72) and `canPayByResting` its `usable`; `loseFloatingMana` runs when the plans lock (called from `plan/apply.ts`).
- Effects: `EFFECT_HANDLERS` in `effects/registry.ts` is a mapped type over the DSL's `Effect` union, so a new DSL effect fails type-checking until it has a handler; `effects/coverage.test.ts` checks every effect has one. Model the handler on `effects/handlers/draw.ts` and the DSL entry on `effect('draw', …)` in `packages/cards/src/dsl.ts`.
- Plan abilities on artifacts already work (`plan/abilities.ts`), and a rested artifact's can't be used. The ability shape, from `unit.bomb_imp`: `{ "trigger": "onUse", "cost": "D", "spell": "utility", "effect": "sacrifice", "target": "self" }`; `rest: true` is the rest cost.

What this PR adds:

```jsonc
// packages/cards/data/artifacts/ember_brazier.json, abilities[0]
{ "trigger": "onUse", "rest": true, "spell": "utility", "effect": "addMana", "target": "owner", "gives": ["R"] }
```

- `addMana`: `target` is `owner`; `gives` has the shape of a resource's `gives` (`["R"]`, `"any"`, or no color for generic only, D70). Only with `trigger: "onUse"` and `spell: "utility"`. It adds one mana that pays a pip of a color it gives or a generic pip.
- Validation (`schema.ts`): a card with an `addMana` ability is Unique, and its casting cost's mana value is at least 2. The error cites D83.
- Core keeps the seat's ability mana beside its floating resources (for example `state.zones.abilityMana[seat]: { source: CardInstanceId; gives }[]`). `pay()` plans payers over both, `loseFloatingMana` clears both, and `canPayFromFloating` counts both.
- Protocol 40: the seat's pool part of the snapshot gains `abilityMana?: { source: CardInstanceId; gives: … }[]`, optional so that literals elsewhere build unchanged, absent meaning none. It follows the pool's visibility (D34: during Plan other seats see the pool as Plan began). No new event: the utility spell's `spell.resolved` already logs it. `round/rebuild.ts` rebuilds ability mana from the snapshot for previews.

The six cards, each `unique: true`, free-standing 1×1, text "Rest: add one <color> mana":

| Id | Name | Cost | Gives |
| --- | --- | --- | --- |
| `artifact.ember_brazier` | Ember Brazier | `1R` | `["R"]` |
| `artifact.tide_font` | Tide Font | `1T` | `["T"]` |
| `artifact.verdant_idol` | Verdant Idol | `1E` | `["E"]` |
| `artifact.bone_reliquary` | Bone Reliquary | `1D` | `["D"]` |
| `artifact.sun_altar` | Sun Altar | `1L` | `["L"]` |
| `artifact.clockwork_dynamo` | Clockwork Dynamo | `2` | generic only ("Rest: add one generic mana") |

## Deliverables

1. The DSL effect and the validation rule, with `#### addMana` under Effects in the cards README and the rule under Artifacts.
2. Core: the handler, ability mana in payment, `payable` and the end of Plan, and the preview rebuild.
3. The protocol field, the version, and `docs/PROTOCOL.md`.
4. The six cards.
5. Tests: one Brazier mana and one Ember resource pay a `1R` cost; Brazier mana can't pay a `T` pip; ability mana is gone once the plans lock; `payable` counts it; a rested Brazier can't add mana again that round; the validator rejects an `addMana` card that isn't Unique or costs 1; a preview keeps the seat's ability mana.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check perf` green
- [ ] `crew check soak` green
- [ ] `pnpm cards:validate` green

## Out of scope

- The bots, the planning UI and the starter decks: T-230.
- `plan/`: if it needs a change, ask the lead (T-231 edits it next).

## Notes

- Lead default: the artifact rests for its mana, so it rests through Simulate too, which costs it nothing: it has no other ability.
- Put new core tests in new files where you can (`view/mana.test.ts`, `effects/handlers/addMana.test.ts`): the existing view and round tests change in most waves.
