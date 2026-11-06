---
id: T-187
title: Deck editor pinned filters, thin deck column, no Chaos
milestone: M5
depends_on: []
branch: agent/T-187-deck-editor-pinned-filters-thin-deck-col
model: sonnet
effort: medium
scope:
  - apps/web/src/decks/editor/**
  - apps/web/src/i18n/en/deckEditor.json
context:
  - apps/web/README.md#Rules a change must keep
  - docs/APPS.md#Web layout and ownership
  - docs/RULES.md#Components and setup
---

# T-187 — Deck editor pinned filters, thin deck column, no Chaos

## Goal

The human's playtest (2026-11-05) asked for four things in the deck editor. The filters stay pinned on top while the card list scrolls. The current deck becomes a thinner column, fixed at the side, that scrolls on its own. Each deck row shows the card's mana cost in a column of its own. Chaos cards, which no deck can hold, leave the editor.

## Interfaces

What exists (copied on 2026-11-05):

```tsx
// apps/web/src/decks/editor/DeckEditorPage.tsx
// :197 const canSave = nameResult.success && descriptionResult.success && dirty && !busy;   (legality isn't required)
// :258 <div inert={blocked} style={{ display: 'flex', gap: 16, alignItems: 'flex-start' }}>
// :259   <section aria-label="Card browser" style={{ flex: 3, minWidth: 0 }}>
// :260     <Panel><CardFilters value={filter} onChange={…} /> <label><input type="checkbox" …/> Fits the Leader</label>
//            <ViewSwitch value={poolView} views={POOL_VIEWS} onChange={…} /></Panel>
// :271     <p aria-live="polite">{shown.length} of {cards.cards.length}</p>
// :274     list view: <CardList cards={shown} …/>; tile view: CardTile with `disabled={deckable ? undefined : 'Not deckable'}`
// :300   <aside aria-label="Focused card" className="cg-deck-focus"> (apps/web/src/cards/cards.css:95: sticky, 224 px wide)
// :309   <section aria-label="Deck" style={{ flex: 2, minWidth: 0 }}> … LeaderSection, PileSection (main, resources), Save
// apps/web/src/decks/editor/deck.ts:23 pileFor(card): 'leader' | 'main' | 'resources' | null — null for Chaos
// apps/web/src/decks/editor/DeckPanel.tsx:99 PileSection: :122-:134 one row per card: name … <span>×{count}</span>
// apps/web/src/cards/CardFilters.tsx:99 CardFilters(props: { value; onChange; types?: readonly CardType[] }) — :105 types ?? CARD_TYPES
// apps/web/src/cards (index): export function CostPips({ cost, label }) (CardFace.tsx:40) — the pips the faces draw
```

## Deliverables

1. **Pinned filters.** The browser's filter panel and its count line stay pinned at the top of the browser column while its list scrolls (`position: sticky`), with the panel's background so cards don't show through.
2. **A thin deck column.** The Deck section becomes a fixed-width column (about 18 rem, not `flex: 2`), pinned at the side and scrolling on its own (`max-height` from the viewport, `overflow-y: auto`), so the browser gets the room. The focused card's aside keeps its place.
3. **A cost column.** Each deck row shows the card's cost with `CostPips`, in a column of its own between the name and `×count`, aligned across rows. Resources have no cost, so their cell stays empty.
4. **No Chaos cards.** The editor lists only cards a deck can hold (`pileFor(card) !== null`): the count says "N of M" over those, and `CardFilters` gets `types` without `chaos`. "Not deckable" never shows.
5. **Styles** go in a new `apps/web/src/decks/editor/editor.css`, imported by the page, not in `cards.css` (T-186's this wave) or the theme.
6. **Tests** in `editor.test.tsx`:
   - no Chaos card in the list, and no Chaos type filter;
   - the count leaves Chaos cards out;
   - a deck row shows the card's cost pips, and a resource row none;
   - the pinned classes are on the filter panel and the deck column.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test editor deck problems matchCard` passes.
- [ ] `pnpm test` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- `apps/web/src/cards/**`: T-186 edits the cards page beside you. Use `CardFilters`' existing `types` prop and the exported `CostPips` as they are.
- The deck list and the lobby.
- Saving an unfinished deck: it works already (see Notes).

## Notes

- The human also asked to save unfinished decks with an "incomplete" flag. That works already: `canSave` doesn't ask for a legal deck, the deck list's tile flags an illegal deck (`deckList.tile.legal`), and the lobby won't start a match with one. Confirm it with a grep and say so in the PR; nothing to build.
- Keep the editor usable at narrow widths: below about 900 px the deck column can drop under the browser, unpinned.
- jsdom doesn't lay out or scroll: test classes and structure.
