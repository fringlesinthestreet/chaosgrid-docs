---
id: T-054
title: Earth card set
milestone: M3
depends_on: [T-042, T-067]
branch: agent/T-054-earth-set
model: sonnet
effort: medium
scope:
  - packages/cards/data/**
  - packages/cards/test/sets/earth.test.ts
  - packages/core/src/effects/coverage.test.ts
  - packages/core/src/view/cards.test.ts
context:
  - docs/PLAN.md#M3
  - docs/RULES.md#Resources and attaching
  - docs/RULES.md#Units
  - docs/tasks/README.md#M3
  - packages/cards/README.md#Fields every card has
  - packages/cards/README.md#Units
  - packages/cards/README.md#Leaders
  - packages/cards/README.md#Triggers
  - packages/cards/README.md#Effects
  - packages/cards/README.md#Targets
  - packages/cards/README.md#`draw`, `reveal` and `rest`
  - packages/cards/README.md#Spell classes
---

# T-054 — Earth card set

## Goal

Earth (`E`) gets its cards: 30 for the main deck and a mono-Earth Leader. Earth ramps and fields big units (RULES.md › Resources and attaching › Colors): it draws extra resources, and its units are large, slow and tough. Its ramp units pay for their ramp by resting (T-042): they skip a round's fighting to draw a resource. The set uses only what the DSL has after T-042.

## Interfaces

What exists (copied from the code):

```ts
// Card files: packages/cards/data/<folder>/<name>.json, one per card, id "<type>.<name>".
// Earth's basic resource is data/resources/grove.json (T-041). Colors come from the cost's pips.
// Ramp in the DSL: { "effect": "draw", "what": "resource", "target": "owner", "amount": 1 } and
// { "effect": "buff", "target": "owner", "stat": "resourceDraw", ... } (Jaksho, Cultivator).
// T-042: a Plan ability is an ability with "trigger": "onUse" and its own "cost", "rest" or both; a card
// may have several. For example { "trigger": "onUse", "rest": true, "spell": "utility", … } drawing a resource.
// packages/cards/src/node/load.ts:120 loadCards(dir?) returns every card, validated.
```

Nothing new is exported.

## Deliverables

1. 30 main-deck cards with `"set": "earth"` whose costs have only `E` pips and a generic number: about 16 units, 6 spells, 4 traps and 4 artifacts or enchantments. Costs run from 1 to 7, with at least 8 cards at 1–2 and at most 6 at 6 or more.
   - Ramp: at least 6 cards that draw resources or raise `resourceDraw`. At least 3 of them are units whose ramp is a Plan ability that rests them (an `onUse` ability with `"rest": true`), and a unit with an attack of 3 or more never ramps without resting.
   - At least 1 spell or ability rests an enemy unit (`rest` on `chosenEnemyUnit`, offensive).
   - Big units: at least 6 units of size 3 × 3 or larger with HP 15 or more, mostly Speed 1 or less.
   - Every `text` says what the card's abilities do, in the style of the existing cards.
2. A Leader, `leader.<name>.json`, with `"set": "earth"` and only `E` pips, in its cost and in its `onUse` abilities' costs.
3. `packages/cards/test/sets/earth.test.ts`: over `loadCards()`, the cards with `set === 'earth'` are 30 main-deck cards and 1 Leader, every cost, `onUse` costs included, has only `E` pips, at least 3 units have an `onUse` ability with `rest`, and no ability uses `script`.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm cards:validate` passes
- [ ] `git diff --diff-filter=MDR --name-only main...HEAD` prints nothing: this task only adds files

## Out of scope

- New effects, keywords or scripts. If an idea needs one, drop the idea and list it in the PR.
- Editing existing cards, decks or fixtures. Earth's starter deck comes with T-061.

## Notes

- Content tasks run alongside the rules tasks (docs/tasks/README.md › M3). Add files only, so you never conflict with them. A duplicate id fails `cards:validate`: if a set that merged meanwhile took one of your ids, rename yours after the rebase.
- Traps are free-standing only (T-044): model each trap on Spike Pit, with an `area` and an area trigger (README › Trap triggers).
- The M2 soak test builds generated decks around every Leader, so a broken card shows up in `scripts/check.sh`. If the soak fails because a bot can't handle a card that is legal, send `lead` a `question` instead of changing the card.
- Default names are yours: keep them distinct from existing card names (`ls packages/cards/data/*`).
