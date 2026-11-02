---
id: T-147
title: Card browser follow-ups
milestone: M5
depends_on: [T-134]
branch: agent/T-147-card-browser-follow-ups
model: sonnet
effort: low
scope:
  - apps/web/src/cards/browse.ts
  - apps/web/src/cards/browse.test.ts
  - apps/web/src/cards/CardFilters.tsx
  - apps/web/src/cards/browser.test.tsx
context:
  - docs/APPS.md#Web layout and ownership
---

# T-147 — Card browser follow-ups

## Goal

Two follow-ups from T-127's handoff, which the human picked on 2026-11-02:

- **Sort ties.** Descending reverses only a sort's own comparison, and ties stay in ascending order (`compareCards`, then the id). The cost sort is the exception: its own comparison is `compareCards` itself, cost then name, so descending reverses the names too. After this task cost sorts like the others: highest cost first, and the cards of one cost still A to Z.
- **More filters.** The section is `<details open={moreOpened || moreSet}>`, so once one of its filters is set it can't close. After this task it opens by itself when the page loads with one set, as today, and a click closes it like any other `details`. The chips still show what's set.

## Interfaces

What exists (copied from the code on 2026-11-02). T-134 edits this folder first, so re-read the files before you start:

```ts
// apps/web/src/cards/filter.ts:51
/** The one card order: costTotal(card.cost), then name. */
export function compareCards(a: Card, b: Card): number;

// apps/web/src/cards/browse.ts
function primary(sort: SortKey, a: Card, b: Card): number; // :47: case 'cost': return compareCards(a, b);
function tieBreak(a: Card, b: Card): number; // :64: compareCards, then the id
export function sortCards(cards: readonly Card[], sort: SortKey, descending: boolean): Card[]; // :72
//   direction * primary(sort, a, b) || tieBreak(a, b)

// apps/web/src/cards/CardFilters.tsx
function hasMoreFilters(filter: CardFilter): boolean; // :88
const [moreOpened, setMoreOpened] = useState(false); // :106
const moreSet = hasMoreFilters(value); // :107
<details open={moreOpened || moreSet} onToggle={(e) => setMoreOpened(e.currentTarget.open)}> // :151

// apps/web/src/cards/browse.test.ts:50-53, "sorts by cost, up and down"
expect(ids(sortCards(fixtures, 'cost', true))).toEqual(['d', 'c', 'a', 'f', 'b', 'e']);
// apps/web/src/cards/browser.test.tsx:120-129, "keeps the extra filters closed when none is set" and
//   "opens the extra filters when the URL sets one"
```

## Deliverables

1. **Cost sort.** `primary`'s `cost` case compares `costTotal` only, so `tieBreak` orders cards of one cost. Update the descending expectation in "sorts by cost, up and down" where two fixtures share a cost, and add a case: two cards of one cost stay A to Z when descending.
2. **More filters.** The open state starts as `hasMoreFilters(value)` at the first render (`useState(() => …)`) and then follows only the toggle: `open={moreOpened}`.
3. **Tests** in `browser.test.tsx`: opened from the URL, a click on "More filters" closes it while the filter stays set (its checkbox stays checked, and the list doesn't change).

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test browse browser` passes, and the two existing More filters tests pass unchanged.

## Out of scope

- The other sorts, the groups and the views.
- What "More filters" holds, and its text.

## Notes

- Default: a filter set while the section is closed doesn't open it. The chips show it.
- This card waits for T-134, whose scope has the `cards` folder.
