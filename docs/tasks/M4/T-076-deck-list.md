---
id: T-076
title: Deck list and the deck API client
milestone: M4
depends_on: [T-073, T-074, T-075]
branch: agent/T-076-deck-list
model: sonnet
effort: medium
scope:
  - apps/web/src/decks/index.tsx
  - apps/web/src/decks/api.ts
  - apps/web/src/decks/api.test.ts
  - apps/web/src/decks/list/**
  - apps/web/src/app/app.test.tsx
context:
  - docs/APPS.md#HTTP API
  - docs/APPS.md#Web layout and ownership
  - docs/APPS.md#Routes
  - packages/cards/README.md#Deck rules
---

# T-076 — Deck list and the deck API client

## Goal

A logged-in player lands on `/decks`. After this task that page lists their decks and the starter decks, says which are legal, and lets them open, copy, create and delete decks. `decks/api.ts` is the one client for the deck routes, which the deck editor (T-077) and the lobby (T-084) use.

## Interfaces

What exists (T-068, T-069, T-073 to T-075):

```ts
// @chaosgrid/http: DeckSummary { id, name, description, leader, starter, legal, updatedAt },
//   DeckDetail { id, name, description, starter, starterId, deck, problems, retired, updatedAt },
//   DeckListResponse { decks }, SaveDeckRequest { name, description?, starterId?, deck }, ROUTES,
//   DECK_NAME_MAX (60)
// API (T-073): GET /api/decks lists own decks (most recently updated first), then the starters (by name)
// apps/web: request() and ApiError (src/api); CardArt({ cardId, size }) (src/art); useCards() and
//   CardTile (src/cards, T-075); RequireLogin (T-074); stubApi(routes) (test/fixtures/api.ts, T-068)
// apps/web/src/decks/index.tsx (T-068): re-exports DecksPage from ./list (a placeholder) and DeckEditorPage from ./editor
```

What this task adds:

```ts
// apps/web/src/decks/api.ts
export function listDecks(): Promise<DeckSummary[]>;
export function getDeck(id: string): Promise<DeckDetail>;
export function createDeck(body: SaveDeckRequest): Promise<DeckDetail>;
export function updateDeck(id: string, body: SaveDeckRequest): Promise<DeckDetail>;
export function deleteDeck(id: string): Promise<void>;
/** Reads a starter and saves a copy the player owns, named `copyName(starter.name)`. */
export function copyStarter(starterId: string): Promise<DeckDetail>;
/** 'Ember Aggro' → 'Ember Aggro (copy)'; a long name is cut so the result is DECK_NAME_MAX long. */
export function copyName(name: string): string;
export type DecksState =
  | { status: 'loading' }
  | { status: 'error'; error: ApiError; retry(): void }
  | { status: 'ready'; decks: DeckSummary[] };
/** listDecks as a hook, fetched on mount (no cache: decks change). The lobby (T-084) reads it too. */
export function useDecks(): DecksState;

// apps/web/src/decks/list/
export function DecksPage(): JSX.Element; // re-exported from decks/index.tsx
```

## Deliverables

1. **`api.ts`** on `request()` and `ROUTES`, each answer parsed with its `@chaosgrid/http` schema. `copyStarter` sends `starterId` with the copy, so the API records where it came from. `useDecks` calls `listDecks` on mount; its error state's `retry()` calls it again.
2. **`DecksPage`** (`/decks`) reads `useDecks()` and shows two sections:
   - **My decks:** one row per deck: the Leader's `CardArt` and name (the name from `useCards().byId`), the deck name, a badge from the summary's `legal` ("Legal", or "Not legal" in the theme's warning color; T-073 computes it with the editor's `checkDeck` call, so the list and the editor agree), and the last update as a date. The row opens `/decks/:id`. Each row has Delete, which asks "Delete <name>?" inline (Yes / No) before it calls the API, then drops the row.
   - **Starter decks:** the same rows, marked "Starter", with a Copy button instead of Delete. Copy saves the copy and opens it in the editor. A starter's row opens it read-only (T-077). Starters stay read-only for everyone, the seeded `admin` who owns them too (D40), so their rows never have Delete.
   - A New deck button (`/decks/new`) above both. With no decks of their own, My decks says "No decks yet. Copy a starter deck or make a new one."
   - Loading and error states use the theme; an error shows `error.message` and a Retry button.
3. **`decks/index.tsx`** exports `DecksPage` from `./list`, re-exports `./api` (other folders import this one only through its index: the lobby, T-084, reads `useDecks` and `getDeck` from `../decks`), and keeps re-exporting `DeckEditorPage` from `./editor`.
4. **Tests** (with `stubApi`):
   - each `api.ts` function calls the right method and path (an id with a space is encoded) and parses the answer; a 404 rejects with `ApiError` `notFound`
   - `copyName`: the suffix, and a name of `DECK_NAME_MAX - 2` characters is cut so the result is `DECK_NAME_MAX` long and still ends in " (copy)"
   - `copyStarter` reads the starter, then posts its deck with `starterId` and the copy name
   - `DecksPage`: own decks and starters in their sections with the right badges; the empty state; Delete asks, then calls `DELETE` and drops the row; No keeps it; Copy posts and navigates to `/decks/<new id>`; a failed list shows the error and Retry reloads

## Acceptance

- [ ] `crew check` green
- [ ] With the API on 5076 and the web on 4076: sign up, `/decks` shows the five starter decks; Copy on one opens `/decks/<id>`, and back on `/decks` the copy is under My decks as Legal

## Out of scope

- Editing a deck (T-077). Until T-077 merges, `/decks/:id` shows T-068's placeholder.
- Renaming from the list, sorting, search.

## Notes

- Default: the list keeps the API's order (own decks most recently updated first, then starters by name); the page only splits it on `starter`.
- Default: a Leader the cards don't have (retired) shows its id in place of its name (`CardArt` still draws a placeholder for the id); the deck is "Not legal" anyway.
- T-084 (lobby) uses `useDecks` and `getDeck`; keep their signatures.
