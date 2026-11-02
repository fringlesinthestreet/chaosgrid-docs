---
id: T-134
title: Bot-game stats on card pages
milestone: M5
depends_on: [T-115, T-127, T-131]
branch: agent/T-134-card-stats
model: sonnet
effort: medium
scope:
  - packages/cards/src/stats.ts
  - packages/cards/src/stats.test.ts
  - packages/cards/src/index.ts
  - packages/cards/stats/**
  - packages/cards/README.md
  - tools/sim-cli/src/**
  - tools/sim-cli/README.md
  - apps/web/src/cards/**
  - apps/web/src/i18n/en/cards.json
context:
  - packages/cards/README.md#Entry points
  - tools/sim-cli/README.md
  - apps/web/README.md#Text
  - apps/web/README.md#Tests
  - docs/tasks/M5/T-127-card-browser.md#Interfaces
---

# T-134 — Bot-game stats on card pages

## Goal

The human tunes cards from bot games, and players will want to see how a card does. After this PR, `@chaosgrid/cards` holds a committed stats file, `packages/cards/stats/cards.json`, with each card's counts from bot games. `pnpm sim --card-stats FILE` writes it, from a run or a `--merge` (T-131). The `/cards` page shows a small "Bot games" section under the clicked card, clearly marked as bot data, and can sort by bot win rate. The first committed file is empty, so every card shows "No bot data yet"; the balance baseline (T-139) fills it.

Keep it small: one schema, one writer, one section and one sort key.

## Interfaces

What exists (copied from the code on 2026-10-29, with the cards T-124, T-127 and T-131 as planned). Re-read T-127's `browse.ts` and `CardsPage.tsx`, and T-131's `stats.ts` and `command.ts`, when you start.

```ts
// packages/cards: package.json exports "." (./src/index.ts) and "./node". src/index.ts re-exports
//   colors, cost, deck, dsl, ids, schema, spells and values. ids.ts:32 CARD_ID_PATTERN.
// No runtime file imports JSON yet. src/deck/check.test.ts:3 imports a fixture with a default import,
//   which tsconfig.base.json allows ("resolveJsonModule": true, "moduleResolution": "Bundler").
//   @chaosgrid/cards runs under Vite and Vitest (web), and tsx (sim-cli, the API, the seed).
// src/readme.test.ts parses every ```json block of the README as a card or an ability.

// tools/sim-cli (T-131): Summary.cards: Record<string, CardCounts>, by card id
interface CardCounts { games: number; drawn: number; played: number; winsPlayed: number; winsNotPlayed: number }
// a run writes --json FILE; --merge FILE,… adds reports up and prints them. Paths resolve like --log.

// apps/web/src/cards (T-127): browse.ts
export const SORT_KEYS = ['cost', 'name', 'type', 'color', 'attack', 'hp', 'speed'] as const;
export function sortCards(cards: readonly Card[], sort: SortKey, descending: boolean): Card[];
//   cards without the stat come after, in compareCards order, in both directions; ties fall back to
//   compareCards, then the id. browseToQuery / browseFromQuery: sort=<key>, a bad value gives the default.
// CardsPage.tsx: a "Sort by" select over the results; a click in any view shows the card's CardDetail
//   in the right panel. T-115 gave CardDetail a `size` prop for the match's card view.
// apps/web/src/i18n (T-124): t(id: MessageId, values?: MessageValues): string, ICU messages.
//   en/cards.json is the cards folder's namespace (D50).
```

What this task adds:

```ts
// packages/cards/src/stats.ts (exported from src/index.ts)
/** One card's counts from bot games, in seat-games, as sim-cli's balance report counts them. */
export const CardStatsSchema = z
  .strictObject({
    games: nonNegativeInt, drawn: nonNegativeInt, played: nonNegativeInt,  // helpers.ts:13
    winsPlayed: nonNegativeInt, winsNotPlayed: nonNegativeInt,
  })
  .check(/* drawn ≤ games, played ≤ games, winsPlayed ≤ played, winsNotPlayed ≤ games − played */);
export type CardStats = z.infer<typeof CardStatsSchema>;
export const CardStatsFileSchema = z.strictObject({
  version: z.literal(1),
  cards: z.record(z.string().regex(CARD_ID_PATTERN), CardStatsSchema),
});
export type CardStatsFile = z.infer<typeof CardStatsFileSchema>;
/** The committed stats, packages/cards/stats/cards.json, parsed when the module loads. */
export const CARD_STATS: CardStatsFile;
/** winsPlayed ÷ played, or null when the card was never played. */
export function winRateWhenPlayed(stats: CardStats): number | null;

// packages/cards/stats/cards.json, as first committed:
//   { "version": 1, "cards": {} }

// tools/sim-cli/src/card-stats.ts (new)
/** The stats file for a summary: its per-card counts, ids sorted. */
export function toCardStatsFile(summary: Summary): CardStatsFile;
export function formatCardStatsFile(file: CardStatsFile): string; // JSON.stringify(file, null, 2) + '\n'
// command.ts: SimOptions gains cardStats: string | null (DEFAULTS: null), from --card-stats FILE.

// apps/web/src/cards/BotGames.tsx (new)
export function BotGames(props: { stats: CardStats | undefined }): JSX.Element;
// browse.ts: SORT_KEYS gains 'botWinRate', and sortCards takes the stats:
export function sortCards(
  cards: readonly Card[], sort: SortKey, descending: boolean,
  stats?: Readonly<Record<string, CardStats>>, // default CARD_STATS.cards
): Card[];
// CardsPage.tsx: CardsPage(props: { stats?: Readonly<Record<string, CardStats>> }), default CARD_STATS.cards
```

## Deliverables

1. **The schema and the file.** `stats.ts` as above. It imports `../stats/cards.json` and parses it with `CardStatsFileSchema` when the module loads. Commit the empty file.
2. **The writer.** `--card-stats FILE` writes `formatCardStatsFile(toCardStatsFile(summary))` after a run or after `--merge`, relative to the directory pnpm ran in, as `--json` does. It parses the file with `CardStatsFileSchema` before it writes, so sim-cli never writes a file the package would refuse. It's a usage error with `--tournament`. Add it to `USAGE` and the README's options table.
3. **The section.** On `/cards`, the right panel shows `BotGames` under the clicked card's `CardDetail`, for the card's entry in the page's `stats`:
   - a heading "Bot games", and the line "From simulated games between bots, not players.";
   - "Played in {played} of {games} bot games";
   - "Won {rate} when played", with `winRateWhenPlayed`, when it was played;
   - "Won {rate} when not played", from `winsNotPlayed ÷ (games − played)`, when that's above 0;
   - with no entry, or `games` 0: "No bot data yet".

   Rates are whole percents, formatted by ICU (`{rate, number, percent}`); counts use ICU plurals. `CardDetail` doesn't change.
4. **The sort.** "Bot win rate" in the "Sort by" select (`botWinRate`) sorts by `winRateWhenPlayed`, lowest first, highest first with Descending, as the other keys do. Cards never played, or without an entry, come after, in `compareCards` order, in both directions; ties fall back to `compareCards`, then the id. `sort=botWinRate` round-trips through the URL like the other keys.
5. **Text.** Every string goes through `t()`, in `en/cards.json`.
6. **Tests:**
   - `packages/cards/src/stats.test.ts`: the committed file parses; the schema refuses a negative count, played over games, winsPlayed over played, winsNotPlayed over games − played, an unknown field, a bad id and version 2; `winRateWhenPlayed` gives 0.75 for 3 of 4 and null for 0 played.
   - sim-cli: `toCardStatsFile` on a hand-built summary; `--card-stats` after a 2-game run (`--target 30 --rounds 3`, in a temporary directory) writes a file `CardStatsFileSchema` reads; `--card-stats` after `--merge`; the usage error with `--tournament`.
   - web, in a new test file: `BotGames` with counts (for example 20 games, 10 played, 4 wins when played and 2 when not: "Played in 10 of 20 bot games", "Won 40% when played", "Won 20% when not played"), with no entry, and never played; the sort through `sortCards` with a hand-built stats map, both directions, unplayed cards last; `CardsPage` with a `stats` prop shows the clicked card's section and sorts by the URL's `sort=botWinRate`.

   No web test may depend on what the committed file holds: T-139 rewrites it, and it can't change web tests. Pass the `stats` prop or a hand-built map.
7. **Docs.**
   - The cards README: `stats.ts` in Entry points, and a short "Bot-game stats" section on what the counts mean, who writes the file (`pnpm sim --card-stats`) and that the numbers come from bots. Use no ```json block (see Interfaces).
   - The sim-cli README: `--card-stats`.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm test:soak` passes
- [ ] `pnpm --filter @chaosgrid/cards test`, `pnpm --filter @chaosgrid/sim-cli test` and `pnpm --filter @chaosgrid/web test src/cards/` pass
- [ ] `pnpm sim --games 2 --target 30 --rounds 3 --card-stats .data/t134.json` exits 0
- [ ] `pnpm cards:validate` and `pnpm db:seed` pass: tsx loads the package with its JSON import
- [ ] `pnpm test:e2e` passes, with `e2e/m4.spec.ts` unchanged
- [ ] `git diff --name-only main...HEAD -- apps/web/src/cards/CardDetail.tsx apps/web/src/cards/CardTile.tsx apps/web/src/cards/cards.test.tsx apps/web/src/cards/browser.test.tsx` prints nothing

## Out of scope

- The real numbers: T-139 runs the baseline and rewrites `cards.json`.
- The API, the DB and the seed: the web bundles the stats with the package, so new numbers need a rebuild.
- The match's card view, the deck editor and the lobby: no bot data there.
- Other sorts or columns from the stats (drawn, played), and a minimum sample.

## Notes

- **Default: the cards page only.** `BotGames` sits beside `CardDetail`, not in it, so the match's card view (T-115) and the deck editor show no bot data. Tell lead if you think the card view needs it.
- **Default: no minimum sample.** The page shows what the file holds and says it's from bots. The text report's lists (T-131) are where `MIN_CARD_PLAYS` applies.
- **The counts are seat-games**, as T-131 counts them: a card in two seats' decks of one game counts twice, and a tie counts as a win. The page calls them "bot games".
- **The JSON import.** Default: a plain default import, as `check.test.ts` does. If tsx refuses it (`pnpm sim`, `pnpm cards:validate`, `pnpm db:seed`), add `with { type: 'json' }`. TypeScript follows an imported file outside `include`. ESLint's boundaries are about workspace packages, so a relative import inside the package passes; if a rule refuses it, send lead a `request`, don't move the file.
- **Fail fast.** An invalid committed file makes every importer throw at load, naming the problem: that's intended. `stats.test.ts` catches it first.
- **Unknown ids.** A card removed from the pool may keep an entry: the page looks stats up by id, so it's harmless.
- **Formatting.** Prettier checks `packages/cards/stats/cards.json` (`.prettierignore` skips `docs/` and `.data/`, not `packages/`). Output of `JSON.stringify(x, null, 2)` that holds only objects and numbers is already Prettier's format, so a written file passes the format gate unchanged. Check it once: write a short run's stats over `packages/cards/stats/cards.json`, run `pnpm exec prettier --check packages/cards/stats/cards.json`, then put the empty file back before you commit.
- **T-127's tests.** If `browse.test.ts` pins the list of sort keys, add `botWinRate` there. Change nothing else in T-127's tests.
