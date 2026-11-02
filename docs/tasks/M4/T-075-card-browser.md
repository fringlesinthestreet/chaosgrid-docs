---
id: T-075
title: Card browser
milestone: M4
depends_on: [T-068, T-069, T-071, T-102]
branch: agent/T-075-card-browser
model: sonnet
effort: medium
scope:
  - apps/web/src/cards/**
context:
  - docs/tasks/M4/README.md#Web layout and ownership
  - docs/tasks/M4/README.md#Routes
  - packages/cards/README.md#Fields every card has
  - packages/cards/README.md#Cost
  - packages/cards/README.md#Card colors
---

# T-075 — Card browser

## Goal

A player has to see the cards before building a deck. After this task `/cards` lists every card the API serves, with filters (type, color, cost, text) and a detail view, and the folder exports the pieces the deck editor (T-077) and the match (T-085) reuse: the card fetch, the filter and the sort, and the card views. Every card rule it shows (cost totals, colors, Unique) comes from `@chaosgrid/cards`; the web computes none of its own.

## Interfaces

What exists (copied from the code on 2026-10-28, plus T-068, T-069 and T-102):

```ts
// @chaosgrid/cards
export const CARD_TYPES; export type CardType; // the eight types, `id` is `<type>.<slug>`
export const COLORS = ['R', 'T', 'E', 'D', 'L'] as const; export type Color;
export function cardColor(card: Card): Color[]; // the card's colors (none for colorless)
export function isUnique(card: Card): boolean;
export function parseCost(cost: string): Cost;
export function costTotal(cost: string): number; // T-102: "2RR" is 4
// Every card: id, name, type, set, version, cost, text (the printed rules text: what UIs show)

// @chaosgrid/http: CardsResponse { cards: Card[]; retired: string[] }, ROUTES.cards
// apps/web (T-068): request() and ApiError (src/api), Panel/Button/ErrorText and the class
// cg-dimmed (src/theme), CardArt({ cardId, size }) (src/art), stubApi(routes) (test/fixtures/api.ts)
```

What this task adds (`apps/web/src/cards/`, exported from `index.tsx`):

```ts
// api.ts
/** ROUTES.cards once per page load; later calls share the same promise. */
export function getCards(): Promise<CardsResponse>;
/** Tests only: forget the cached promise, so the next getCards fetches again. */
export function resetCardsCache(): void;
export type CardsState =
  | { status: 'loading' }
  | { status: 'error'; error: ApiError; retry(): void }
  | { status: 'ready'; cards: Card[]; byId: Map<string, Card>; retired: string[] };
/** getCards as a hook. */
export function useCards(): CardsState;

// filter.ts (pure, no React)
export interface CardFilter {
  text: string;            // matches name or rules text, case-insensitive
  types: CardType[];       // empty: every type
  colors: Color[];         // empty: every color; a card matches if cardColor(card) has any of them
  colorless: boolean;      // also show colorless cards (cardColor(card) is empty) when colors is not empty
  cost: { min?: number; max?: number }; // on costTotal(card.cost)
}
export const EMPTY_FILTER: CardFilter;
/** The one card order: costTotal(card.cost), then name. */
export function compareCards(a: Card, b: Card): number;
export function filterCards(cards: readonly Card[], filter: CardFilter): Card[]; // sorted with compareCards
export function filterToQuery(filter: CardFilter): URLSearchParams;
export function filterFromQuery(query: URLSearchParams): CardFilter;

// components
/** `disabled`: why the tile can't be picked; the tile is dimmed (cg-dimmed), says why, and onClick doesn't fire. */
export function CardTile(props: { card: Card; count?: number; onClick?(): void; disabled?: string }): JSX.Element;
export function CardDetail(props: { card: Card }): JSX.Element; // every field a player reads
export function CardFilters(props: { value: CardFilter; onChange(next: CardFilter): void; types?: readonly CardType[] }): JSX.Element;
export function CardsPage(): JSX.Element;
```

## Deliverables

1. **`api.ts`.** `getCards` calls `request()` with `CardsResponse` and caches the promise for the page's lifetime (a failed load clears it, so the next call retries). `useCards` builds `byId` with `indexCards`; its error state's `retry()` calls `getCards` again.
2. **`filter.ts`** as above. Colors and colorless read `cardColor(card)`, and cost reads `costTotal(card.cost)`. The filter lives in the URL query (`?q=…&type=unit,spell&color=R&cost=2-4`), so a filtered view can be shared and survives a reload.
3. **`CardTile`:** the card's `CardArt`, name, cost pips, type, and a `count` badge when given (the deck editor shows copies). Keyboard: it's a button when `onClick` is set and `disabled` isn't.
4. **`CardDetail`:** name, type, cost, colors, `text`, and the type's numbers (a unit's stats, a Leader's, a resource's), plus a Unique flag from `isUnique(card)` and a colorless flag when `cardColor(card)` is empty. Read the fields from the card's type; don't print raw JSON.
5. **`CardsPage`** (`/cards`): `CardFilters` on the left, a grid of `CardTile`s, and `CardDetail` in a side panel for the clicked card. A count of shown cards ("42 of 180"). Loading and error states use the theme; the error shows `error.message` with a Retry button.
6. **Tests** (`resetCardsCache()` before each):
   - `filterCards` on the sample cards: text matches name and rules text; types; colors with and without `colorless`; a cost range; the sort order (`"2RR"` after `"3"`, ties by name)
   - `filterToQuery` and `filterFromQuery` round-trip, and a bad query (`cost=x`) gives `EMPTY_FILTER`'s value for that field
   - `getCards` calls `fetch` once for two callers, and again after a failure
   - `CardTile` with `disabled` is dimmed, shows the reason and ignores a click
   - `CardsPage` with `stubApi`: typing in the search box narrows the grid, clicking a tile shows its detail; a failed load shows its message, and Retry loads the cards

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] With the API on 5075 and the web on 4075, `/cards` lists the cards; `/cards?type=leader` lists only Leaders

## Out of scope

- Adding cards to a deck (T-077 uses these components).
- Real card art: it comes later from cloud storage through the art manifest (D39, T-082). `CardArt` draws the placeholders until then, and this folder never reads sprites itself.
- Showing retired cards: the API leaves them out of `cards`.

## Notes

- Default: the sample tests read the cards with `loadCards` from `@chaosgrid/cards/node` (a test file may import it, DECISIONS.md rule 6) and serve them with `stubApi`.
- Default: Chaos cards show in the browser with their type filter; they aren't deckable, which the deck editor handles (T-077).
- The web's fetch is `getCards`, so it never shares a name with `@chaosgrid/cards/node`'s `loadCards`, which reads files (tests only).
- `compareCards` is the only card order on the web: the deck editor's piles (T-077) sort with it too.
