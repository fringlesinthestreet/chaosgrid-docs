---
id: T-103
title: Test timeouts that fit the CI runner
milestone: M4
depends_on: []
branch: agent/T-103-ci-timeouts
model: sonnet
effort: medium
scope:
  - packages/core/src/round/round.test.ts
  - packages/core/src/arena/transform.test.ts
  - packages/core/src/combat/caches.test.ts
  - packages/core/src/combat/perf.test.ts
  - tools/sim-cli/src/command.test.ts
  - tools/sim-cli/src/game.test.ts
  - tools/sim-cli/src/tournament.test.ts
  - tools/sim-cli/test/golden.test.ts
  - tools/sim-cli/test/smoke.test.ts
  - tools/sim-cli/test/*.soak.test.ts
  - tools/sim-cli/README.md
  - .github/workflows/ci.yml
context:
  - tools/sim-cli/README.md#Tests
---

# T-103 — Test timeouts that fit the CI runner

## Goal

CI is red (2026-10-28). An agent session can't read its logs, but the timings point at time limits. GitHub's runner for a private repo has 2 CPUs, so Vitest runs one worker there, where this laptop runs nine. `pnpm -r test` also runs several packages at once on those 2 CPUs, and a thread there is about 1.5 to 2 times slower than here. So tests that take a few seconds here go over Vitest's default timeout of 5 seconds, or their own 30, and the soaks, 9.5 minutes here one after another, go over the soak job's 20 minutes. Give them room. Nothing a test checks changes, except one perf budget (deliverable 2).

## Interfaces

What exists (copied from the code on 2026-10-28). The times are this laptop's (an M1 Pro), from `--reporter=verbose`:

```ts
// packages/core, all on Vitest's default timeout (5 s)
// src/round/round.test.ts, in describe('a whole game')
it('plays several rounds with scripted plans', () => { … }); // :73, 3.6 s
it('replays byte for byte from the same inputs', () => { … }); // :109, 2.9 s
it('ends when a seat passes the point target', () => { … }); // :125, 1.3 s
// src/arena/transform.test.ts
it('map back and forth exactly for every world cell, off the grid too', () => { … }); // :44, 1.9 s
// src/combat/caches.test.ts, one test per scenario
it(`never change a result: ${scenario.name}`, () => { … }); // :48, about 1.2 s each

// packages/core/src/combat/perf.test.ts (pnpm test:perf: alone, --retry=1), no timeout
it('runs a 4-player round with 120 units in under 2 seconds', () => { … expect(ms).toBeLessThan(2000); }); // :81, 1.0 s
it('keeps 120 units fighting for 10,000 ticks in good time', () => { … expect(ms).toBeLessThan(5000); }); // :87, 3.0 s

// tools/sim-cli/src/tournament.test.ts
it('accounts for every game, deterministically', () => { … }, 30_000); // :43, 22 s
it('formats a report', () => { … }); // :55, 2.3 s
// tools/sim-cli/src/game.test.ts
it('plays a game to its winners, and its events tell the same story', () => { … }, 30_000); // :29, 4.4 s
it('plays the same game for the same seed (D8)', () => { … }, 30_000); // :50, 14 s
// tools/sim-cli/src/command.test.ts
it('plays the games and prints the stats', () => { … }); // :100, 1.7 s
it('plays a tournament', () => { … }, 30_000); // :121, 4.5 s
it('plays the starter decks', () => { … }); // :131, 1.9 s
it("saves the first game's events with --log, each one a protocol Event", () => { … }, 30_000); // :138, 9.4 s
it("says so when it can't save the log", () => { … }, 30_000); // :160, 3.6 s
// tools/sim-cli/test/smoke.test.ts
it('plays 5 games between 4 RandomBots without an error', { timeout: 60_000 }, () => { … }); // :9, 13 s
// tools/sim-cli/test/golden.test.ts
it('plays the same way every time (D8)', () => { … }); // :41, 2.2 s

// tools/sim-cli soaks (pnpm test:soak): 571 s in all
// test/done-when.soak.test.ts
it('plays 100 games between 4 RandomBots without an error', { timeout: 600_000 }, () => { … }); // :9, 258 s
// test/m3-done-when.soak.test.ts
it(…, { timeout: 300_000 }, () => { … }); // :54, the one-bot tables, 70 s
it('has greedy beat random in more than 55 of 100 games', { timeout: 300_000 }, () => { … }); // :112, 162 s
// test/plan-abilities.soak.test.ts
it('play to the end for 20 seeded games', { timeout: 120_000 }, () => { … }); // :26, 47 s
// test/settle.soak.test.ts
it('ends every Simulate once, short of the cap, with nobody acting', { timeout: 300_000 }, () => { … }); // :54, 34 s
```

```yaml
# .github/workflows/ci.yml:57, in job `soak`
timeout-minutes: 20
```

## Deliverables

1. **Quick tests** (`pnpm test`): give each test above a timeout of at least 5 times its time here. Pass it as the last argument (`}, 30_000);`), the way tournament.test.ts does, or as `{ timeout: N }` in smoke.test.ts, which already uses that form.
   - core, `30_000`: round.test.ts:73, :109 and :125, transform.test.ts:44 and caches.test.ts:48.
   - sim-cli, `120_000`: tournament.test.ts:43, game.test.ts:50 and smoke.test.ts:9.
   - sim-cli, `60_000`: command.test.ts:138.
   - sim-cli, `30_000`: tournament.test.ts:55, command.test.ts:100 and :131, and golden.test.ts:41.

   The other tests above already have 5 times their time. Then time both packages with one worker, as CI runs them: `pnpm --filter @chaosgrid/core test --maxWorkers=1 --reporter=verbose`, and the same for `@chaosgrid/sim-cli`. Apply the same rule to any other test that takes more than a second, and list those tests in the PR. For a test in a file outside the scope, list it in the PR and send `lead` a `request` instead.

2. **Perf** (`combat/perf.test.ts`): give both tests a timeout of `30_000`, so Vitest's 5 seconds never stops a timed run. Raise 'nobody dies' (line 103) from `5000` to `10_000`, and say why in a comment above it: 3 seconds here, and CI's thread is up to twice as slow. The real round keeps `2000`: that's T-020's target.

3. **Soaks** (`pnpm test:soak`): at least 3 times their time here. done-when goes from `600_000` to `900_000`, m3-done-when's greedy against random (line 112) from `300_000` to `600_000`, and plan-abilities from `120_000` to `300_000`. m3-done-when's tables and the settle soak keep `300_000`.

4. **CI** (`.github/workflows/ci.yml`): the `soak` job's `timeout-minutes` goes from 20 to 45. Nothing else in the file changes.

5. **sim-cli README › Tests**: give each soak its time here (done-when about 4 minutes, not 60 seconds; m3-done-when about 4; plan-abilities and settle under a minute each), add the settle soak (T-101) to the list, and say that CI plays them one after another, so the job takes about twice their 9.5 minutes here.

## Acceptance

- [ ] `scripts/check.sh` is green.
- [ ] `scripts/check.sh soak` is green.
- [ ] `pnpm --filter @chaosgrid/core test --maxWorkers=1` and `pnpm --filter @chaosgrid/sim-cli test --maxWorkers=1` pass.
- [ ] In those runs, every test in scope that takes more than a second has a timeout of at least 5 times its time.
- [ ] `git diff -U0 main...HEAD -- packages tools/sim-cli/src tools/sim-cli/test | grep '^[+-][^+-]'` shows only timeouts, the one perf budget and its comment: no test body changes.

## Out of scope

- Fewer games, seeds or rounds in a test, and any change to what a test checks.
- Making core or the games faster. A follow-up could: 'nobody dies' takes 3 seconds here, against a real round's target of 2.
- The root package.json, a Vitest config (a global `testTimeout`) and ESLint: T-068 holds the root files.
- The movement and projectiles perf tests: they're well under their limits.
- Shards, path filters or a nightly soak: the human's call if D31 comes up again.

## Notes

- Vitest 5 sets its workers in `getDefaultMaxWorkers`: `availableParallelism() - 1` for `vitest run`, so 9 on this laptop (10 CPUs) and 1 on CI (2 CPUs). Here the four soak files run side by side, and `pnpm test:soak` takes about as long as done-when alone; CI plays them one after another.
- Shards would split the soaks badly: Vitest assigns files to shards by a hash of their path, not by their time, and each shard job pays for its own install.
- Earlier fixes of the same kind: e3cdd28 (the human's, in pay.test.ts, for CI's 5 s timeout) and T-095.
- D31 moved the perf tests "with their budgets unchanged", and its revisit trigger is "The soak job takes more than 15 minutes, or a perf test fails when it runs alone". Both likely happen on CI now. The human merging this card is their OK for the 10-second budget, and for a 45-minute soak job instead of shards.
- This laptop can't show CI's times. The real check is this PR's own CI run; if a job still fails there, the human sends `lead` the failing step.
- T-068 waits for this task, since both change ci.yml. T-078 can run beside it.
