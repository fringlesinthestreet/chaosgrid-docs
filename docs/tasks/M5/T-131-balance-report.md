---
id: T-131
title: Balance report v2
milestone: M5
depends_on: [T-114]
branch: agent/T-131-balance-report
model: sonnet
effort: high
scope:
  - tools/sim-cli/src/**
  - tools/sim-cli/test/*.ts
  - tools/sim-cli/README.md
context:
  - tools/sim-cli/README.md
  - docs/RULES.md#Balance knobs
---

# T-131 — Balance report v2

## Goal

M5 tunes cards from sim-cli reports, and its Done when needs numbers the report doesn't give yet: the median game length, and Leader win rates with an interval (PLAN.md › M5). After this PR `pnpm sim` also reports:

- game length: the median, p10 and p90, in rounds;
- each Leader's win rate with its sample size and a 95% Wilson interval;
- per card: seat-games with it in the deck, drawn and played, and the win rate when played against not played;
- what each Plan leaves: unspent resources and cards in hand, as averages;
- opening hands with nothing castable;
- how rounds end, per reason, and when the first attack comes.

`--json FILE` writes all of it as counts, and `--merge` adds up reports of one setup, so a long run can be split over several processes. T-134 writes the card pages' stats from the per-card part, and T-139 runs the baseline with both.

## Interfaces

What exists (copied from the code on 2026-10-29). T-110 (`--target`) and T-114 (the bots' Discard-step choices) change `game.ts` and `command.ts` first: re-read them when you start.

```ts
// tools/sim-cli/src/game.ts
export interface GameOptions { seed; cards; bots; decks; maxRounds; check?; onEvents? } // :27-45; T-110 adds pointTarget?
export interface GameResult {                                                           // :54-68
  seed: string; rounds: number; winners: Seat[]; points: number[];
  pointsByReason: Record<ScoreReason, number>; rejected: Partial<Record<RejectReason, number>>;
  error: GameError | null;
}
export function playGame(options: GameOptions): GameResult; // :79. The loop (:116-131): beginRound, each seat's
//   bot plans from begun.snapshots[seat], then playRound(begun.state, plans). record(events) (:91) runs
//   tally(result, event) (:146) on every event, newGame's included.

// tools/sim-cli/src/stats.ts
export interface PlayedGame { result: GameResult; bots: readonly BotName[]; leaders: readonly string[] } // :9-15
export interface Summary {                                                              // :32-57
  games; won; ties; capped; errors: GameResult[]; rounds: { total; min; max }; seatRounds; points;
  pointsByReason; rejected; seats: SeatStats[]; leaders: LeaderStats[];                 // LeaderStats { leader, seats, wins }
}
export function summarize(games: readonly PlayedGame[]): Summary;                       // :59
export interface RunSetup { games; seed; bots; decks; rounds }                          // :117; T-110 may add target
export function replayCommand(setup: RunSetup, seed: string): string;                   // :126
export function formatSummary(summary: Summary, setup: RunSetup, seconds: number): string[]; // :144

// tools/sim-cli/src/command.ts: USAGE :18, SimOptions :33, DEFAULTS :44 (the soaks spread it), parseSimArgs :65
//   (node:util parseArgs, strict), runGame(seed, options, cards, starters, onEvents?): PlayedGame :155 (its decks
//   come from chooseDecks :164), simCommand :203: the run loop :241-261, the report :264-266. --log's write
//   (:251-259) is the model for --json. command.test.ts:118 matches /errors: none$/ at the very end of the output.

// What the referee sees (@chaosgrid/protocol, @chaosgrid/core):
// card.drawn { seat, card, cardId }, resource.drawn { seat, card, cardId, rested }: private draws; newGame's
//   events include the opening draw.
// plan.rejected { seat, index, action, reason }: core skipped action `index` of the seat's plan.
// tick { tick }: before a tick's first event; ticks restart at 0 each round (core round/begin.ts:82).
// unit.attacked { unit, target }: a unit attacked a unit or a permanent. TICKS_PER_SECOND (protocol) is 100.
// playRound(state, plans) returns { state, events, winners, reason }, reason: EndReason
//   ('timeUp' | 'lastStanding' | 'chaosWon'), a type @chaosgrid/core exports.
// Plan actions that play a card: castUnit, castPermanent and castSpell { card: CardInstanceId, … }; castLeader.
// Snapshot.hand: HandCard[] ({ card, cardId, cost, … }); Snapshot.resources: PoolResource[]
//   ({ card, cardId, gives, rested, attachedTo }). Cost { generic, colors: { R, T, E, D, L } };
//   Gives = 'any' | Color[], where [] is colorless and 'any' is Prism.
// checkPlan(state, seat, plan): PlanCheckedEvent (core round/check.ts): a dry run of one seat's plan on a copy.
//   Its `snapshot` is the seat's view with the plan applied: cards gone from the hand, resources rested or attached.
// Deck { leader: string; main: readonly string[]; resources: readonly string[] } (@chaosgrid/cards).
```

What this task adds:

```ts
// game.ts: GameResult gains
/** How each round's Simulate ended, in round order. */
ends: EndReason[];
/** Each round's first `unit.attacked`, in ticks from Simulate's start; null when nobody attacked. */
firstContact: (number | null)[];
/** Per seat, seat 0 first. */
seats: SeatRecord[];

export interface SeatRecord {
  /** Card ids it drew (`card.drawn`, `resource.drawn`, the opening draw included), each once. */
  drawn: string[];
  /** Card ids it played, each once: a castUnit, castPermanent or castSpell core didn't reject, or castLeader. */
  played: string[];
  /** Its Plans, and what they left, summed: unrested and unattached resources, and cards in hand. */
  plans: number;
  unspentResources: number;
  cardsInHand: number;
  /** Whether round 1's hand held a card its pool could pay for; null when round 1's Plan never came. */
  openingCastable: boolean | null;
}

// pay.ts (new, pure)
/** Whether resources that give `pool` can pay `cost`: each colored pip from its own resource giving that
 *  color (or Prism), the generic part from what's left. Ignores room and targets. */
export function canPay(cost: Cost, pool: readonly Gives[]): boolean;

// stats.ts
// PlayedGame gains decks: readonly Deck[] (empty when the decks couldn't be chosen).
// Summary gains these fields, each a count or a sum, so two summaries add up:
lengths: Record<number, number>;                  // played games by rounds: { 12: 40 } is 40 games of 12 rounds
ends: Record<EndReason, number>;                  // rounds by how Simulate ended
firstContact: { bySecond: Record<number, number>; none: number }; // rounds by the whole second of their first attack
plans: { count: number; unspentResources: number; cardsInHand: number };
openingHands: { seats: number; nothingCastable: number };
cards: Record<string, CardCounts>;                // by card id
// and Summary.errors becomes { seed: string; round: number; message: string }[], so a Summary is plain JSON.

export interface CardCounts {
  /** Seat-games whose deck holds the card: main deck, resources or Leader. */
  games: number;
  drawn: number;
  played: number;
  /** Of the seat-games it was played in, the ones the seat won (a tie is a win, as in wins by seat). */
  winsPlayed: number;
  /** Of the seat-games it was in the deck but not played, the ones the seat won. */
  winsNotPlayed: number;
}
export const MIN_CARD_PLAYS = 30; // the report's per-card lists skip cards with fewer seat-games
export function mergeSummaries(a: Summary, b: Summary): Summary;
/** The nearest-rank percentile `p` (0 to 100) of a histogram, or null when it's empty. */
export function percentile(counts: Readonly<Record<number, number>>, p: number): number | null;
/** The 95% Wilson score interval of `wins` in `n`, as shares from 0 to 1; { low: 0, high: 1 } when n is 0. */
export function wilson(wins: number, n: number): { low: number; high: number };

// report.ts (new)
/** What `--json FILE` writes, version 1: the setup and the Summary. Counts only, so reports add up. */
export interface JsonReport {
  version: 1;
  setup: {
    bots: BotName[];
    decks: DeckSource;
    rounds: number;                           // the round cap
    target: number | null;                    // --target; null: core's default
    runs: { seed: string; games: number }[];  // one for a run; one per run a merge added up
  };
  summary: Summary;
}
export function toJsonReport(summary: Summary, setup: RunSetup): JsonReport;
export function formatJsonReport(report: JsonReport): string; // JSON.stringify(report, null, 2) + '\n'
/** Throws, naming `file`, unless `text` is a version 1 report. */
export function parseJsonReport(text: string, file: string): JsonReport;
/** Adds reports of one setup up. Throws when bots, decks, rounds or target differ, or two runs share a seed. */
export function mergeReports(reports: readonly JsonReport[]): JsonReport;

// command.ts: SimOptions gains json: string | null (DEFAULTS: null); parseSimArgs reads --json FILE and
//   --merge FILE,FILE,…  index.ts exports the new names.
```

## Deliverables

1. **What a game records.** In `playGame`, without changing the game (same events, plans and winners):
   - each round's end reason, from `playRound`'s `reason`;
   - first contact: the latest `tick` value when the round's first `unit.attacked` comes;
   - per seat, `drawn` from `card.drawn` and `resource.drawn`;
   - per seat, `played`: each cast action of its plan whose index has no `plan.rejected` for that seat in the round's events. The card id comes from the round's snapshot hand;
   - per seat and round, `checkPlan(begun.state, seat, plan)`'s snapshot: `hand.length`, and the resources neither rested nor attached;
   - in round 1, `openingCastable`: some hand card's `cost` passes `canPay` against the unrested, unattached resources' `gives`.
2. **The summary.** `summarize` fills the new fields, and `mergeSummaries` adds two up: histograms, ends and cards by key, seats by index, Leaders by id. Per card:
   - a main deck card is drawn by `card.drawn` and played by a cast;
   - a resource is played when drawn, since it's in play at once;
   - a Leader is drawn in every game, since it waits in the command zone, and played when cast.

   A game that threw counts nowhere, as today.
3. **The text report.** Keep every line it prints, and add, all before `errors:` (still the last thing printed):
   - the rounds line goes on: `; median 9, p10 5, p90 14`;
   - `ends      timeUp 12.5%, lastStanding 85.0%, chaosWon 2.5% of 400 rounds`;
   - `contact   first attack at second 4 (median; p10 3, p90 7); 2 rounds had none`;
   - `plans     2.10 resources unspent and 4.30 cards in hand at the end of a Plan, per seat`;
   - `opening   12 of 400 opening hands (3.0%) had nothing castable`;
   - each Leader line ends with its interval, `(22.1% to 32.6%)`;
   - a cards section with three lists of 10: the highest and the lowest win rates when played, among cards played in at least `MIN_CARD_PLAYS` seat-games, and the cards drawn in at least that many that were played least often when drawn. Each line has the card's games, drawn, played, and both win rates. When no card qualifies, one line says so.

   The layout is yours, as long as each line starts with the word shown.
4. **`--json FILE`.** After a plain run, writes `formatJsonReport(toJsonReport(summary, setup))`, relative to the directory pnpm ran in, like `--log`. It holds no wall-clock time, so the same command writes the same file (D8).
5. **`--merge FILE,FILE,…`.** Reads the reports, merges them and prints the text report, with no run time. With `--json FILE` it writes the merged report too. It's a usage error with any option that plays games: `--games`, `--seed`, `--bots`, `--tournament`, `--decks`, `--rounds`, `--target`, `--log` and `--check`. `--json` with `--tournament` is a usage error as well. The exit code is 1 on a usage error, a file it can't read or parse, reports that don't add up, or merged games that threw, as for a run.
6. **Tests**, in `src/*.test.ts`:
   - `canPay`: colored pips, generic from what's left, a two-color resource, Prism, colorless, too few resources;
   - `percentile` and `wilson` against worked values: 5 of 10 is 0.237 to 0.763, 0 of 10 is 0 to 0.278, and n = 0;
   - `summarize` on two hand-built games: a card played in one and only drawn in the other, a resource, a Leader, and the ends, first contact, plans and opening hands;
   - `mergeSummaries`: the merge of two games' summaries equals the summary of both;
   - `playGame` on a real game: every main deck card it played was drawn, everything drawn is in its deck, `plans` is rounds × seats, and `ends` has one entry per round;
   - `simCommand`: `--json` writes a report that `parseJsonReport` reads back; merging `--seed 1 --games 2` and `--seed 3 --games 2` writes the same JSON as `--seed 1 --games 4` (all with `--target 30 --rounds 3`, in a temporary directory); the usage errors above.

   Every existing test keeps passing, the regexes on the text report included.
7. **README.** The new options, what the report prints, a "JSON report" section (the fields, version 1, what adds up), and how to split a long run: contiguous seeds, one process per part, then `--merge`.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm test:soak` passes
- [ ] `pnpm --filter @chaosgrid/sim-cli test` passes
- [ ] `pnpm sim --games 4 --target 30 --json .data/t131.json` exits 0 and prints the median and the Leader intervals
- [ ] `pnpm sim --merge .data/t131.json` exits 0 and prints the same numbers
- [ ] `git diff --stat main...HEAD -- tools/sim-cli/test/golden tools/sim-cli/test/fixtures` prints nothing

## Out of scope

- The card pages' stats file and `--card-stats` (T-134), and the baseline run (T-139).
- Tournaments: `--tournament` prints what it prints today.
- Parallel games inside sim-cli: a long run is split into processes and merged.
- How bots play and how core scores.

## Notes

- Default: percentiles are nearest-rank, so they're whole rounds and whole seconds. A capped game counts at the cap.
- First contact is the round's first `unit.attacked`, whoever attacks what (a Chaos unit, a prize, an Emblem).
- The Plan's leftovers come from `checkPlan`, a dry run of one seat's plan. It's exact for seat 0. For a later seat it misses what earlier seats' plans did to it, such as an opponent's utility spell: fine for an average. It copies the state once per seat and round, so time `pnpm sim --games 10 --seed 1 --target 30` before and after, and put both times in your handoff. Tell lead if it's more than 10% slower.
- `canPay` asks whether any assignment pays. In a rare multi-color pool that can differ from core's own pick order (bots/src/pool.ts mirrors it): fine for a count, and its doc comment says so.
- A cast's card id comes from the snapshot the bot planned from: a bot plans from it, so every cast names a card in it.
- The JSON holds counts only, never rates: the text report and T-134 compute the rates. JSON keys come back as strings, so read the histograms' keys with `Number`.
- `rounds.min` is 0 when no game was played: after a merge, take min and max from `lengths`.
- A merge refuses runs whose games overlap: for whole-number seeds the range S to S + games − 1, otherwise the same seed twice. Game i of `--seed S` plays seed S + i, so the parts of a run with contiguous seeds merge into exactly that run's report (the test above checks it).
- `parseJsonReport` checks the version and the top-level shape by hand: sim-cli doesn't depend on zod, and its package.json is out of scope.
- If `replayCommand` doesn't pass `--target` yet, add it: a replay must play the same game.
- The golden game plays through test/scripted.ts, not `playGame`, so it can't change here.
- Size: this is at the top of the range (about 100 steps). Do the deliverables in order and commit after each; if you run short, hand off with `--merge` missing and say so.
