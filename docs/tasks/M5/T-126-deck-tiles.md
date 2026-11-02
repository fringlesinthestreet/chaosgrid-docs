---
id: T-126
title: Deck list tiles
milestone: M5
depends_on: [T-124]
branch: agent/T-126-deck-tiles
model: sonnet
effort: medium
scope:
  - apps/web/src/decks/list/**
  - apps/web/src/i18n/en/deckList.json
context:
  - apps/web/README.md#Text
  - apps/web/README.md#Tests
---

# T-126 — Deck list tiles

## Goal

The deck list (`/decks`) becomes a grid of tiles, as the human asked after playing M4 (2026-10-29). Each tile shows:

- the Leader's art
- the deck's name and the Leader's name
- the counts: main n/100 and resources n/30
- a badge that says whether the deck is legal
- three key cards

No colors and no stats: the human said no. The actions stay as they are: New deck, Copy on a starter, and Delete with a confirmation.

## Interfaces

What exists (copied from the code on 2026-10-29). T-110 to T-118 don't touch `decks/`:

```ts
// @chaosgrid/http
interface DeckSummary { id: string; name: string; description: string | null; leader: string;
  starter: boolean; legal: boolean; updatedAt: string }
//   `legal`: the API runs checkDeck on the deck with the current cards (deckProblems, apps/api/src/decks/map.ts:10-15)
//   and sets `legal` when it found none (toDeckSummary, :40-49).
//   The summary has no cards, so the counts and the key cards need each deck's DeckDetail.
interface DeckDetail { id; name; description; starter; starterId;
  deck: { leader: string; main: string[]; resources: string[] }; problems; retired; updatedAt }

// decks/api.ts (T-076's file: use it as it is)
export function useDecks(): DecksState; // { status: 'loading' } | { status: 'error'; error: ApiError; retry() } | { status: 'ready'; decks: DeckSummary[] }
export function getDeck(id: string): Promise<DeckDetail>;
export function copyStarter(starterId: string): Promise<DeckDetail>;
export function deleteDeck(id: string): Promise<void>;

// decks/list/DecksPage.tsx
// formatDate(iso) (:12-15); message(error) (:17-19): the API's message, or "Can't reach the server."
// DeckRow({ deck, leaderName, onDeleted }) (:27-94): a flex-row <li>: a Link to /decks/<id> with
//   CardArt at 32, the name (strong) and the Leader's name (dimmed); "Starter"; "Legal" or "Not legal";
//   the date; Copy on a starter, else Delete → span[role=group][aria-label="Delete <name>?"] with Yes
//   and No; ErrorText.
// DeckSection({ title, decks, names, empty, onDeleted }) (:96-124): h2, then a <ul> in a Panel.
// DecksPage (:126-174): h1 "Decks"; "Loading decks…"; the error Panel with Retry; the "New deck"
//   link; "My decks" (empty: "No decks yet. Copy a starter deck or make a new one.") and "Starter
//   decks"; `removed` hides a deleted deck until the list reloads; useCards() names the Leaders.

// ../../art: CardArt({ cardId, size }): decorative (aria-hidden), so the card's name shows beside it.
//   ART.md › Stills: art is drawn at whole multiples, and 96 is the 32 px portrait at ×3.
// ../../cards: useCards(): its 'ready' state has byId: Map<string, Card>.
// @chaosgrid/cards: MAIN_DECK_SIZE (100), RESOURCE_DECK_SIZE (30), costTotal(cost).
// ../../i18n (T-124): t(id, values?).
// Tests. list.test.tsx: summary(over) builds a DeckSummary. test/fixtures/api.ts: stubApi (a request
//   it has no stub for fails the test), deckListBody, deckBody, cardsBody, errorBody.
```

What this task adds:

```ts
// decks/list/keyCards.ts (pure)
/** The `count` main-deck cards with the most copies, ties by higher costTotal, then by name. Resources and ids byId lacks are skipped. */
export function keyCards(main: readonly string[], byId: ReadonlyMap<string, Card>, count = 3): Card[];

// decks/list/useDeckDetails.ts
export type DetailState = { status: 'loading' } | { status: 'ready'; detail: DeckDetail } | { status: 'error' };
/** Each deck's DeckDetail, fetched once per id with getDeck, all at once. */
export function useDeckDetails(ids: readonly string[]): ReadonlyMap<string, DetailState>;

// decks/list/DeckTile.tsx: in place of DeckRow
export function DeckTile(props: {
  deck: DeckSummary; detail: DetailState | undefined; byId: ReadonlyMap<string, Card> | undefined;
  onDeleted: (id: string) => void;
}): JSX.Element;
```

## Deliverables

1. **Tiles.** Each section lists its decks as tiles in a grid, `<li>`s in a `<ul>`, three or four a row at 1024 px. A tile holds:
   - a link to `/decks/<id>` with the Leader's art (`CardArt` at 96), the deck's name and the Leader's name (its id while the card list lacks it)
   - "Main n/100 · Resources n/30"
   - the badge, "Legal" or "Not legal", from `DeckSummary.legal`
   - "Starter" on a starter, and the date, small and dimmed, as today
   - the key cards (`keyCards`), each its art at 32 and its name, in a list labeled "Key cards". A deck with fewer cards shows fewer.
   - the actions as today: Copy on a starter; on the player's own, Delete, then "Delete <name>?" with Yes and No
2. **The details.** `useDeckDetails` fetches each listed deck's detail once the list has arrived. While one loads, its tile shows the summary's parts and "Loading cards…" where the counts and key cards go. If it fails, the tile says "Couldn't load this deck's cards." there. The key cards also wait for the card list.
3. **Text.** Every string in `DecksPage.tsx` and the new files goes through `t()`, from `en/deckList.json`, the namespace this card owns. The English that exists today stays the same. A failed request still shows the API's message (`message(error)`).
4. **Tests.**
   - `keyCards.test.ts`: most copies first; a tie broken by higher cost, then by name; resources and unknown ids skipped; fewer than three cards.
   - `list.test.tsx`: a tile with its counts, badge and key cards from a stubbed detail; a tile whose detail fails still shows its name and badge; the tests that exist (the sections, the empty text, Delete with Yes and No, Copy, Retry) pass with each deck's detail stubbed.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test decks/list` passes, with the tests above
- [ ] `pnpm test:e2e` passes, with `e2e/m4.spec.ts` unchanged

## Out of scope

- Colors and stats on the tiles: the human said no.
- Changing `DeckSummary` or the deck routes. It's a shared contract in `packages/http` and `apps/api` (Notes).
- The deck editor (T-125) and the lobby's list of decks.

## Notes

- **A request per deck.** `DeckSummary` has no cards, and adding them changes the HTTP contract in `packages/http` and `apps/api`, which needs the lead (CLAUDE.md › Hard rules 7). A player has a handful of decks and the API is local, so one GET per deck is fine for now. If it isn't, ask lead for a card that adds the counts and key cards to `DeckSummary`.
- **The e2e.** `e2e/m4.spec.ts` isn't in this card's scope, and it must pass unchanged. It finds:
  - "No decks yet." on a new player's page
  - a link named `/Ember Aggro/` that opens the starter
  - `getByRole('listitem').filter({ hasText: '<deck name>' })` holding "Legal" or "Not legal"

  So a tile is an `<li>` that holds the badge's word, and the deck's name is in the tile's link and nowhere in the key cards' list items.
- The badge reads `DeckSummary.legal`, which is the API's checkDeck. The tile doesn't check the deck again, so it never disagrees with what the editor shows for the saved deck.
- Default: the key cards aren't links; the tile's link opens the deck.
- "Higher cost" is `costTotal(card.cost)`; names compare with `localeCompare`.
- Default: the date and the "Starter" mark stay, though the human's list doesn't name them, since nobody asked to remove them. Drop them if the lead says so.
- Default: no retry for a failed detail. Reloading the page fetches it again.
- Layout: a CSS grid, `repeat(auto-fill, minmax(220px, 1fr))`. Styles go inline or in `decks/list/list.css`; `theme.css` isn't in scope.
- Tests: stub `GET ${ROUTES.deck(id)}` for every deck a test lists. app.test.tsx lists no decks, so it makes no detail request.
