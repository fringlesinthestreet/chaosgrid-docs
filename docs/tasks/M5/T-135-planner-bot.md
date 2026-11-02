---
id: T-135
title: The planner bot looks ahead
milestone: M5
depends_on: [T-116, T-129, T-133, T-134, T-141]
branch: agent/T-135-planner-bot
model: opus
effort: high
scope:
  - packages/bots/**
  - apps/web/src/host/**
  - tools/sim-cli/src/**
  - tools/sim-cli/test/planner.soak.test.ts
  - tools/sim-cli/test/planner.perf.test.ts
  - tools/sim-cli/package.json
  - tools/sim-cli/README.md
context:
  - packages/bots/README.md#Using a bot
  - packages/bots/README.md#The greedy bot
  - packages/bots/README.md#Adding a bot
  - docs/PROTOCOL.md#Round previews
  - packages/core/README.md#Previews
  - tools/sim-cli/README.md#Tournaments
  - tools/sim-cli/README.md#Tests
---

# T-135 — The planner bot looks ahead

## Goal

The human wants bots that try out what can happen, from what their seat can see, and play the best option, without slowing the game (D49, 2026-10-29). After this PR a `planner` bot does that. It builds a few candidate plans from the heuristic bots and previews each one with the `Simulator` its runner passes in (core's `previewRound`, T-129). It stays within a fixed budget of previews and ticks, and keeps the plan that scores best. sim-cli and the web host pass it the simulator, and a soak shows it wins more often than greedy.

## Interfaces

What exists (copied from the code on 2026-10-29). T-114, T-116, T-130, T-133 and T-134 change these files first: re-read greedy-bot.ts, turtle-bot.ts, registry.ts, sim-cli's game.ts and host.ts when you start.

```ts
// packages/bots/src/bot.ts:8-19 (T-114 adds chooseDiscards)
export interface Bot { readonly name: string; plan(snapshot: Snapshot): Plan; chooseDiscards(snapshot: Snapshot): CardInstanceId[] }
export type Random = () => number;

// packages/bots/src/registry.ts
const FACTORIES = { random, greedy, turtle } satisfies Record<string, (random: Random) => Bot>; // :8-12
export type BotName = keyof typeof FACTORIES;                     // :14
export const BOT_NAMES = Object.keys(FACTORIES) as BotName[];     // :17
export function createBot(name: BotName, random: Random): Bot;    // :24
// registry.test.ts:6 expects ['random', 'greedy', 'turtle']; :16 creates every bot with createBot(name, () => 0.5).

// packages/bots/src/greedy-bot.ts: createGreedyBot({ random }) (:34). planFor(snapshot, random) (:48) builds
//   the private GreedyPlanner (:90) three times, and the planner aims at `pointTarget(snapshot).aim` (:103).
//   T-130 changes what greedy aims at (prizes, Emblems, keeping away from Chaos) and how spells pick
//   targets. T-133 adds traps, Leader moves and Rest to the planners.
// packages/bots/src/placement.ts: PRIZE_VALUE = 2 (:76, the default prizePoints); pointTarget(snapshot) (:84).
//   T-130's card adds aimFor(snapshot): { seat; aim } there (the best Emblem, else an undefended prize,
//   else pointTarget's), with bestEmblem and undefendedPrize. Use the names its code has.
// packages/bots/src/turtle-bot.ts: createTurtleBot({ random }) (:32).

// T-129, in packages/protocol/src/preview.ts:
//   PreviewBudget { previews; ticksPerPreview }
//   SeatPreview { seat; points: Record<ScoreReason, number>; conceded; unitsLost; unitsAlive; prizeHp }
//   RoundPreview { seat; seats: SeatPreview[]; emblems; rejected: PlanRejection[]; endTick; ended }
//   type Simulator = (snapshot: Snapshot, plan: Plan) => RoundPreview;
// and in core's public entry: previewRound(snapshot, plan, cards: Iterable<Card>, { maxTicks }): RoundPreview.
// Core's README › Previews has what a preview costs per 1,000 ticks, and what it doesn't know.

// tools/sim-cli/src/game.ts:111-114, each seat's bot:
const rng = seedRng(botSeed(seed, seat));
return createBot(name, () => nextFloat(rng));
// With `check`, game.ts parses snapshots and plans: parse(Schema, value, label).
// tools/sim-cli/src/command.test.ts:63 names the bots in an error message.
// tools/sim-cli/src/tournament.ts: playMatchup(lineup, options, cards, starters): MatchupResult (:44).
//   wins[i] counts the games lineup[i] won alone (:15), and the seats rotate with the game (seated, :36).
// tools/sim-cli/test/m3-done-when.soak.test.ts: the D33 pattern, with an options(patch) helper over DEFAULTS.
// tools/sim-cli/test/snapshot-positions.test.ts:69-76: a game played round by round, bots planning from snapshots.
// tools/sim-cli/package.json: "test": "vitest run --exclude '**/*.soak.test.ts'", "test:soak": "vitest run soak.test".
//   The root's `test` and `test:perf` run every package's test:perf (pnpm -r --if-present).

// apps/web/src/host/host.ts: the constructor (:100) gets `cards` and creates each bot at :129 with
//   createBot(player.bot, () => nextFloat(rng)). begin() (:175) plans every bot synchronously, in seat
//   order, after beginRound (:187-191). T-116 adds the Discard stage: re-read it.
// apps/web/src/host/host.test.ts: bot(seat, name = BOT_NAMES[seat % BOT_NAMES.length]) (:48); the
//   replay check creates the bots again with createBot (:146-150).
// apps/web/src/lobby/index.tsx:154 lists BOT_NAMES by name, so `planner` shows up there with no change.
```

What this task adds:

```ts
// packages/bots/src/planner-bot.ts (new)
export interface PlannerBotOptions {
  /** The bot's only randomness (D8). */
  random: Random;
  /** Core's previewRound, bound by the runner with budget.ticksPerPreview as maxTicks (D49). */
  simulator: Simulator;
  budget: PreviewBudget;
}
/** A bot named `planner`: it previews a few candidate plans within its budget and keeps the best. */
export function createPlannerBot(options: PlannerBotOptions): Bot;
/** Measured so a decision on the busiest snapshot takes about 250 ms (Deliverable 5). */
export const DEFAULT_PREVIEW_BUDGET: PreviewBudget;
/** How the planner ranks a candidate's preview for snapshot.seat: higher is better. */
export function scorePreview(preview: RoundPreview, snapshot: Snapshot): number;

// packages/bots/src/registry.ts
/** What a runner gives a bot that looks ahead (D49). */
export interface LookAhead { simulator: Simulator; budget: PreviewBudget }
/** What createBot hands a bot besides its randomness. */
export interface CreateBotOptions { lookAhead?: LookAhead }
export function createBot(name: BotName, random: Random, options?: CreateBotOptions): Bot;
// FACTORIES gains `planner`, last, so BOT_NAMES is ['random', 'greedy', 'turtle', 'planner'].
// index.ts exports createPlannerBot, PlannerBotOptions, DEFAULT_PREVIEW_BUDGET, LookAhead and CreateBotOptions.
```

## Deliverables

1. **Candidates.** The planner builds these plans, in this order:
   1. greedy's plan, exactly as `createGreedyBot` makes it;
   2. turtle's plan;
   3. greedy's plan toward each other aim it could take, in the shape T-130's aim has (`{ seat, aim }`): each standing Emblem, then each opponent's standing prize, best first by the rules T-130's helpers use.

   Identical plans count once. T-130's card doesn't let greedy plan toward a given aim: add that to greedy as an optional aim that defaults to its own pick, so its plans don't change. T-133's plays (traps, Leader moves, Rest) come with the planners they live in.
2. **Choosing.**
   - With one candidate, the planner plans without a preview.
   - Otherwise it previews the first `budget.previews` candidates, one `simulator` call each, and keeps the one `scorePreview` ranks highest. Ties go to the earlier candidate. A candidate whose preview has `rejected` actions ranks below every candidate without.
   - `scorePreview` is `scored − lost`. `scored` is the seat's points in the preview, every reason added up. `lost` is its `conceded`, plus `PRIZE_VALUE × (1 − prizeHp ÷ maxHp)` while its prize stands; a destroyed prize is in `conceded` already. `maxHp` comes from `snapshot.prizes`.
   - `chooseDiscards` is greedy's.
3. **The registry.**
   - `planner` joins FACTORIES last. `createBot` passes `options.lookAhead` to it, and the other bots ignore it.
   - Without a look-ahead the planner throws, naming D49. It checks its budget with `PreviewBudget.parse`.
4. **The runners.**
   - sim-cli's game.ts and the web host create every bot with `{ lookAhead }`: `DEFAULT_PREVIEW_BUDGET`, and a simulator that calls `previewRound(snapshot, plan, cards, { maxTicks: budget.ticksPerPreview })` with the game's `cards`.
   - With `--check`, sim-cli parses every preview with `RoundPreview`.
   - In host.test.ts, `bot()` keeps to the first three names, and the replay check passes the same look-ahead. A new test plays two rounds of a match with a planner seat.
5. **The budget.** Start from `{ previews: 6, ticksPerPreview: 3_000 }` and the costs in core's README › Previews. Time a decision on the busiest snapshot (the perf test below). While it takes over 250 ms on your machine:
   - lower `ticksPerPreview` first, down to 1,500. The goldens' first deaths come at ticks 210–400, so 1,500 ticks still sees the first fights;
   - then lower `previews`, down to 3.

   Put the result and its time in the bots README and in your handoff. If 3 × 1,500 still takes over 250 ms, keep it and say so.
6. **Tests.**
   - Bots, with a fake simulator (a function that returns made-up previews and counts its calls):
     - the planner calls it at most `budget.previews` times per plan, and not at all with one candidate;
     - it keeps the best-scored candidate, and the earlier one on a tie;
     - the same seed and simulator give the same plan;
     - every plan passes the referee;
     - `scorePreview` on made-up previews, including a destroyed prize, which counts once.
   - registry.test.ts: the new list of names, `createBot` with a look-ahead for every name, and the planner throwing without one.
   - `tools/sim-cli/test/planner.perf.test.ts`:
     - Play one game of 4 greedy bots (seed 1, starter decks, target 30) round by round, as snapshot-positions.test.ts does, and keep every snapshot.
     - Time the planner's `plan` on each, with `DEFAULT_PREVIEW_BUDGET` and the real simulator. The slowest must take under 1,000 ms (the target is 250 ms on a laptop; CI is slower). Print the slowest and the average.
     - sim-cli's package.json gets `"test:perf": "vitest run --no-file-parallelism --retry=1 perf.test"`, and its `test` excludes `**/*.perf.test.ts` too.
   - `tools/sim-cli/test/planner.soak.test.ts`:
     - `playMatchup(['planner', 'greedy', 'greedy', 'greedy'], …)` over 40 games, with starter decks and target 30.
     - No game throws, and `3 × wins[0] > wins[1] + wins[2] + wins[3]`: the planner wins more often than the average greedy seat. Print the shares.
     - The timeout is 900 s. If it runs over 5 minutes here, play 24 games, and say so in the handoff.
7. **Docs.**
   - bots README: a `## The planner bot` section (its candidates, its score, its budget and what it costs), and the look-ahead in › Using a bot.
   - sim-cli README: the two new files and their times in › Tests, and what `--check` checks now.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm test:soak` passes
- [ ] `pnpm test:perf` passes, and its output shows the planner's times
- [ ] `pnpm --filter @chaosgrid/bots test` passes
- [ ] `pnpm --filter @chaosgrid/web test host` passes
- [ ] `pnpm sim --games 2 --bots planner,greedy,greedy,greedy --decks starter --target 30 --check` exits 0
- [ ] `pnpm test:e2e` passes

## Out of scope

- The lobby's difficulty presets and the "Hard" label (T-138). Until then the lobby lists `planner` by its name.
- Bot styles (T-137).
- Smarter discards. The planner discards as greedy does.
- A Web Worker or an async host, so that planning doesn't block the page.
- Budget flags for sim-cli, and a server that enforces budgets (M6).
- Guessing other seats' plans (D49: other seats add nothing).

## Notes

- Planning blocks the page. The host plans bots synchronously in `begin()`, so a round's snapshots reach the screen only after every bot has planned. With three planners at 250 ms, that's about 0.75 s once per round. That's accepted for now. Say in your handoff what you measured.
- Default: the budget is per `plan` call. `chooseDiscards` doesn't preview.
- Default: the planner previews from the snapshot `plan` gets: `beginRound`'s.
- Default: when the simulator throws, the planner lets it throw. It means the runner's `cards` lacks a card, which is a bug.
- Budgets count ticks, never time (D49), so sim-cli runs replay exactly. Bots never read a clock.
- If the soak fails, improve the candidates or the score first, and never loosen the threshold. If it still fails, send `lead` a `question` with the numbers.
- Greedy's plans don't change, so its tests and D33's soak (greedy beats random in more than 55 of 100) stay as they are.
- T-137 weighs `scored` and `lost` per bot style, and passes a style through `CreateBotOptions`. Keep the two terms separate in `scorePreview`.
- T-130 and T-133 were planned alongside this card. Use the names their code has when you start.
