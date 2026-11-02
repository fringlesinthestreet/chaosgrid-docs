---
id: T-125
title: Deck problems and quick add
milestone: M5
depends_on: [T-124]
branch: agent/T-125-deck-problems
model: sonnet
effort: medium
scope:
  - apps/web/src/decks/editor/**
  - apps/web/src/i18n/en/deckEditor.json
context:
  - packages/cards/README.md#Deck rules
  - apps/web/README.md#Text
  - apps/web/README.md#Tests
---

# T-125 — Deck problems and quick add

## Goal

The human's wishes for the deck editor after playing M4 (2026-10-29):

- **A validation chip** by the deck name. It reads "Legal · 100/100 · 30/30" when the deck is legal and "Problems (N)" when it isn't. It opens a list where each problem says what's wrong and how to fix it, with a one-click fix wherever only one fix makes sense.
- **Quick add:** a labeled text field. "3 Cinder Grunt" adds three copies, "Cinder Grunt" one. The name matches loosely, and the copy limits hold.

The human ruled out curve, color and type stats, import and export, a maybe zone and sample hands. None of those go in.

## Interfaces

What exists (copied from the code on 2026-10-29). T-110 to T-118 don't touch `decks/`:

```ts
// @chaosgrid/cards (src/deck/check.ts, src/colors.ts; COLORS and Color from src/cost.ts)
export interface Deck { leader: string; main: readonly string[]; resources: readonly string[] }
export type DeckPile = 'leader' | 'main' | 'resources';
export interface DeckProblem { code: DeckProblemCode; pile: DeckPile; cards: string[]; message: string }
// DeckProblemCode: 'mainDeckSize' | 'resourceDeckSize' | 'tooManyCopies' | 'wrongType' | 'leaderInMain'
//   | 'unknownCard' | 'retiredCard' | 'offColor'. `cards` holds each id once: one id for a card's
//   problem, none for a deck size. `message` is English for the API and logs; the web words a
//   problem itself (D50).
export function checkDeck(deck: Deck, cards: DeckCatalog, options?: { retired?: Iterable<string> }): DeckProblem[];
export const MAIN_DECK_SIZE = 100, RESOURCE_DECK_SIZE = 30, MAX_COPIES = 4;
export function maxCopies(card: Card): number;           // 1 for a Unique card and every Leader
export function usageColors(card: Card): Color[];        // in COLORS order
export function colorAllowance(leader: Card): Color[];
export function offColors(card: Card, leader: Card): Color[];
export const COLORS = ['R', 'T', 'E', 'D', 'L'] as const; // Ember, Tide, Earth, Dark, Light

// decks/editor/deck.ts (pure)
export const EMPTY_DECK: Deck;
export function pileFor(card: Card): DeckPile | null;    // null for Chaos
export function addCard(deck: Deck, card: Card): Deck;   // one copy; a Leader replaces the Leader
export function removeCard(deck: Deck, pile: DeckPile, id: string): Deck; // one copy, the last
export function pileRows(ids: readonly string[], byId: ReadonlyMap<string, Card>): PileRow[];

// decks/editor/DeckEditorPage.tsx: Editor({ deckId, cards }) (:80-382)
//   readOnly = saved.starter (:146); leader, leaderCard (:147-148)
//   local = checkDeck(deck, cards.byId, { retired: cards.retired }) (:150-153)
//   problems = dirty || !saved.problems ? local : saved.problems (:155); marked (:156) flags rows
//   edit(change: Partial<Draft>) (:173-177): every deck change goes through it
//   section "Card browser" (:244): CardFilters, "Fits the Leader", CardTile per card
//   section "Deck" (:274): Copy on a starter (:276-283), the Name field (:284-294), Description
//   (:298-307), LeaderSection, PileSection "Main deck" and "Resource deck", <Problems problems={problems} />
//   (:343), Save and "Unsaved changes" (:344-351)
//   messageOf(error) (:64-66): a failed save shows the API's message
// decks/editor/DeckPanel.tsx: ColorPips (:21), LeaderSection (:44), ProblemMark (:77, img "Has a
//   problem"), PileSection (:85; its h3 says "n / size"), PILE_TITLES (:145), Problems (:151-181:
//   section "Problems" with "Legal", or each problem's message under an h4 per pile)

// ../../cards (T-127 changes it in this wave; use its exports as they are)
// CardsState 'ready' = { status: 'ready'; cards: Card[]; byId: Map<string, Card>; retired: string[] }
// ../../i18n (T-124): t(id, values?), locale()

// Tests. editor.test.tsx: renderEditor(path) (:44), browser() and deckPanel() (:58-63), tile(card)
//   (:64), the `small` card list (:20-26: leader, fitting, offColor, chaos, resource).
//   deck.test.ts tests deck.ts. test/fixtures/api.ts: stubApi, cardsBody, deckBody, errorBody.
```

What this task adds:

```ts
// decks/editor/problems.ts (pure)
export type DeckFix =
  | { kind: 'remove'; pile: DeckPile; id: string; copies: number } // copies to take out of the pile
  | { kind: 'move'; id: string; from: 'main' | 'resources'; to: 'main' | 'resources' }; // every copy
/** The one-click fix for `problem`, or null when the fix is the player's choice. */
export function fixFor(problem: DeckProblem, deck: Deck, byId: ReadonlyMap<string, Card>): DeckFix | null;
export function applyFix(deck: Deck, fix: DeckFix): Deck;

// decks/editor/quickAdd.ts (pure)
/** "3 Name", "3x Name", or "Name" for one copy. Null for a blank line or a count of 0. */
export function parseQuickAdd(text: string): { count: number; query: string } | null;
export type CardMatch = { kind: 'one'; card: Card } | { kind: 'many'; cards: Card[] } | { kind: 'none' };
/** The best match for `query` among `cards`, whatever the case and punctuation (Notes › Matching). */
export function matchCard(query: string, cards: readonly Card[]): CardMatch;

// decks/editor/deck.ts
/** Up to `count` copies of `card`: within maxCopies in the main deck, any number of resources; a Leader replaces the Leader. */
export function addCopies(deck: Deck, card: Card, count: number): { deck: Deck; added: number };

// decks/editor/DeckPanel.tsx: in place of Problems
export function ProblemChip(props: {
  problems: readonly DeckProblem[]; deck: Deck; byId: ReadonlyMap<string, Card>;
  readOnly: boolean; onFix: (fix: DeckFix) => void;
}): JSX.Element;
// decks/editor/QuickAdd.tsx
export function QuickAdd(props: { cards: readonly Card[]; deck: Deck; onChange: (deck: Deck) => void }): JSX.Element;
```

## Deliverables

1. **The chip.** `ProblemChip` is a `section` labeled "Problems", next to the Name field. It replaces the Problems section at the bottom of the panel.
   - Legal: plain text "Legal · 100/100 · 30/30", since there's nothing to open.
   - Not legal: a button "Problems (N)" with `aria-expanded`, which opens and closes the list under it. The list stays open across edits and closes when the deck becomes legal.
   - The rows keep their "Has a problem" marks.
2. **The list.** One item per problem, in checkDeck's order. Each says what's wrong and how to fix it, in words from `deckEditor.json`. It names the card where there is one, or gives the id when the card list doesn't have it. The fixes (`fixFor`):

   | `code` | It says | One-click fix |
   | --- | --- | --- |
   | `mainDeckSize`, `resourceDeckSize` | how many cards the pile has and takes; add or remove the difference | none |
   | `tooManyCopies` | the copies and the limit (1 for a Unique card) | remove the extra copies |
   | `wrongType` | what the card is, and what the pile takes | move every copy to the pile its type goes in (a resource to the resource deck, a main-deck type to the main deck); otherwise remove them, or clear the Leader slot |
   | `leaderInMain` | the Leader starts in the command zone | remove its copies from the main deck |
   | `unknownCard`, `retiredCard` | there's no such card, or it's retired | remove every copy, or clear the Leader slot |
   | `offColor` | the card's colors outside the Leader's, by name | none: remove the card or pick another Leader |

   A fix button says what it does ("Remove 1 copy", "Move to the resource deck") and goes through `edit()` like any change. A starter (read-only) shows the list without fixes.
3. **Quick add.** A text field labeled "Quick add", above the Leader section, with an Add button. The hint "3 Cinder Grunt, or a name for one copy" is linked with `aria-describedby`. It's hidden on a read-only starter. It checks on Add or Enter, never while typing.
   - `matchCard` searches the deckable cards (`pileFor(card) !== null`), whatever the browser's filters and "Fits the Leader" say.
   - One match: `addCopies`, the field clears, and a status line (`role="status"`) says what was added. At the copy limit it adds what fits and says so, for example "Added 1 copy of Cinder Grunt: the deck holds at most 4". A Leader replaces the Leader, whatever the count.
   - Several matches: the text stays, and the field lists the candidates as buttons, up to 8 by name, then "and N more". A click adds the count to that card.
   - No match, a count of 0, or a card already at its limit: an error under the field (`ErrorText`) says which, and the text stays.
4. **Text.** Every string this task adds goes through `t()`, from `en/deckEditor.json`, the namespace this card owns. Counts use ICU plurals. The color names for `offColor` are there too ("Ember", "Tide", "Earth", "Dark", "Light", as checkDeck names them), joined with `new Intl.ListFormat(locale())`. The editor's other text stays where it is.
5. **Tests.**
   - `problems.test.ts`: `fixFor` for each code (null for the sizes and `offColor`), and `applyFix` for a remove, a cleared Leader and a move.
   - `quickAdd.test.ts`: `parseQuickAdd` on "3 Name", "3x Name", "Name", a name that starts with a digit ("7th Legion"), a blank line and "0 Name". `matchCard` for each tier, with case and punctuation ignored, an ambiguous query and no match.
   - `deck.test.ts`: `addCopies` at the limit (4, a Unique card's 1), a Leader replacing the Leader, and resources with no limit.
   - `editor.test.tsx`: the chip, legal and not; opening the list; a fix that clears its problem; quick add of "2 <name>", the candidate list and a pick from it, the no-match error; no quick add on a starter. Update the tests that found the old section's text (`/the main deck has 2 cards/`, `/outside the Leader's colors/`, `'Legal'`).

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test decks/editor` passes, with the tests above
- [ ] `pnpm test:e2e` passes, with `e2e/m4.spec.ts` unchanged

## Out of scope

- Stats, import and export, a maybe zone, sample hands: the human said no.
- The card browser's filters, sorting and views (T-127, which owns `cards/` in this wave).
- Moving the editor's other text into `deckEditor.json`: a later card (PLAN.md › M5).
- Wording a failed save by the API error's code: `messageOf` keeps the API's message.

## Notes

- **The e2e.** `e2e/m4.spec.ts` isn't in this card's scope (T-113 owns it in this wave, then the later playtest cards), and it must pass unchanged. It finds:
  - the region "Problems", holding "Legal" for a legal deck, with no line that's only "Legal" otherwise. That's why the legal chip says "Legal · …", not just the counts.
  - the region "Main deck" with "99 / 100", and the button "Remove one Cinder Grunt"
  - the textbox "Name", "Unsaved changes", "Saved." and "A starter deck: read-only."
  - the card browser's searchbox "Search", the checkbox "Fits the Leader" and the tile buttons
- **Names.** Playwright matches an accessible name by substring, so no new control's name may contain "Name": `getByRole('textbox', { name: 'Name' })` would find two. "Quick add" is safe, and the hint is a description, not part of the name.
- **Alerts.** The list's items aren't alerts. The editor tests call `getByRole('alert')` and expect exactly one.
- **Matching.** `matchCard` normalizes both sides: NFKD, no diacritics, lowercase, each run of anything but letters and digits as one space, trimmed. The first tier with any match wins:
  1. the whole name
  2. the name starts with the query
  3. every query word starts a word of the name, in any order ("pyre vask")
  4. the name contains the query
  5. for a query of 4 or more characters, a name within 2 edits (Levenshtein)

  One card in the winning tier is the match. More are candidates, even when they share a name.
- **Counts.** `parseQuickAdd` reads a count only when digits are followed by a space or an "x" and a space, so "7th Legion" is one copy of 7th Legion. Quick add ignores the deck sizes, like clicking a tile: a 101st card is a problem the chip shows, not an error.
- `tooManyCopies` on a card the list doesn't have takes `MAX_COPIES` as its limit, as checkDeck does.
- After a fix the deck is dirty, so `problems` is the local checkDeck's (DeckEditorPage.tsx:155) and the fixed problem goes at once.
- **T-127 runs beside this card** and owns `apps/web/src/cards/**`. Use `CardFilters`, `CardTile`, `CardDetail`, `filterCards`, `filterFromQuery`, `filterToQuery` and `useCards` as they are. T-127 adds filters to `CardFilters`, and they'll show in the editor's browser too. Tests here find nothing inside `CardFilters` but the searchbox "Search".
- Styles: inline, as the folder does today, or a CSS file in `decks/editor/`. `theme.css` isn't in scope.
