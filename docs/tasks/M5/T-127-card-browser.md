---
id: T-127
title: Card browser sorting, groups and views
milestone: M5
depends_on: [T-124]
branch: agent/T-127-card-browser
model: sonnet
effort: high
scope:
  - apps/web/src/cards/*.ts
  - apps/web/src/cards/index.tsx
  - apps/web/src/cards/CardFilters.tsx
  - apps/web/src/cards/CardsPage.tsx
  - apps/web/src/cards/CardList.tsx
  - apps/web/src/cards/CardTable.tsx
  - apps/web/src/cards/FilterChips.tsx
  - apps/web/src/cards/browser.test.tsx
  - apps/web/src/cards/cards.css
  - apps/web/src/i18n/en/cards.json
context:
  - apps/web/README.md#Text
  - apps/web/README.md#Tests
---

# T-127 — Card browser sorting, groups and views

## Goal

The card browser (`/cards`) gets what the human asked for after playing M4 (2026-10-29):

- **Sorting** by name, cost, type, color, and for units attack, HP and speed, up or down.
- **Groups** by type, cost or color, with counts in the group headers.
- **Three views:** the images of today, a text list, and a table with stat columns.
- **More filters:** keywords, range, squad, Chaos tier and spell class.
- **Chips** for the active filters, each one removable.

All of it lives in the URL, as the filters already do, so a link or a reload shows the same page.

## Interfaces

What exists (copied from the code on 2026-10-29). T-115 changes `CardDetail.tsx` and `cards.test.tsx` in wave 16; nothing else in M4 touches `cards/`:

```ts
// cards/filter.ts: every export stays as it is. The deck editor and T-125 use them.
export interface CardFilter {
  text: string; types: CardType[]; colors: Color[]; colorless: boolean;
  cost: { min?: number; max?: number };
}                                                                         // :11-22
export const EMPTY_FILTER: CardFilter;                                    // :24
/** The one card order: costTotal(card.cost), then name. */
export function compareCards(a: Card, b: Card): number;                   // :33
export function filterCards(cards: readonly Card[], filter: CardFilter): Card[]; // :54, sorted by compareCards
export function filterToQuery(filter: CardFilter): URLSearchParams;       // :60: q, type, color,
//   colorless=1, cost=2-4 or cost=3; only what differs from EMPTY_FILTER
export function filterFromQuery(query: URLSearchParams): CardFilter;      // :85: a bad part gives
//   EMPTY_FILTER's value for that field

// cards/CardFilters.tsx:12-93
export function CardFilters(props: { value: CardFilter; onChange: (next: CardFilter) => void; types?: readonly CardType[] });
//   form[role=search]: label "Search" (input type=search); fieldsets "Type" (a checkbox per type id,
//   "unit"), "Color" (a checkbox per letter, "R", then "colorless") and "Cost" (Min, Max).
// cards/CardsPage.tsx:11-54: h1 "Cards"; "Loading cards…"; on error a Panel with
//   state.error.message and Retry; then three columns: a Panel with CardFilters; the count
//   <p aria-live="polite">{shown.length} of {cards.length}</p> over a wrap of CardTile buttons; a Panel
//   with the clicked card's CardDetail, or "Pick a card.". Filters write the URL with
//   setParams(filterToQuery(next), { replace: true }).
// cards/CardTile.tsx: CardTile({ card, count?, onClick?, disabled? }): a button with CardArt at 48,
//   the name, the cost and the type. The deck editor and T-115's tray use it: leave it as it is.
// cards/index.tsx: getCards, resetCardsCache, useCards, CardsState, CardDetail, CardFilters,
//   CardsPage, CardTile, compareCards, EMPTY_FILTER, filterCards, filterFromQuery, filterToQuery, CardFilter.

// @chaosgrid/cards, the fields the browser reads:
//   every card: id, name, type (CARD_TYPES: unit, leader, spell, trap, artifact, enchantment,
//   resource, chaos), cost (costTotal(cost)), text; cardColor(card): Color[] in COLORS order (R, T, E, D, L)
//   unit, leader: stats { hp, attack, attackSpeed, speed, range, charge }, squad (units per card),
//   keywords; unit: durability
//   chaos: tier (1 | 2 | 3) and kind; kind 'units' also has stats, squad and keywords
//   spell: spell (SPELL_CLASSES: utility, defensive, offensive)
//   KEYWORDS: blocker, trample, reach, flying, static, ignoresBlockers, seeksEmblems, consumed,
//   shield, extraLife, ward. RANGES: melee, ranged, artillery. Types Keyword, Range, SpellClass.
// ../i18n (T-124): t(id, values?).
```

What this task adds:

```ts
// cards/filter.ts: new optional fields. Absent means any card.
export interface CardFilter {
  // …the five fields above, unchanged
  keywords?: Keyword[];        // has every one; query kw=flying,reach
  ranges?: Range[];            // stats.range is one of them; query range=melee,ranged
  squad?: { min?: number; max?: number }; // on squad; query squad=2-4 or squad=3, as cost
  tiers?: (1 | 2 | 3)[];       // a Chaos card of one of these tiers; query tier=1,2
  spellClasses?: SpellClass[]; // a spell of one of these classes; query spell=utility
}

// cards/browse.ts (pure)
export const SORT_KEYS = ['cost', 'name', 'type', 'color', 'attack', 'hp', 'speed'] as const;
export type SortKey = (typeof SORT_KEYS)[number];
export const GROUP_KEYS = ['none', 'type', 'cost', 'color'] as const;
export type GroupKey = (typeof GROUP_KEYS)[number];
export const VIEWS = ['images', 'list', 'table'] as const;
export type View = (typeof VIEWS)[number];
export interface BrowseOptions { sort: SortKey; descending: boolean; group: GroupKey; view: View }
export const DEFAULT_BROWSE: BrowseOptions; // { sort: 'cost', descending: false, group: 'none', view: 'images' }
export function sortCards(cards: readonly Card[], sort: SortKey, descending: boolean): Card[];
export type GroupValue =
  | { by: 'none' } | { by: 'type'; type: CardType } | { by: 'cost'; cost: number }
  | { by: 'color'; color: Color | 'multicolor' | 'colorless' };
/** The cards in groups, each keeping the order it was given. Empty groups are left out. */
export function groupCards(cards: readonly Card[], group: GroupKey): { value: GroupValue; cards: Card[] }[];
/** sort, dir=desc, group, view: only what differs from DEFAULT_BROWSE. */
export function browseToQuery(options: BrowseOptions): URLSearchParams;
/** A bad value gives DEFAULT_BROWSE's value for that field. */
export function browseFromQuery(query: URLSearchParams): BrowseOptions;

// components
export function FilterChips(props: { value: CardFilter; onChange: (next: CardFilter) => void }): JSX.Element | null;
export function CardList(props: { cards: readonly Card[]; onSelect: (card: Card) => void }): JSX.Element;
export function CardTable(props: { cards: readonly Card[]; onSelect: (card: Card) => void }): JSX.Element;
```

## Deliverables

1. **Sorting.** A "Sort by" select (cost, name, type, color, attack, HP, speed) and a "Descending" checkbox, over the results.
   - cost is `compareCards`; name compares names, then `compareCards`
   - type follows `CARD_TYPES`
   - color: one-color cards in `COLORS` order, then multicolored cards by their first color, then colorless ones
   - attack, HP and speed read `stats`. Cards without stats come after, in `compareCards` order, in both directions.
   - every tie falls back to `compareCards`, then the id
2. **Groups.** A "Group by" select: none, type, cost, color. Each group is a section headed "<name> (<count>)", in `CARD_TYPES` order, by rising cost total, or as Ember, Tide, Earth, Dark, Light, Multicolor, Colorless. A card with two or more colors goes in Multicolor. The sort applies inside each group, and Descending doesn't reorder the groups.
3. **Views.** A "View" radio group: Images, List, Table.
   - Images: today's `CardTile` buttons. It's the default.
   - List: a row per card with its name as a button, the cost, the type and the rules text.
   - Table: a real table (a caption, `th scope="col"`) with Name (a button), Cost, Type, Colors, HP, Attack, Attack speed, Speed, Range, Squad and Durability. A card without the stat shows "—". The table scrolls sideways inside its column.

   In every view a click shows the card's `CardDetail` in the right panel, as today.
4. **Filters.** `CardFilters` gets fieldsets for keywords, range, squad (Min and Max, like cost), Chaos tier and spell class. They sit in a "More filters" disclosure, closed unless one of them is set. The deck editor's browser gets them too, through the same component.
5. **Chips.** `FilterChips`, over the results on `/cards`, shows one chip per active filter value: each type, each color, Colorless, the cost range, each keyword, each range, the squad range, each tier and each spell class. A chip is a button whose name says what it removes ("Remove filter: Ember"). "Clear filters" shows when there are two or more chips; it clears what the chips show and keeps the search text. The search text gets no chip, since the search box shows it.
6. **The URL.** The filters (`filterToQuery`, old parameters and new) and the browse options (`browseToQuery`) share the page's query, with `replace: true` as today. Changing one keeps the other. The clicked card stays React state, as today.
7. **Text.** The text of `CardFilters.tsx`, `CardsPage.tsx` and the new files goes through `t()`, from `en/cards.json`, the namespace this card owns. The English that exists stays the same, except that types and colors get names wherever the browser shows them (filters, chips, headers, list, table): "Unit", "Leader", "Spell", "Trap", "Artifact", "Enchantment", "Resource", "Chaos", and "Ember", "Tide", "Earth", "Dark", "Light", "Colorless" (RULES.md › Card colors). Keywords, ranges and spell classes get names too ("Ignores Blockers", "Extra life", "Melee", "Utility"). `CardTile` and `CardDetail` keep their text.
8. **Tests**, in new files only:
   - `browse.test.ts`: `sortCards` for each key in both directions, with stat-less cards last; `groupCards` for each key, with the order, Multicolor and Colorless; the browse query round trip, defaults left out, and bad values.
   - `filters.test.ts`: each new filter, and the round trip of its query parameter.
   - `browser.test.tsx`: `CardsPage` reads the sort, group, view and new filters from the URL; switching the view writes the URL and keeps the filters; group headers with counts; a chip removes its filter; Clear filters; a click in the list and in the table opens the card's detail.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test src/cards/ decks/editor` passes: the new tests, `cards.test.tsx` unchanged, and the deck editor with the shared filters
- [ ] `git diff --name-only main...HEAD -- apps/web/src/cards/CardDetail.tsx apps/web/src/cards/cards.test.tsx apps/web/src/cards/CardTile.tsx` prints nothing
- [ ] `pnpm test:e2e` passes, with `e2e/m4.spec.ts` unchanged

## Out of scope

- `CardDetail.tsx` and `cards.test.tsx` (T-115, wave 16), and bot-game stats on card pages (T-134).
- The deck editor's browser, beyond what `CardFilters` adds: T-125 owns `decks/editor/` in this wave.
- `CardTile`: the deck editor and the match tray use it.
- Sorting by clicking a table header, and saving views per player.
- Wording the load error by its API code.

## Notes

- **`cards.test.tsx` must pass unchanged** (T-115 owns it). It pins:
  - a round trip of a filter literal with only the five old fields, and a query of bad values that gives `EMPTY_FILTER`. So the new fields are optional, and `filterFromQuery` leaves out each one the query doesn't set or sets only to bad values: `toEqual` ignores an `undefined` field, but not `[]`.
  - `filterCards(list, EMPTY_FILTER)` ordered by cost, then name. `filterCards` keeps `compareCards`, and other orders are `sortCards`' job.
  - `getByRole('searchbox')`: one searchbox on the page
  - after it types a card's name, `getByRole('button', { name: new RegExp(name) })`: exactly one button holds the name. Hence no chip for the search text, and Images stays the default.
  - `findByText('N of M')`: the count stays one element with exactly that text. Group headers use "(n)".
  - the error alert holds the API's message ('Boom'), so `state.error.message` stays
- **The e2e** must pass unchanged: on `/cards`, the searchbox "Search", a tile button `/Vask, Pyre Marshal/` and the article it opens; in the deck editor, the browser's searchbox "Search", the checkbox "Fits the Leader" and the tile buttons.
- **T-125 runs beside this card** and uses `filter.ts` and `CardFilters`. Add to them; change no export, prop or behavior that exists.
- **Squad.** RULES.md's "Squad Size" column is the footprint (`size`), while the card view's "Squad" is `squad`, the units per card. Default: the filter works on `squad` and is labeled "Squad", as the card view labels it. No footprint filter.
- A card matches the keywords when it has every one chosen (keywords narrow, unlike colors). A keyword set to a number counts as set. The range, squad and keyword filters leave out cards without those fields: a spell has no range.
- The query parameters `sort`, `dir`, `group`, `view`, `kw`, `range`, `squad`, `tier` and `spell` don't collide with `q`, `type`, `color`, `colorless` and `cost`.
- Desktop first: it works from 1024 px. Styles go inline or in `cards/cards.css`; `theme.css` isn't in scope.
- Size: this is the top of the range (sorting, groups, three views, five filters and chips). If the lead wants it smaller, move the new filters and the chips to a follow-up card, and keep sorting, groups, views and the URL here.
