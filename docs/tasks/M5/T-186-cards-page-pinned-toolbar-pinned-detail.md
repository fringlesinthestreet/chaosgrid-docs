---
id: T-186
title: Cards page pinned toolbar, pinned detail and Overall stats
milestone: M5
depends_on: []
branch: agent/T-186-cards-page-pinned-toolbar-pinned-detail
model: sonnet
effort: medium
scope:
  - apps/web/src/cards/CardsPage.tsx
  - apps/web/src/cards/BotGames.tsx
  - apps/web/src/cards/cards.css
  - apps/web/src/cards/*.test.ts
  - apps/web/src/cards/*.test.tsx
  - apps/web/src/i18n/en/cards.json
context:
  - apps/web/README.md#Rules a change must keep
  - docs/APPS.md#Web layout and ownership
---

# T-186 — Cards page pinned toolbar, pinned detail and Overall stats

## Goal

The human's playtest (2026-11-05) asked for three things on the cards page. The filters, the sort and the view options stay in sight while the list scrolls. The selected card's detail stays in sight too, so a click on a card far down the list shows it at once, as in the deck editor. "Bot games" becomes "Overall stats".

## Interfaces

What exists (copied on 2026-11-05):

```tsx
// apps/web/src/cards/CardsPage.tsx:143-:192
<div className="cg-cards-page">
  <h1>{t('cards.page.title')}</h1>
  {cards && (
    <div style={{ display: 'flex', gap: 16, alignItems: 'flex-start' }}>
      <Panel><CardFilters value={filter} onChange={…} /></Panel>             {/* left */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <BrowseControls value={browse} onChange={…} />                        {/* :46 <div className="cg-browse-controls">: sort, group, ViewSwitch */}
        <FilterChips value={filter} onChange={…} />
        <p aria-live="polite">{t('cards.page.count', { shown, total })}</p>
        {groups.map(…)}                                                       {/* <section><h2>…</h2> tiles, list or table */}
      </div>
      <Panel>{selected ? (<><CardFace card={selected} size="medium" /><BotGames stats={stats[selected.id]} /></>)
             : <p className="cg-dimmed">{t('cards.page.pick')}</p>}</Panel>  {/* right */}
    </div>
  )}
</div>
// apps/web/src/cards/cards.css:30 .cg-browse-controls; :95 the deck editor's pinned detail:
.cg-deck-focus { position: sticky; top: 16px; flex: none; width: calc(192px + 32px); }
// apps/web/src/i18n/en/cards.json:8 "bot.title": "Bot games"; :9 "bot.note": "From simulated games between bots, not players."
// apps/web/src/cards/botGames.test.tsx:24 and :83 look for 'Bot games'
```

## Deliverables

1. **A pinned toolbar.** The browse controls, the filter chips and the count form one toolbar at the top of the list column (`<div role="toolbar">` isn't right for mixed controls: use a labelled `<section aria-label="Sort and view">` or similar) that stays pinned while the page scrolls (`position: sticky`, below the app's header if that is sticky too, with the page's background so cards don't show through). The filters panel on the left is pinned the same way and scrolls on its own when it's taller than the screen (`max-height` from the viewport, `overflow-y: auto`).
2. **A pinned detail.** The right panel is an `<aside aria-label="Selected card">`, pinned like `.cg-deck-focus`, so the selected card shows wherever the list is scrolled. A click on a card far down the list fills it without scrolling the page.
3. **Overall stats.** `cards.bot.title` reads "Overall stats". The note keeps saying the numbers come from games between bots.
4. **Keyboard focus stays visible.** A card the player tabs to never ends up under the pinned toolbar: give the scrolling page a `scroll-padding-top` of the toolbar's height.
5. **Tests.** The toolbar and the aside exist with their labels and pinned classes. Selecting a card fills the aside. The stats heading reads "Overall stats". jsdom can't scroll, so test structure and classes, not positions.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test cards botGames browser` passes.
- [ ] `pnpm test` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- `CardFace.tsx`, `CardTable.tsx` and `filter.ts`: T-189 takes their Durability out next wave, and T-192 adds live stats to the face.
- The deck editor: T-187, beside you. Its `.cg-deck-focus` rule stays in `cards.css`, unchanged.
- A horizontal filter bar: the filters keep their panel, pinned.

## Notes

- Lead default: "on top" reads as "always in sight". The filters stay a left column and the sort and view options sit above the list. If one top bar for everything fits better, say so in the PR rather than redesigning `CardFilters`, which the deck editor shares.
- Keep the mobile width in mind: below about 900 px the three columns may stack; the pinned toolbar then stays on top, and the detail comes after the list.
