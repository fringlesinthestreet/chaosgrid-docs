---
id: T-176
title: Pool cards preview on hover and focus
milestone: M5
depends_on: [T-169]
branch: agent/T-176-pool-cards-preview-on-hover-and-focus
model: sonnet
effort: low
scope:
  - apps/web/src/cards/CardTile.tsx
  - apps/web/src/cards/CardList.tsx
  - apps/web/src/decks/editor/DeckEditorPage.tsx
  - apps/web/src/decks/editor/editor.test.tsx
  - apps/web/src/i18n/en/deckEditor.json
context:
  - apps/web/README.md#Text (D50)
  - apps/web/README.md#Tests
---

# T-176 — Pool cards preview on hover and focus

## Goal

The deck editor's side panel ("Focused card", T-159) shows only cards picked in the deck panel. A click on a pool card adds a copy and doesn't show it, so a player can't read a pool card there before adding it. On 2026-11-04 the human picked this behavior: pointing at a pool card, or tabbing to it, shows it in the side panel, and a click still adds a copy.

## Interfaces

What exists (copied on 2026-11-04, and from the T-169 card):

```tsx
// apps/web/src/decks/editor/DeckEditorPage.tsx:252
const select = (card: Card) => setSelected(card); // the deck panel's onSelect; the side panel shows `selected`
const add = (card: Card) => edit({ deck: addCard(deck, card) });
// the pool, list view:  <CardList cards={shown} onSelect={readOnly ? () => undefined : add} />
// the pool, tile view:  <CardTile card={card} count={count} disabled={...} onClick={readOnly ? undefined : () => add(card)} />
// :295 <aside aria-label="Focused card">: <CardFace card={selected} size="medium" />, else t('deckEditor.focus.hint')

// apps/web/src/cards/CardTile.tsx: CardTile({ card, count?, onClick?, disabled?, cost? (T-169) }); it
// draws a <button className="cg-tile-button"> only when it has onClick and isn't disabled.
// apps/web/src/cards/CardList.tsx: CardList({ cards, onSelect }), one <button> per card.
// en/deckEditor.json: "focus.hint": "Pick a card in your deck to see it here."
```

## Deliverables

1. **`CardTile` and `CardList` take an optional `onPreview`**, called when the pointer enters a card and when its button gets the keyboard focus.
2. **The pool previews.** The editor passes `select` as the pool's `onPreview` in both views, read-only too, since a preview changes nothing. A click still adds a copy. The side panel keeps the last card shown after the pointer leaves the pool.
3. **The hint** says both ways in: point at a pool card or tab to it, or pick one in your deck.
4. **Tests in `editor.test.tsx`:**
   - pointing at a pool tile shows it in the side panel and adds nothing;
   - tabbing to a pool tile shows it;
   - a click still adds one copy;
   - in the list view, pointing and tabbing show the card too;
   - a read-only deck's pool previews on pointing.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test editor` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Touch screens, which have no hover: a tap still adds.
- The card browser page and the deck panel, which keep their clicks.

## Notes

- Defaults:
  - The pointer previews a card once it has rested on it for 100 ms, so sweeping across the pool doesn't flicker the panel. Focus previews at once.
  - A tile with no button (read-only, or not deckable) previews on pointing only.
