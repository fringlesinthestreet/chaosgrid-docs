---
id: T-066
title: Core deck fixture from the starter decks
milestone: M3
depends_on: [T-061, T-065]
branch: agent/T-066-core-starter-fixture
model: sonnet
effort: medium
scope:
  - packages/core/test/fixtures/zones/**
  - packages/core/src/zones/*.test.ts
context:
  - packages/cards/README.md#Starter decks
  - packages/core/README.md#Tests
---

# T-066 — Core deck fixture from the starter decks

## Goal

Core's zones tests build their games from `packages/core/test/fixtures/zones/starter-decks.json`. That file is a hand-made copy of two decks, and it already differs from the real starter decks in `packages/cards/decks/`. The cards package loads those decks itself (`loadStarterDecks()`), and core tests may import `@chaosgrid/cards/node`. This task replaces the copy with the real decks, and makes the zones tests read deck sizes from the cards package. After that, a change to a starter deck or to the deck sizes doesn't break core's tests.

## Interfaces

What exists (copied from the code on 2026-10-22; T-047 and T-061 change some of it, so look for the current version):

```ts
// packages/core/test/fixtures/zones/decks.ts
export const SAMPLE_CARDS: readonly Card[] = loadCards();
export function expand(counts): string[]                 // counts → one entry per copy
export const STARTER_SEATS: readonly SeatSetup[]          // from starter-decks.json, via expand
export function starterSetup(seed = 1, config?): GameSetup // { seats: STARTER_SEATS, seed, config }
// Users: packages/core/src/zones/{draw,hand,resources,setup}.test.ts
// packages/core/src/zones/setup.test.ts:34 expects 2 * (1 + 40 + 30) cards; :77 expects { hand: 7, deck: 33, … }
// packages/cards/src/node/starter.ts
loadStarterDecks(dir = DEFAULT_DECKS_DIR): StarterDeck[]  // sorted by file name; checks the format only
StarterDeck { id, name, description, deck: Deck }         // Deck { leader, main: string[], resources: string[] }, one entry per copy
// @chaosgrid/cards: MAIN_DECK_SIZE (100 after T-061), RESOURCE_DECK_SIZE (30)
// packages/core/src/zones/setup.ts: SeatSetup { seat, leader, main, resources }; T-047: a game has exactly 4 seats
```

What this task changes:

```ts
// packages/core/test/fixtures/zones/decks.ts
export const STARTER_SEATS: readonly SeatSetup[] = loadStarterDecks()
  .slice(0, 4)
  .map(({ deck }, seat) => ({ seat, ...deck }));
// starter-decks.json and expand() are deleted
```

## Deliverables

1. **The fixture.** `STARTER_SEATS` comes from `loadStarterDecks()`: the first four decks by file name, one per seat. `starterSetup` keeps its signature. Delete `starter-decks.json`, and delete `expand` if nothing else uses it. Update the file's header comment.
2. **The tests.**
   - Every count in the zones tests that comes from a deck must come from the cards package or from `STARTER_SEATS`. Use `MAIN_DECK_SIZE`, `RESOURCE_DECK_SIZE`, `STARTER_SEATS.length` and the seat's own `main` and `resources`, not numbers. For example, `setup.test.ts:34` becomes the sum over `STARTER_SEATS` of `1 + main.length + resources.length`, and the deck left after the opening hand becomes `main.length - 7`.
   - Tests that need a particular card keep building their own decks, as `setup.test.ts` already does for Underwater Volcano. No test may depend on which card a starter deck holds or where it sits.
   - List each number you replaced in the PR.

## Acceptance

- [ ] `crew check` green
- [ ] `packages/core/test/fixtures/zones/starter-decks.json` is gone, and `grep -rn "starter-decks.json" packages/core` finds nothing.
- [ ] In your worktree, swap one main-deck card in `packages/cards/decks/ember_aggro.json` for another legal card, and change one deck's pile order. `pnpm --filter @chaosgrid/core test src/zones` stays green. Then run `git checkout -- packages/cards/decks`: that file isn't in your scope, so never commit it.

## Out of scope

- `packages/core/test/fixtures/round/games.ts`. Its decks are built on purpose to hold every resource with an ability, so the round tests can play them. Keep them.
- Making `expand` public in `@chaosgrid/cards`: the starter decks come already expanded.
- The sim-cli and bots fixtures.

## Notes

- Decision (human, 2026-10-22): reuse packages and functions where it makes sense and doesn't block later work. Here that means the real starter decks, loaded by the cards package.
- Default: seat `s` plays the `s`-th starter deck by file name. Five starter decks exist after T-061, so four seats always have one each. If fewer than four exist, the fixture throws with a clear message rather than repeating decks.
- Core doesn't check deck sizes (`zones/setup.ts` checks only card types), so these tests never relied on the deck rules. That stays true.
