---
id: T-055
title: Ember and Tide top-up
milestone: M3
depends_on: [T-044]
branch: agent/T-055-ember-tide-top-up
model: sonnet
effort: medium
scope:
  - packages/cards/data/**
  - packages/cards/test/sets/ember-tide.test.ts
context:
  - docs/PLAN.md#M3
  - docs/RULES.md#Resources and attaching
  - docs/RULES.md#Units
  - docs/tasks/README.md#M3
  - packages/cards/README.md#Fields every card has
  - packages/cards/README.md#Units
  - packages/cards/README.md#Effects
  - packages/cards/README.md#Targets
  - packages/cards/README.md#Spell classes
---

# T-055 — Ember and Tide top-up

## Goal

Ember and Tide each reach 30 main-deck cards. After T-044 removes Backdraft and Riptide, each has 18 mono-color cards, so this adds 12 of each. Ember is damage and speed; Tide is control and draw (RULES.md › Resources and attaching › Colors).

## Interfaces

What exists (copied from the code):

```ts
// Card files: packages/cards/data/<folder>/<name>.json, one per card, id "<type>.<name>".
// Colors come from the cost's pips: "2R" is Ember, "1T" is Tide, "RT" is both (T-041).
// packages/cards/src/node/load.ts:120 loadCards(dir?) returns every card, validated.
```

Nothing new is exported.

## Deliverables

1. 12 Ember cards (only `R` pips) and 12 Tide cards (only `T` pips), all with `"set": "ember_tide"`. Count each color's units, spells, traps and backline permanents first, and fill the types that are thin. Costs run from 1 to 7.
2. `packages/cards/test/sets/ember-tide.test.ts`: the `ember_tide` cards are 12 mono-Ember and 12 mono-Tide main-deck cards with no `script`, and over `loadCards()` Ember and Tide each have at least 30 mono-color main-deck cards. A card is mono-Ember when its `usageColors` (T-043) is `['R']`, and so on.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm cards:validate` passes
- [ ] `git diff --diff-filter=MDR --name-only main...HEAD` prints nothing: this task only adds files

## Out of scope

- New Leaders: Ember and Tide have five between them
- New effects, keywords or scripts. If an idea needs one, drop the idea and list it in the PR.
- Editing existing cards, decks or fixtures

## Notes

- Content tasks run alongside the rules tasks (docs/tasks/README.md › M3). Add files only. A duplicate id fails `cards:validate`: if a set that merged meanwhile took one of your ids, rename yours after the rebase.
- Traps are free-standing only (T-044).
- If the M2 soak fails because a bot can't handle a legal card, send `lead` a `question` instead of changing the card.
