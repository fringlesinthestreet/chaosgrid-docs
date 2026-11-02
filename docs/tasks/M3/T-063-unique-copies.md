---
id: T-063
title: Unique cards and the 4-copy limit
milestone: M3
depends_on: [T-044]
branch: agent/T-063-unique-copies
model: sonnet
effort: medium
scope:
  - packages/cards/src/**
  - packages/cards/test/fixtures/**
  - packages/cards/README.md
  - tools/sim-cli/src/decks.ts
  - tools/sim-cli/src/decks.test.ts
context:
  - docs/RULES.md#Components and setup
  - docs/tasks/README.md#M3
  - packages/cards/README.md#Fields every card has
  - packages/cards/README.md#Deck rules
  - packages/cards/README.md#Starter decks
---

# T-063 — Unique cards and the 4-copy limit

## Goal

A main deck holds at most 4 copies of a card, and at most 1 of a Unique card (D26, RULES.md › Components and setup › Unique). Units, artifacts, enchantments and traps can be Unique, and every Leader is. `sim-cli`'s generated decks follow the new limits.

## Interfaces

What exists (copied from the code):

```ts
// packages/cards/src/deck/check.ts:24-29
export const MAIN_DECK_SIZE = 40;
export const RESOURCE_DECK_SIZE = 30;
/** Copies of one card a main deck may hold. Resource decks have no limit. */
export const MAX_COPIES = 2;
// packages/cards/src/deck/check.ts:183-189: problem 'tooManyCopies',
// "<n> copies of <card>: the main deck takes at most 2 of a card"
// tools/sim-cli/src/decks.ts:49
export function generateDeck(rng: RngState, cards: readonly Card[]): Deck;
// decks.ts:58 throws when mainCards.length * MAX_COPIES < MAIN_DECK_SIZE;
// decks.ts:63 adds every fitting card MAX_COPIES times, shuffles, and takes MAIN_DECK_SIZE.
```

What this task adds:

```ts
// cards: an optional field on unit, artifact, enchantment and trap cards
unique?: true
export const MAX_COPIES = 4;
/** True for a card marked `unique` and for every Leader. */
export function isUnique(card: Card): boolean;
/** The copies of `card` a main deck may hold: 1 for a Unique card, MAX_COPIES otherwise. */
export function maxCopies(card: Card): number;
```

## Deliverables

1. **Cards.**
   - `"unique": true` is valid on `unit`, `artifact`, `enchantment` and `trap` cards. Any other value, such as `false`, fails: leave the field out instead.
   - It fails validation on spells, resources and Chaos cards, and on Leaders with the message "a Leader is always Unique".
   - `isUnique` and `maxCopies` are exported from the package entry.
2. **Deck rules.**
   - `MAX_COPIES = 4`. `checkDeck` uses `maxCopies(card)` for each main-deck card. For a Unique card the problem stays `tooManyCopies`, with the message "<n> copies of <card>: the main deck takes at most 1 of a Unique card".
   - Resource decks still have no copy limit.
   - Every doc comment and error message that says 2 follows the new limits.
3. **Generated decks.** `generateDeck` adds each fitting card `maxCopies(card)` times. Its throw counts what those copies add up to. Its doc comment follows.
4. **Tests:**
   - cards: `unique` is accepted on each of the four types and rejected on the others, and on Leaders with the message above
   - deck rules: 4 copies pass and 5 fail, a Unique card passes with 1 and fails with 2, and the Unique message is the one above
   - sim-cli: in `decks.test.ts`, with an inline pool that holds a Unique card, a generated deck holds it at most once, and the throw counts a Unique card as 1
   - Fixtures: `test/fixtures/decks/many_problems.json` and `test/fixtures/starter/illegal.json` (3 copies of Cinder Grunt today) still trigger `tooManyCopies`: raise their copies to 5 where they hold 3 or 4.
5. **Docs.** packages/cards/README.md: a `unique` row in › Fields every card has, the limits in › Deck rules, and every other line that says 2 copies, such as the sample output in › Starter decks (`grep -n 'copies' packages/cards/README.md`).

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm cards:validate` passes. No card file changes.
- [ ] `grep -rn "at most 2 of a card" packages tools` prints nothing

## Out of scope

- Unique cards: T-060 adds the first ones.
- Deck size: T-061 takes the main deck to 100.
- Effects that copy a permanent card: none exists. When one comes, it must skip Unique cards (RULES.md › Unique).
- Showing Unique in snapshots or the UI: M4.
- tools/sim-cli/README.md › Decks: T-061 rewrites it for 100-card decks.

## Notes

- Default: copying a spell that a Unique card's ability cast is allowed (RULES.md › Unique). Only the card itself can't be copied.
- Default: Unique is checked only in the main deck. A Leader sits in the command zone, so its uniqueness needs no deck check.
- More copies change the generated decks, so the seeded soak and tournament tests in `tools/sim-cli` may see different games. If one of them fails, send `lead` a `question` with the failing seed instead of changing the test.
