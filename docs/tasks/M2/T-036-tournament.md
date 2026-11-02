---
id: T-036
title: Bot tournaments in sim-cli
milestone: M2
depends_on: [T-024]
branch: agent/T-036-tournament
model: sonnet
effort: medium
scope:
  - tools/sim-cli/src/tournament.ts
  - tools/sim-cli/src/tournament.test.ts
  - tools/sim-cli/src/command.ts
  - tools/sim-cli/src/command.test.ts
  - tools/sim-cli/src/index.ts
  - tools/sim-cli/README.md
context:
  - tools/sim-cli/README.md
  - docs/PLAN.md#M2
---

# T-036 — Bot tournaments in sim-cli

## Goal

`pnpm sim --tournament greedy,turtle,random` plays every pair of bots head to head, then all of them at one table, with seats rotating, and prints each bot's win rate. M2's done-when is measured with it, and so is the balance-knob sanity check (PLAN.md › M2).

## Interfaces

What exists (copied from the code):

```ts
// src/command.ts
export interface SimOptions { games: number; seed: string; bots: BotName[]; decks: DeckSource; rounds: number; log: string | null; check: boolean }
export function parseSimArgs(args: readonly string[]): SimOptions & { help: boolean };
export function runGame(seed: string, options: SimOptions, cards: readonly Card[], starters: readonly Deck[], onEvents?: (events: readonly Event[]) => void): PlayedGame;
export function simCommand(args: readonly string[], options: CommandOptions = {}): number; // loads cards with loadCards/loadStarterDecks
// src/stats.ts
export interface PlayedGame { result: GameResult; bots: readonly BotName[]; leaders: readonly string[] }
export interface RunSetup { games: number; seed: string; bots: readonly BotName[]; decks: string; rounds: number }
export function replayCommand(setup: RunSetup, seed: string): string;
// src/game.ts: GameResult.winners is Seat[]. Several seats mean a tie; none means the round cap or an
// error came first. GameResult.error is GameError | null, where GameError is { round, message }.
// src/seeds.ts
export function gameSeed(base: string, index: number): string;
// src/bots.ts
export type BotName; export const BOT_NAMES: BotName[]; export function isBotName(name: string): name is BotName;
```

What this task adds:

```ts
// src/tournament.ts
export interface MatchupResult {
  lineup: BotName[]; // as given; game i seats it rotated by i
  games: number;
  wins: number[]; // per lineup entry: the games it won alone
  ties: number; // won by more than one seat
  capped: number; // reached the round cap with no winner
  errors: { seed: string; message: string; replay: string }[];
}
export interface TournamentResult { matchups: MatchupResult[] }
export function matchups(bots: readonly BotName[]): BotName[][]; // every pair in order, then all of them together when there are 3 or 4
export function seated(lineup: readonly BotName[], game: number): BotName[]; // seat s gets lineup[(s + game) % n]
export function playMatchup(lineup: readonly BotName[], options: SimOptions, cards: readonly Card[], starters: readonly Deck[]): MatchupResult;
export function runTournament(bots: readonly BotName[], options: SimOptions, cards: readonly Card[], starters: readonly Deck[]): TournamentResult;
export function formatTournament(result: TournamentResult, options: SimOptions, seconds: number): string[];
```

## Deliverables

1. `src/tournament.ts` as above. Game `i` of every matchup is seeded with `gameSeed(options.seed, i)` and plays `runGame` with `bots: seated(lineup, i)`. Every matchup sees the same seeds, which keeps the comparison fair.
2. `--tournament a,b,…` in `parseSimArgs` and `simCommand`: 2 to 4 bot names, repeats allowed. `--games` counts games per matchup. `--seed`, `--decks`, `--rounds` and `--check` work as they do now. Combining it with `--bots` or `--log` is a usage error. The exit code is 1 if any game threw. Add it to `USAGE`.
3. The report is a header line (the bots, the games per matchup, the seed, the decks), then one line per matchup: its lineup, each entry's wins as a percentage of the matchup's games, then ties, capped games and errors. Every error follows with its replay command (`replayCommand` with the seated lineup and the game's seed).
4. Export the new names from `src/index.ts`, and document `--tournament` in the README: Usage, the option table, and how seats rotate. In the option table, change the `--bots` row to say the bots are `random`, `greedy` and `turtle`, and that `pnpm sim --help` lists them.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `tournament.test.ts`: `matchups` order for 2, 3 and 4 bots; `seated` rotation; in every matchup `wins` plus `ties`, `capped` and the number of errors adds up to `games`; the same seed gives the same result. Run it with `random` and a few short games (`rounds: 5`) to keep it fast.
- [ ] `command.test.ts`: `--tournament` with one name, an unknown name, or `--bots` is a usage error
- [ ] `pnpm sim --tournament random,random,random --games 4 --rounds 10` prints 3 pairs and 1 three-seat matchup, and reports no errors

## Out of scope

- The M2 done-when test: T-039, which calls `playMatchup`
- The bots: T-035 registers `greedy` and `turtle` as stubs, and T-037 and T-038 fill them in

## Notes

- T-035 runs at the same time and registers `greedy` and `turtle` in `src/bots.ts`, which isn't in your scope. They may not exist in your worktree yet, so test with `random`. Once T-035 merges, they appear through `BOT_NAMES` with no change here.
- Count a win only when `winners` has exactly one seat. Map it back to the lineup entry through the rotation.
- A lineup can repeat a name (`random,random`), so `wins` is per lineup entry, not per name.
