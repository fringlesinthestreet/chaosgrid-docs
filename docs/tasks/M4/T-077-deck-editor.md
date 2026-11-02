---
id: T-077
title: Deck editor
milestone: M4
depends_on: [T-075, T-076, T-102]
branch: agent/T-077-deck-editor
model: sonnet
effort: high
scope:
  - apps/web/src/decks/editor/**
  - apps/web/src/app/app.test.tsx
context:
  - docs/APPS.md#HTTP API
  - docs/APPS.md#Web layout and ownership
  - packages/cards/README.md#Deck rules
  - packages/cards/README.md#Card colors
---

# T-077 — Deck editor

## Goal

Building a deck is the main thing a player does outside a match. After this task `/decks/new` and `/decks/:id` show the card browser next to the deck, check the deck with `checkDeck` on every change (the API answers `problems` with the same call over the same card list, T-073, so the two always agree), and save it. Starter decks open read-only, with a Copy button.

## Interfaces

What exists (copied from the code on 2026-10-28, plus T-068, T-069, T-075, T-076 and T-102):

```ts
// @chaosgrid/cards
export interface Deck { leader: string; main: readonly string[]; resources: readonly string[] } // one entry per copy
export const MAIN_DECK_SIZE = 100;
export const RESOURCE_DECK_SIZE = 30;
export const MAX_COPIES = 4;
export const MAIN_DECK_TYPES; // unit, spell, trap, artifact, enchantment
export function maxCopies(card: Card): number; // MAX_COPIES (4), or 1 of a Unique card
export function checkDeck(deck: Deck, cards: DeckCatalog, options?: { retired?: Iterable<string> }): DeckProblem[];
export function colorAllowance(leader: Card): Color[];
export function offColors(card: Card, leader: Card): Color[]; // T-102: usage colors the Leader doesn't allow; [] when it fits

// @chaosgrid/http (T-069): SaveDeckRequest (a z.object; .shape.name checks a deck name), DECK_NAME_MAX (60)
// apps/web (T-068): CardArt({ cardId, size }) (src/art), stubApi(routes) (test/fixtures/api.ts)
// apps/web/src/cards (T-075): useCards(): CardsState (ready: { cards, byId, retired }), compareCards,
//   filterCards, CardFilters, CardTile ({ card, count?, onClick?, disabled? }), CardDetail
// apps/web/src/decks/api.ts (T-076): getDeck, createDeck, updateDeck, copyStarter
```

What this task adds (`apps/web/src/decks/editor/`):

```ts
// deck.ts (pure, no React)
export const EMPTY_DECK: Deck; // { leader: '', main: [], resources: [] }
/**
 * Where a card goes: a Leader replaces the Leader, a resource joins resources, a card whose type is in
 * MAIN_DECK_TYPES joins main; any other type (Chaos) gives null.
 */
export function pileFor(card: Card): DeckPile | null;
export function addCard(deck: Deck, card: Card): Deck;   // unchanged when pileFor is null
export function removeCard(deck: Deck, pile: DeckPile, id: string): Deck; // one copy
/** The pile as rows: one per card id with its count, sorted with compareCards; ids byId lacks go last, by id. */
export function pileRows(ids: readonly string[], byId: ReadonlyMap<string, Card>): { id: string; card?: Card; count: number }[];

export function DeckEditorPage(): JSX.Element; // re-exported by decks/index.tsx
```

## Deliverables

1. **`deck.ts`** as above, with the copy limit left to `checkDeck`: adding a fifth copy works and shows the `tooManyCopies` problem, so the editor never disagrees with the rules.
2. **`DeckEditorPage`.**
   - `/decks/new` starts from `EMPTY_DECK`; `/decks/:id` loads the deck with `getDeck`. A 404 shows "Deck not found." with a link to `/decks`.
   - **Left, the card browser:** `CardFilters` and a grid of `CardTile`s with each card's count in the deck. Clicking a tile adds it with `addCard`. A card `pileFor` gives null for (Chaos) gets `disabled="Not deckable"`. A "Fits the Leader" toggle, on by default once a Leader is set, hides the cards whose `offColors(card, leader)` isn't empty.
   - **Right, the deck:** name (checked with `SaveDeckRequest.shape.name.safeParse`, so the limit is the API's `DECK_NAME_MAX`) and description; the Leader (its `CardArt`, name, and its `colorAllowance` as color pips); the main deck and the resource deck as `pileRows`, each with a count against its size (`37 / 100`, `30 / 30`) and − / + per row. Clicking a row shows its `CardDetail`.
   - **Problems:** `checkDeck(deck, byId, { retired })` on every change, listed under the deck by pile, each with its `message`. Rows whose card is in a problem's `cards` are marked. A legal deck shows "Legal".
3. **Save.** A Save button, enabled when the name is valid and something changed. New decks `createDeck` and then replace the URL with `/decks/<id>`; existing ones `updateDeck`. An illegal deck saves (the API never refuses one) with the line "Saved. This deck isn't legal yet, so it can't be played." After a save the editor shows the API's `problems`. A failed save (`unknownCard`, `network`, …) shows `error.message` as one line and keeps the edits.
4. **Unsaved changes.** An "Unsaved changes" marker next to Save, and a `beforeunload` prompt while there are any.
5. **Starter decks** (`starter: true`): the same view, read-only (no − / +, no browser clicks, no Save), with a Copy button (`copyStarter`) that opens the copy. They're read-only for everyone, the seeded `admin` who owns them too (D40): the seed rewrites them from `packages/cards/decks`.
6. **Tests:**
   - `deck.ts`: `pileFor` for each type (a Chaos card gives null); `addCard` of a Leader replaces it; `removeCard` drops one copy; `pileRows` counts and sorts with `compareCards`, with an unknown id last
   - the page with `stubApi`: a new deck, set a Leader, add a card: the counts and problems update; "Fits the Leader" hides an off-color card and shows it again when turned off; a Chaos tile is dimmed and a click adds nothing; a name of `DECK_NAME_MAX + 1` characters disables Save; Save posts the `SaveDeckRequest` and the URL becomes `/decks/<id>`; a starter is read-only and Copy posts a copy; a 404 shows "Deck not found."
   - a consistency test: for every starter deck from `loadStarterDecks` (test-only import), the editor's `checkDeck` call returns `[]`

## Acceptance

- [ ] `crew check` green
- [ ] With the API on 5077 and the web on 4077: sign up, copy a starter, remove one main-deck card (the `mainDeckSize` problem shows), add it back ("Legal"), save, reload: the deck is as saved

## Out of scope

- Drag and drop, deck import and export, deck statistics (mana curve).
- Changing the deck rules: they're `@chaosgrid/cards`' (T-061).

## Notes

- Default: the browser's filter lives in the URL query like `/cards`' (T-075), so a reload keeps it.
- Default: in-app navigation away with unsaved changes isn't blocked; only `beforeunload` asks. The marker makes the state visible.
- Default: adding a Leader when one is set replaces it, and the old one isn't moved anywhere.
- Never hard-code 40, 100, 30 or 60: read `MAIN_DECK_SIZE`, `RESOURCE_DECK_SIZE` and `DECK_NAME_MAX`.
- No card rule lives in the editor: placement reads `MAIN_DECK_TYPES`, colors read `offColors` and `colorAllowance`, the order is `compareCards`, and legality is `checkDeck`. There is no web `fitsLeader`.
