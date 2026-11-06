---
id: T-184
title: Unique timed cards
milestone: M5
depends_on: []
branch: agent/T-184-unique-timed-cards
model: haiku
effort: low
scope:
  - packages/cards/data/units/lightbringer_priest.json
  - packages/cards/data/units/mender_of_dawn.json
  - packages/cards/data/units/current_mage.json
  - packages/cards/data/enchantments/mossy_shrine.json
  - packages/cards/data/enchantments/gravewheel.json
  - packages/cards/data/artifacts/tide_clock.json
  - packages/cards/decks/**
  - packages/cards/src/node/starter.test.ts
  - packages/cards/test/sets/**
  - packages/cards/test/fixtures/decks/legal.json
  - packages/cards/stats/cards.json
context:
  - docs/RULES.md#Components and setup
  - docs/DECISIONS.md#Decision log
  - packages/cards/README.md#Starter decks
---

# T-184 — Unique timed cards

## Goal

D66: a card whose "Every N seconds" ability reaches other units or permanents stacks with every copy on the grid, so it's Unique and a deck holds one copy. The human's example from the 2026-11-05 playtest: four Lightbringer Priests Shield a squad every 5 seconds, and nothing answers the stack.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// The six cards and their timed texts
// units/lightbringer_priest.json  "Every 5 seconds: your units within 3 cells get Shield (1) this round"
// units/mender_of_dawn.json       "Every 4 seconds: heal 2 to every unit you control within 3 cells"
// units/current_mage.json         "Every 5 seconds: push the nearest enemy 1+{level} cells away"
// enchantments/mossy_shrine.json  "Every 4 seconds: heal 2 HP to your units"
// enchantments/gravewheel.json    "Every 10 seconds: revive the unit card that entered your discard pile last (rests after use)"
// artifacts/tide_clock.json       "Every 15 seconds: heal your units 2 (rests after use)"

// The convention, from the two Unique cards today:
// units/sun_seraph.json     "unique": true, "text": "Unique. Reach"
// units/elder_colossus.json "unique": true, "text": "Unique. Static"

// packages/cards/src/deck/check.ts
export const MAX_COPIES = 4;                     // :30
export function isUnique(card: Card): boolean    // :33: a Leader, or `unique: true`
export function maxCopies(card: Card): number    // :38: 1 for a Unique card, else MAX_COPIES
// :186-:192 the main deck's copy check: "N copies of X: the main deck takes at most 1 of a Unique card"

// The starter decks that hold more than one copy today (packages/cards/decks/*.json, "main": { id: count }):
// light_guard.json:  "unit.lightbringer_priest": 3, "unit.mender_of_dawn": 3
// earth_ramp.json:   "enchantment.mossy_shrine": 3
// tide_control.json: "unit.current_mage": 3, "artifact.tide_clock": 4
```

## Deliverables

1. **Six Unique cards.** Each of the six files gets `"unique": true`, its text starts with "Unique. " as Sun Seraph's does, and its `version` goes up by one. Stonebark Troll ("Every 5 seconds: heal 2 HP to itself") stays as it is: it heals only itself.
2. **Legal starter decks.** Each starter deck keeps one copy of each of these cards and stays at 100 cards: the freed slots go to cards already in the deck, or to other cards of the deck's colors, keeping each deck's plan (its `description`). No card goes above its own limit.
3. **Tests.** Wherever a test pins these cards' texts, copies or a deck's list (`starter.test.ts`, the set tests in `packages/cards/test/sets/`), it follows the change. Add one test that the six are Unique, in the set tests where the colors' cards are checked.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm cards:validate` passes.
- [ ] `pnpm --filter @chaosgrid/cards test` passes.
- [ ] `pnpm test` passes.
- [ ] `pnpm test:soak` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Resources: Prism, Harvest Cycle and Old Library become Unique in T-198 (D69).
- RULES.md's sample rows: the lead marked Current Mage and Tide Clock there already.
- The engine: `maxCopies` already applies `unique` to the main deck.

## Notes

- The web's and the bots' tests that read the starter decks only check that they're legal, so they shouldn't change. If one pins a copy count, stop and say which.
- The sim's golden game plays frozen copies of its cards, so it doesn't change.
