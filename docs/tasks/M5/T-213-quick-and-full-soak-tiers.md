---
id: T-213
title: Quick and full soak tiers
milestone: M5
depends_on: [T-196]
branch: agent/T-213-quick-and-full-soak-tiers
model: sonnet
effort: high
scope:
  - package.json
  - .github/workflows/ci.yml
  - tools/sim-cli/package.json
  - tools/sim-cli/README.md
  - tools/sim-cli/test/**
  - tools/sim-cli/src/command.test.ts
  - tools/sim-cli/src/game-discards.test.ts
context:
  - tools/sim-cli/README.md#Tests
---

# T-213 — Quick and full soak tiers

## Goal

A core, bots, card data or sim-cli change waits about 25 minutes for its checks: on 2026-11-06, on an idle 10-core laptop, `pnpm test` took 4 min 51 s and `pnpm test:soak` 20 min 12 s. After this PR the tests run in D75's four tiers: `pnpm test` without dependency order and without perf tests, `pnpm test:perf` alone, a quick `pnpm test:soak` (a few seeded games per file, legal play only, about 2 minutes), and `pnpm test:soak:full` with today's game counts and every bar.

## Interfaces

D75, as `docs/DECISIONS.md` has it: `pnpm test` runs every package's tests side by side, not in dependency order, without perf tests or soaks, keeps one smoke game, and sim-cli's other tests cap their games unless a whole game is what they check. `pnpm test:perf` runs the perf tests alone, one file at a time, budgets unchanged. `pnpm test:soak` plays a few seeded games in each `*.soak.test.ts` and checks legal play; `pnpm test:soak:full` plays the full counts and also checks the bars that need many games. CI runs `pnpm test:perf` right after `pnpm test`, and the quick soak in its own job.

```jsonc
// package.json (root): the scripts that change. "test:perf" and "test:soak" stay as they are.
"test": "pnpm -r --if-present --no-sort run test",
"test:soak:full": "pnpm -r --if-present run test:soak:full",

// tools/sim-cli/package.json: "test:soak" stays "vitest run soak.test"
"test:soak:full": "CHAOSGRID_SOAK=full vitest run soak.test",
```

```ts
// tools/sim-cli/test/soak.ts (new)
/** True under `pnpm test:soak:full`: every soak plays its full game count and checks its bars. */
export const FULL_SOAK = process.env['CHAOSGRID_SOAK'] === 'full';
/** A soak's game count: `quick` in `pnpm test:soak`, `full` in `pnpm test:soak:full`. */
export function soakGames(quick: number, full: number): number;
```

The soaks, with the times measured on 2026-11-06 (the files run side by side, so the M3 file's two tests, one after the other, set the wall time):

| File today | Its time | After: file | Quick tier | Full tier |
| --- | --- | --- | --- | --- |
| `done-when.soak.test.ts` | 809 s | `random-games.soak.test.ts`, `describe('RandomBots')` | 5 games with `--check` | 100 games with `--check`, as today |
| `m3-done-when.soak.test.ts`, first test | 245 s | `bot-tables.soak.test.ts`, `describe('tables of one bot')` | 1 game per table: no error, no rejected action, valid timelines | 10 per table, plus the two bars: at most 5% of games without a winner, and each deck source's Leaders in all five colors |
| `m3-done-when.soak.test.ts`, second test | 966 s | `bot-skill.soak.test.ts`, `describe('the bots against each other')` | nothing | greedy beats random in more than 55 of 100 games, as today |
| `settle.soak.test.ts` | 316 s | the same | 2 games per deck source | 10 per source, as today |
| `plan-abilities.soak.test.ts` | 96 s | the same | 2 games per table | 10 per table, as today |
| `planner.soak.test.ts` | 296 s | the same | 4 games, the planner once in each seat: no error | 40 games, and the planner beats the average greedy seat, as today |

The slowest tests in sim-cli's `pnpm test`, measured alone on 2026-11-07 (sim-cli's file took 157 s inside the root `pnpm test`, where it also started a minute late, after core's):

| Test | Time | After |
| --- | --- | --- |
| `test/smoke.test.ts`: 5 RandomBot games with `--check` | 106 s | 1 game |
| `src/command.test.ts` › "saves the first game's events with --log": three whole games at the default point target | 76 s | the same runs with `--target 10` |
| `src/game-discards.test.ts`: one game to `maxRounds: 100` with `check: true` | 43 s | the fewest rounds that still discard (try `maxRounds: 3`) |
| `test/planner-early-chaos.test.ts` | 47 s | unchanged: it already plays 4 rounds |

## Deliverables

1. **The tiers.** `test/soak.ts` as above. Each soak takes its counts from `soakGames`. A bar that needs many games is a test of its own, `it.runIf(FULL_SOAK)(…)`, never an `if` inside a test, so the quick tier lists it as skipped. The scripts as in Interfaces.
2. **The split and the renames** (`git mv` where a file keeps its content): the M3 file's two tests become `bot-tables.soak.test.ts` and `bot-skill.soak.test.ts`, so the full tier runs them side by side, and `done-when.soak.test.ts` becomes `random-games.soak.test.ts`. Each soak's header comment says what it checks and what each tier plays, with no task id, milestone or `PLAN.md` (D73).
3. **A quicker `pnpm test`.** The root `test` script as in Interfaces: `--no-sort`, so sim-cli's tests no longer wait for core's, and no perf step. The smoke plays 1 game, and its comment cites D75. The `--log` test and the discard test as in the table, with every assertion kept.
4. **CI.** In `.github/workflows/ci.yml`, a `Perf tests` step (`pnpm run --if-present test:perf`) right after `Test` in the `checks` job, and the `soak` job's comment cites D75 and says it runs the quick tier. The job keeps its timeout.
5. **The README.** `tools/sim-cli/README.md` › Tests: the three tiers, each soak file with its quick and full counts and your measured times, D75 instead of D31, and no task ids in the lines you rewrite. Its planner soak line says it now checks the win share, which it does.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check perf` green
- [ ] `crew check soak` green in under 2 minutes, on a machine with no other worker's tests running; the PR gives its time
- [ ] `pnpm test:soak:full` green, with every bar at today's threshold; the PR gives each file's time (run it in the background)
- [ ] `pnpm test` before and after, and the five slowest sim-cli tests before and after, in the PR
- [ ] `ls tools/sim-cli/test/*.soak.test.ts` lists `bot-skill`, `bot-tables`, `plan-abilities`, `planner`, `random-games` and `settle`
- [ ] `git grep -n -E '(^|[^A-Za-z0-9_])(T-[0-9]{3}|M[0-9])([^0-9A-Za-z]|$)|PLAN\.md' -- 'tools/sim-cli/test/*.soak.test.ts' tools/sim-cli/test/soak.ts tools/sim-cli/test/smoke.test.ts` prints nothing

## Out of scope

- Loosening a bar, a threshold or a perf budget, or lowering a full-tier game count.
- `CLAUDE.md` and `docs/DECISIONS.md`: D75 and the commands table are already on `main`.
- The time of core's tests (57 s, two thirds of it imports) and the web's (83 s): put ideas in the PR.
- Task ids in sim-cli's other files: T-209 removes them.

## Notes

- Vitest hides each test's time in an agent session. To see them: `pnpm --filter @chaosgrid/sim-cli exec vitest run --exclude '**/*.soak.test.ts' --exclude '**/*.perf.test.ts' --reporter=json --outputFile=<a file in your temp dir>`; each test's `duration` is in milliseconds.
- `--no-sort` is safe because no package has a build step: each one's `exports` points at its `src/`.
- A game stopped by the round cap ends without `game.ended`, and the `--log` test checks that the log ends with one. That's why it lowers `--target` instead of passing `--rounds`.
- Give each quick test a timeout of about 4 times its idle time, for a loaded machine. The full tier keeps today's timeouts.
- If a quick count leaves an assertion meaningless at its fixed seed (the Plan abilities soak needs at least one own rest and one wake), use the smallest count that keeps it, and say so in the PR.
- `package.json` and `.github/**` are root files (planning rule 4), and this is their dedicated task.
