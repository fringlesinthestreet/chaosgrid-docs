---
id: T-061
title: 100-card decks and five starters
milestone: M3
depends_on: [T-054, T-055, T-056, T-057, T-058, T-059, T-060, T-064, T-095]
branch: agent/T-061-hundred-card-decks
model: sonnet
effort: high
scope:
  - packages/cards/src/deck/**
  - packages/cards/src/node/starter.ts
  - packages/cards/src/node/starter.test.ts
  - packages/cards/src/node/validate.test.ts
  - packages/cards/decks/**
  - packages/cards/test/fixtures/decks/**
  - packages/cards/test/fixtures/starter/**
  - packages/cards/README.md
  - packages/db/src/**/*.test.ts
  - packages/db/test/fixtures/**
  - tools/sim-cli/src/decks.ts
  - tools/sim-cli/src/**/*.test.ts
  - tools/sim-cli/README.md
  - packages/core/test/fixtures/round/games.ts
context:
  - docs/PLAN.md#M3
  - docs/RULES.md#Components and setup
  - docs/RULES.md#Card colors
  - docs/tasks/README.md#M3
  - packages/cards/README.md#Deck rules
  - packages/cards/README.md#Starter decks
  - tools/sim-cli/README.md#Decks
---

# T-061 — 100-card decks and five starters

## Goal

Main decks go from 40 to 100 cards (RULES.md › Components and setup, PLAN.md › M3). The copy limit is 4, and 1 for a Unique card (T-063, D26); the resource deck stays at 30. Each color gets a starter deck: Ember Aggro and Tide Control are rebuilt at 100 cards, and Earth, Dark and Light get new ones. `sim-cli` generates 100-card decks.

## Interfaces

What exists (copied from the code):

```ts
// packages/cards/src/deck/check.ts:25-29
export const MAIN_DECK_SIZE = 40;
export const RESOURCE_DECK_SIZE = 30;
export const MAX_COPIES = 4;                 // T-063
export function maxCopies(card: Card): number; // 1 for a Unique card (T-063)
// packages/cards/src/node/starter.ts: one JSON file per deck in packages/cards/decks/, ids
// "starter.<slug>", each pile a map of card id to copies. loadStarterDecks(dir?) checks them.
// tools/sim-cli/src/decks.ts:49
export function generateDeck(rng: RngState, cards: readonly Card[]): Deck;
// Every card that fits the Leader's color allowance (T-043), maxCopies(card) times (T-063), shuffled,
// the first MAIN_DECK_SIZE taken. Throws when those copies add up to fewer than MAIN_DECK_SIZE.
export const BASIC_RESOURCES = 20;
```

What this task changes:

```ts
export const MAIN_DECK_SIZE = 100;
// packages/cards/decks/: ember_aggro.json and tide_control.json rebuilt, plus earth_ramp.json,
// dark_revive.json and light_guard.json
```

## Deliverables

1. `MAIN_DECK_SIZE = 100`, and every doc comment and error message that says 40 follows it.
2. Starter decks, each legal and 100 + 30 cards:
   - `starter.ember_aggro` and `starter.tide_control` rebuilt, keeping their Leaders and their plans.
   - `starter.earth_ramp`, `starter.dark_revive` and `starter.light_guard`, each with its set's mono-color Leader (T-054, T-057, T-058). Resources: the color's basic resource (T-041) and the resources that fit.
   - Each `description` says how the deck plays, like the two existing ones.
   - Use T-060's rest, fear, copy and color cards where they fit a deck's plan.
3. Fixtures and tests: `test/fixtures/decks/legal.json` is a legal 100-card deck, `many_problems.json` and `test/fixtures/starter/illegal.json` keep the problems they test, and the deck-rule, starter, db and sim-cli tests expect 100. Tests use `MAIN_DECK_SIZE`, not the number, where they can.
4. A `tools/sim-cli/src/decks.test.ts` case: for every Leader in `loadCards()`, `generateDeck` with that Leader as the only one makes a deck that the deck rules accept.
5. Docs: packages/cards/README.md › Deck rules and › Starter decks (five rows; new players get the starters in M4), the "(M3)" in the starter.ts header comment becomes "(M4)", and tools/sim-cli/README.md › Decks.
6. In the PR body, reported and not gated: for each Leader, the number of distinct main-deck cards that fit its color allowance.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm cards:validate` passes
- [ ] `pnpm db:seed` runs twice without an error, and the second run stores the same five starter decks
- [ ] `pnpm --filter @chaosgrid/sim-cli test -- decks` passes, including the case for every Leader

## Out of scope

- The copy limit (T-063) and the resource deck size: they are balance knobs for M5 (RULES.md › Balance knobs)
- Two-color starter decks: M5
- Editing cards. If a starter or a generated deck can't be built, send `lead` a `question` with the counts.
- Bots and the done-when tests

## Notes

- A one-color deck at 100 cards with 4 copies needs at least 25 distinct cards that fit, more when some are Unique. After the content tasks, each mono Leader fits about 30 cards of its color plus 20 colorless ones, so a starter can pick its cards for its plan instead of taking every fitting card.
- `generateDeck` reads the constants, so its code shouldn't need to change. Its doc comment says 40 and 20 today.
- The M1 and M2 done-when tests play these decks. If one fails because of the bigger decks, send `lead` a `question` with the failing seed instead of changing the test.
- Until T-099 merges, the M2 soak fails with `rejected {forbidden:…}` when Fog of War is out, because the bots cast spells under `noSpells`. That one is known: name it in the handoff and don't chase it.
