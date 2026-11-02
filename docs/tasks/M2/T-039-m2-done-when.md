---
id: T-039
title: 'M2 done-when: bot soak'
milestone: M2
depends_on: [T-036, T-037, T-038]
branch: agent/T-039-m2-done-when
model: sonnet
effort: high
scope:
  - tools/sim-cli/test/m2-done-when.test.ts
  - tools/sim-cli/README.md
  - packages/bots/src/greedy-bot.ts
  - packages/bots/src/greedy-bot.test.ts
  - packages/bots/src/turtle-bot.ts
  - packages/bots/src/turtle-bot.test.ts
  - packages/bots/test/fixtures/greedy.ts
  - packages/bots/test/fixtures/turtle.ts
  - packages/bots/README.md
  - packages/bots/src/pool.ts
  - packages/bots/src/pool.test.ts
context:
  - docs/PLAN.md#M2
  - packages/bots/README.md
  - tools/sim-cli/README.md#Tests
  - docs/RULES.md#Balance knobs
---

# T-039 — M2 done-when: bot soak

## Goal

Pin M2's done-when in a test: the M2 bots are fit to be M3's opponents (PLAN.md › M2). They play legally at every table size with both deck sources, their games end, and greedy play beats random play. They are placeholders, so this task doesn't tune them toward a balance between them. Fix the bots where they break the done-when, document them, and report what their games say about the balance knobs.

## Interfaces

What exists after T-036, T-037 and T-038:

```ts
// tools/sim-cli/src/command.ts
export interface SimOptions { games: number; seed: string; bots: BotName[]; decks: DeckSource; rounds: number; log: string | null; check: boolean }
export const DEFAULTS: SimOptions; // rounds: 100, decks: 'generated'
export function runGame(seed: string, options: SimOptions, cards: readonly Card[], starters: readonly Deck[]): PlayedGame;
// simCommand loads cards with loadCards and loadStarterDecks from @chaosgrid/cards/node; the test calls them the same way.
// src/stats.ts
export interface PlayedGame { result: GameResult; bots: readonly BotName[]; leaders: readonly string[] }
// src/game.ts
// GameResult: rounds; winners: Seat[] (none means the round cap or an error came first); error: { round, message } | null;
// rejected: Partial<Record<RejectReason, number>>, all seats together; pointsByReason
// src/seeds.ts
export function gameSeed(base: string, index: number): string;
// src/decks.ts
export const DECK_SOURCES = ['generated', 'starter'] as const;
// src/tournament.ts
export interface MatchupResult { lineup: BotName[]; games: number; wins: number[]; ties: number; capped: number; errors: { seed: string; message: string; replay: string }[] }
export function playMatchup(lineup: readonly BotName[], options: SimOptions, cards: readonly Card[], starters: readonly Deck[]): MatchupResult;
// packages/bots/src/greedy-bot.ts and turtle-bot.ts: createGreedyBot and createTurtleBot, each
// with its decision list in the file and in its PR (T-037, T-038)
```

Nothing new is exported.

## Deliverables

1. `tools/sim-cli/test/m2-done-when.test.ts`, with seed `1`, `DEFAULTS.rounds` and no `--check`:
   - **One-bot tables.** For each deck source in `DECK_SOURCES`, each of `greedy` and `turtle`, and 2, 3 and 4 seats: 10 games through `runGame`, game `i` seeded with `gameSeed('1', i)`. That's 12 tables and 120 games. No game has an `error`, and no game has any `rejected` action. At most 5% of the 120 games end with no winner. A failure message names the table, the game's seed, and the reasons or the error.
   - **Skill check.** `playMatchup(['greedy', 'random'])` over 100 games with starter decks: no errors, and greedy wins more than 65.
   - Use `runGame` for the one-bot tables because `rejected` counts all seats together: a table of one bot is the only way to pin rejections on that bot.
   - Give it a `timeout` like `test/done-when.test.ts`, and aim for under 90 seconds in total. If it runs slower, play fewer games per table, never fewer tables, and say so in the PR.
2. Bot fixes, in the greedy and turtle files only, until the test passes. Every fix that makes a rejection go away gets a unit test in the bot's test file. Keep each bot's character as PLAN.md › M2 describes it, and don't tune for win rates.
3. `packages/bots/README.md`: sections "The greedy bot" and "The turtle bot" with decision tables, like "The random bot".
4. `tools/sim-cli/README.md` › Tests: a line for the new test and how long it takes.
5. In the PR body, reported and not gated:
   - the table from `pnpm sim --tournament greedy,turtle,random --games 100 --seed 1 --decks starter`
   - the `rounds`, `points` and `rejected` lines from `pnpm sim --bots greedy,greedy,greedy,greedy --games 100 --decks starter`, and the same for `turtle`
   - one line per balance knob (RULES.md › Balance knobs and open questions) that the numbers make look off, for example games far from the 12–15 rounds the point target expects, or turtle tables that stall

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/sim-cli test -- m2-done-when` passes
- [ ] `pnpm --filter @chaosgrid/bots test` passes, with a test for every rejection the bots no longer make

## Out of scope

- Win-rate targets between the bots. Better bots come later; these only need to be fit opponents for M3.
- Changing rules, cards or balance knobs: they belong to M4. Only report them. If a one-bot table stalls because of the rules and not the bot, stop and send `lead` a `question` with the numbers.
- `random-bot.ts`, `draft.ts`, `placement.ts` and the tournament code. If you need a change there, send `lead` a `request`.

## Notes

- A rejection is a bot bug: the bot planned something core refused. Its reason (`RejectReason`) tells you where to look. Replay one game with `pnpm sim --bots turtle,turtle --games 1 --seed <game seed> --decks starter --log <file>` and read the `plan.rejected` events.
- A capped game hit 100 rounds with no winner: a stall, not a long game. It's either a bot that stops scoring (fix it) or a rules finding (report it).
- The skill check tests the game more than the bot: if greedy can't beat random, deliberate play doesn't pay off yet. If it misses after the bots play legally, report the number and ask `lead` instead of tuning.
- Try fixes on fewer games first, then confirm with the full test.
