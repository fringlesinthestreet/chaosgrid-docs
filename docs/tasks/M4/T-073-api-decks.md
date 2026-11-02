---
id: T-073
title: API deck routes
milestone: M4
depends_on: [T-072, T-061]
branch: agent/T-073-api-decks
model: sonnet
effort: high
scope:
  - apps/api/**
context:
  - docs/tasks/M4/README.md#Accounts
  - docs/tasks/M4/README.md#HTTP API
  - packages/db/README.md#Decks
  - packages/cards/README.md#Deck rules
---

# T-073 — API deck routes

## Goal

The deck list and the deck editor (T-076, T-077) need the logged-in player's decks over HTTP. After this task the API lists, reads, creates, replaces and deletes a player's decks, shows every player the starter decks (read-only for everyone, the admin too: D40), and returns each deck's problems from `checkDeck` over the catalog the web's editor checks with, so the web never stores a deck it can't explain and the two never disagree.

## Interfaces

What exists (copied from the code on 2026-10-28, plus T-069 to T-072):

```ts
// @chaosgrid/db, packages/db/src/decks.ts
export function isStarterDeck(deck: Pick<DeckRow, 'id' | 'starterId'>): boolean; // id === starterId
/** The decks `owner` has, starter decks included, without their cards: oldest first. */
export function listDecks(db: Db, owner: number): DeckRow[];
/** No owner check. A retired card is a `retiredCard` problem and is listed in `retired`. */
export function getDeck(db: Db, id: string): SavedDeck | undefined;
/** Create (no id) or replace one of `owner`'s decks. Saves an illegal deck as it is. */
export function saveDeck(db: Db, owner: number, input: DeckInput, options?: { now?: Date }): SavedDeck;
// throws DeckError: 'notFound' (no such deck, or another owner's), 'starterDeck', 'unknownCard'
/** No owner check. False when no deck has the id; DeckError('starterDeck') for a starter. */
export function deleteDeck(db: Db, id: string): boolean;
export interface SavedDeck extends Omit<DeckRow, 'leader'> { deck: Deck; problems: DeckProblem[]; retired: string[] }
export const LOCAL_PLAYER_ID = 0; // the admin (D40): owns the starter decks and any deck made before M4
// getDeck checks the deck against its own card rows, retired cards' data included, so its
// problems can differ from the web editor's checkDeck(deck, byId, { retired }) (T-077)
export function listCards(db: Db): { cards: Card[]; retired: string[] }; // T-070: a retired card is only in `retired`

// @chaosgrid/cards
export function checkDeck(deck: Deck, cards: DeckCatalog, options?: { retired?: Iterable<string> }): DeckProblem[];
export type DeckCatalog = Iterable<Card> | ReadonlyMap<string, Card>;

// @chaosgrid/http (T-069): DeckSummary, DeckDetail, DeckListResponse, SaveDeckRequest, ROUTES
// apps/api (T-071, T-072): ApiFailure, parseInput, requirePlayer(request): { id, username },
//   seedOnStart(db), setAdminPassword(db, password)
```

What this task adds: `apps/api/src/routes/decks.ts` with the five deck routes of [M4/README.md](README.md) › HTTP API, and `src/decks/map.ts`:

```ts
/** checkDeck as the web's editor runs it (T-077): over listCards(db), read once per request. */
export function deckProblems(deck: Deck, listed: { cards: Card[]; retired: string[] }): DeckProblem[];
export function toDeckDetail(deck: SavedDeck, problems: DeckProblem[]): DeckDetail;
export function toDeckSummary(deck: SavedDeck, problems: DeckProblem[]): DeckSummary; // legal: problems.length === 0
```

## Deliverables

1. **Who may see a deck.** A deck is visible to a player when they own it or it's a starter deck. Any other deck answers 404 `notFound`, the same as a missing one, so ids of other players' decks don't leak.
2. **Problems.** Every `problems` and `legal` the routes answer come from `deckProblems`: `checkDeck(deck, listCards(db).cards, { retired: listCards(db).retired })`, with `listCards` read once per request. That's the catalog the web's editor checks with (`GET /api/cards`, T-077), so the two never disagree. `SavedDeck.problems` isn't used, because `getDeck` also knows the retired cards' data.
3. **`GET /api/decks`.** The player's own decks (`listDecks(db, player)` without the ones `isStarterDeck` matches), most recently updated first, then the starter decks (`listDecks(db, LOCAL_PLAYER_ID).filter(isStarterDeck)`) by name, so the admin, who owns them, lists each starter once. Each one is a `DeckSummary`; read each deck with `getDeck` for its cards.
4. **`POST /api/decks`.** Parse `SaveDeckRequest`; `saveDeck(db, player, …)` without an id; 201 `DeckDetail`. A `starterId` that isn't a starter deck's id answers 400 `invalidInput`.
5. **`GET /api/decks/:id`.** 200 `DeckDetail` for a visible deck.
6. **`PUT /api/decks/:id`.** A starter deck answers 403 `starterDeck` for everyone, the admin included (D40), checked before `saveDeck` (whose owner check would say `notFound` for anyone else). Otherwise `saveDeck` with the id; its `DeckError` codes become the same `ErrorCode`s. `starterId` in the body is ignored, as `saveDeck` ignores it on a replace.
7. **`DELETE /api/decks/:id`.** Not visible: 404. A starter: 403, the admin included. Otherwise `deleteDeck`, then 204. `deleteDeck` has no owner check, so the route checks first.
8. **README.** The deck section: visibility, the list order, that the starters are read-only for everyone, where the problems come from, and that saving never refuses an illegal deck.
9. **Tests** (`inject`, an in-memory DB seeded with `seedOnStart`, two signed-up players A and B, and the admin logged in with a test password set by `setAdminPassword`):
   - every 2xx body parses with its schema: `DeckListResponse` for the list, `DeckDetail` for one deck
   - every deck route without a cookie answers 401
   - A's list holds every starter with `starter: true`; B's list too
   - the admin's list holds each starter once; its `PUT` and `DELETE` on a starter answer 403 `starterDeck`, and the starter is unchanged
   - A copies a starter (`POST` with its `starterId` and its cards): 201, `starter: false`, `starterId` set, `problems` empty, and it's first in A's list
   - A saves an illegal deck (too few cards): 201 with a `mainDeckSize` problem, `legal: false` in the list
   - a deck naming a card id that doesn't exist answers 400 `unknownCard` and saves nothing
   - A's deck holding a card a reseed then retires: `GET` answers the `problems` that `checkDeck(deck, listCards(db).cards, { retired })` finds, a `retiredCard` problem among them, and the list shows `legal: false`
   - B gets 404 on `GET`, `PUT` and `DELETE` of A's deck
   - A's `PUT` and `DELETE` on a starter deck answer 403 `starterDeck`
   - A replaces their deck: the name and cards change, `updatedAt` moves to the pinned `now`
   - `DELETE` answers 204, then `GET` answers 404
   - an id with a space and a slash round-trips through `ROUTES.deck`
   - a `SaveDeckRequest` with an extra key answers 400 `invalidInput`

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/api test` passes

## Out of scope

- Changing `@chaosgrid/db`'s deck functions. If one is missing something the routes need, ask lead.
- Paging, search and sorting options for the list.
- Importing and exporting decks as files.
- Anything the admin may do that a player can't: nothing in M4 (D40).

## Notes

- T-061 (M3) is merged: a legal deck is a Leader, 100 main-deck cards and 30 resources, and there are five starters (`packages/cards/decks/`). Build the tests' legal decks from a starter, so a rules change doesn't break them.
- Player `0` is the admin (D40): it logs in once `CHAOSGRID_ADMIN_PASSWORD` is set (T-072), and its list is its own non-starter decks (any made before M4), then the starters, each once.
- Decision (human, 2026-10-28): D40. The starter decks are read-only for everyone, the admin too, because the seed rewrites them from `packages/cards/decks`.
- Default: the list reads each deck in full to compute `legal`. That's at most a few dozen decks on a local DB; don't add a cache.
