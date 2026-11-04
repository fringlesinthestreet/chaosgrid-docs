---
id: T-159
title: Card list views and side panel
milestone: M5
depends_on: [T-152]
branch: agent/T-159-card-list-views-and-side-panel
model: sonnet
effort: medium
scope:
  - apps/web/src/cards/CardsPage.tsx
  - apps/web/src/cards/CardList.tsx
  - apps/web/src/cards/CardTile.tsx
  - apps/web/src/cards/ViewSwitch.tsx
  - apps/web/src/cards/browse.ts
  - apps/web/src/cards/browse.test.ts
  - apps/web/src/cards/browser.test.tsx
  - apps/web/src/cards/cards.test.tsx
  - apps/web/src/cards/cards.css
  - apps/web/src/cards/index.tsx
  - apps/web/src/decks/editor/DeckEditorPage.tsx
  - apps/web/src/decks/editor/editor.test.tsx
  - apps/web/src/i18n/en/cards.json
  - apps/web/src/i18n/en/deckEditor.json
context:
  - apps/web/README.md#Text
  - apps/web/README.md#Tests
---

# T-159 — Card list views and side panel

## Goal

Two requests from the human's playtest (2026-11-04):

- "On deck edit view, when User clicks a card, the focused card should be on the side and not down." Today the editor shows the card picked in the deck panel under the deck panel, at the bottom of the right column, often below the fold.
- "On card lists (search cards, deck edits) it should give 2 options for viewing: list (plain list without icon showing mana cost) OR preview using card design small (with fixed size each so it looks more tidy)."

After this task the card browser and the deck editor's card pool both offer Preview, a grid of small card faces all the same size, and List, one plain row per card with its cost as pips. The editor shows the focused card in a column of its own beside the pool, as the card browser does, and it stays in view while the page scrolls.

## Interfaces

What exists (copied on 2026-11-04, and from the T-152 card):

```ts
// apps/web/src/cards/browse.ts
export const VIEWS = ['images', 'list', 'table'] as const;
export interface BrowseOptions { sort: SortKey; descending: boolean; group: GroupKey; view: View }
export const DEFAULT_BROWSE: BrowseOptions = { sort: 'cost', descending: false, group: 'none', view: 'images' };
// browseFromQuery / browseToQuery: `view=list`; a value it doesn't know falls back to the default.

// apps/web/src/cards/CardsPage.tsx: BrowseControls (a fieldset of radios, `cards.browse.view.<view>`),
// and CardView, which switches on the view: 'images' → <div className="cg-card-tiles">{CardTile…}</div>,
// 'list' → <CardList cards onSelect />, 'table' → <CardTable cards onSelect />. The page is three
// columns: the filters, the views, and a Panel with the selected card and its bot stats.

// apps/web/src/cards/CardList.tsx: <ul className="cg-card-list"> of <li>: a name <button> (onSelect),
// the cost as text, the type, the text. cards.css lays a row out as a grid of 14rem 5rem 8rem 1fr.

// apps/web/src/decks/editor/DeckEditorPage.tsx:245-371: two columns. "Card browser" (flex 3): the
// filters, "{shown} of {total}", and a wrapping row of CardTile with count, disabled ('Not deckable')
// and onClick = add a copy (none when the deck is read-only). "Deck" (flex 2): the deck panel, whose
// Leader and pile entries call select(card), then the selected card's face under it.

// T-152: CardTile is the small face (112 px wide) with the count badge and the disabled reason, and a
// button over the face when it's clickable. cards/ exports CardFace, CostPips({ cost }) and FaceSize.
```

`browser.test.tsx` checks the "Images" radio and `?view=list`; `browse.test.ts` checks the query; `editor.test.tsx` › `tile()` finds a pool tile by its button's name.

## Deliverables

1. **The views.** `VIEWS` becomes `['preview', 'list', 'table']`, with "Preview" as the default. `browseFromQuery` reads the old `view=images` as `preview`, so old links still work.
2. **Preview:** the small faces in a grid of equal cells, `repeat(auto-fill, <the small face's width>)`, every cell the same height. The count badge and the disabled reason sit over the face (a corner badge, a strip along the bottom), so no cell grows.
3. **List:** one row per card: the name (the button, as now), its cost as `CostPips`, and its type. No art.
4. **`ViewSwitch`**, the radios `BrowseControls` has for the view, as a component of its own that both pages use: `{ value, views, onChange }`. The card browser offers Preview, List and Table; the editor offers Preview and List.
5. **The editor's pool** has the switch, Preview by default. A click on a card adds a copy in both views, as a tile does today, and a read-only deck's pool adds nothing. Its view is in the URL as the browser's is (`view=list`), and keeps the editor's other parameters.
6. **The editor's focused card** moves out of the right column into a column between the pool and the deck panel. It holds the medium face, or the hint "Pick a card in your deck to see it here." when nothing is picked. The column is sticky (`position: sticky; top: …`), so the face stays in view while the pool or the deck scrolls. At 1024 px the three columns fit with no sideways scroll.
7. **Text:** `cards.browse.view.preview` "Preview" in place of `images`; the editor's hint in `en/deckEditor.json`.
8. **Tests:**
   - `browse.test.ts`: `view=images` reads as `preview`; the default writes no `view`.
   - `browser.test.tsx`: Preview is checked by default; List shows a row per card with the cost's accessible text and no `[data-art]`.
   - `editor.test.tsx`: the pool's switch shows List rows, and a click on one adds a copy; picking a card in the deck panel shows its face in the focus column, which comes before the deck panel in the DOM; the column's hint shows before any pick.
   - `cards.test.tsx`: two small faces with different names and types render the same height in a Preview grid. jsdom has no layout, so assert the cell's fixed size in its style or class.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test cards browse browser editor` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `pnpm test:e2e` passes with `e2e/m4.spec.ts` unchanged: its editor step finds the "Card browser" region and clicks a card's button by name, which Preview, the default, keeps.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Focusing a pool card without adding it: today a pool click adds, and that stays. Say in the PR if the new layout makes a focus click worth a card.
- The deck panel's own list (names, counts, + and −) and the deck list page's tiles.
- Removing the card browser's Table view: the human asked for two options, and the lead kept Table on the browser because it's the only view that compares stats. The human can drop it later.

## Notes

- Defaults: the browser keeps its filters column. The editor's focus column is the medium face's width plus the panel's padding.
- The PR says which keys it added or renamed in `en/cards.json` and `en/deckEditor.json`.
