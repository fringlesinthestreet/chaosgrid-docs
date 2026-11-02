---
id: T-092
title: Perf and soak test tiers
milestone: M3
depends_on: [T-046]
branch: agent/T-092-test-tiers
model: sonnet
effort: medium
scope:
  - package.json
  - packages/core/package.json
  - tools/sim-cli/package.json
  - tools/sim-cli/test/done-when.test.ts
  - tools/sim-cli/test/m2-done-when.test.ts
  - tools/sim-cli/test/plan-abilities.test.ts
  - tools/sim-cli/test/*.soak.test.ts
  - tools/sim-cli/test/smoke.test.ts
  - tools/sim-cli/README.md
  - .github/workflows/ci.yml
  - scripts/check.sh
  - scripts/README.md
  - docs/agents/WORKER.md
  - CLAUDE.md
context:
  - tools/sim-cli/README.md#Tests
  - docs/agents/WORKER.md#4. Work
  - docs/agents/WORKER.md#7. Verify
  - packages/core/README.md#Tests
---

# T-092 — Perf and soak test tiers

## Goal

T-046 asked two questions about slow tests, and the human answered both (D31):

- Core's perf tests time a round against a budget, but `pnpm test` runs them while every other package's tests run too. Under that load they can fail when the code is fine. They now run alone, after every other test, one file at a time, with the same budgets.
- The whole-game soaks in `tools/sim-cli/test/` take about 3 minutes of every `pnpm test`, in every worktree. They move to their own script, `pnpm test:soak`, and their own CI job. `pnpm test` keeps a short smoke game, so a change that breaks whole games still fails the quick gates.

## Interfaces

What exists (copied from the repo on 2026-10-22):

```jsonc
// package.json (root) scripts
"test": "pnpm -r --if-present run test",
// packages/core/package.json and tools/sim-cli/package.json: no vitest config in either package
"test": "vitest run",
```

```ts
// packages/core/src/combat/perf.test.ts, movement/perf.test.ts, projectiles/perf.test.ts
// time a run with performance.now() against a budget (combat: a real round 2 s, nobody dies 5 s)

// tools/sim-cli/test/done-when.test.ts: M1's done-when
it('plays 100 games between 4 RandomBots without an error', { timeout: 600_000 }, () => {
  // simCommand(['--games', '100', '--seed', '1', '--check'], { out, env: {} }) … expect(report).toMatch(/^errors: none$/m)
});
// tools/sim-cli/test/m2-done-when.test.ts: M2's one-bot tables and skill check, two tests of timeout 300_000
// tools/sim-cli/test/plan-abilities.test.ts: GAMES = 20, timeout 120_000
// tools/sim-cli/test/golden.test.ts: the golden game, fast. It stays in `pnpm test`.
```

```yaml
# .github/workflows/ci.yml: one job, `checks` (ubuntu-latest, timeout-minutes 15):
# checkout, pnpm/action-setup, setup-node (node-version-file .nvmrc, cache pnpm),
# pnpm install --frozen-lockfile, Lint, Format, Typecheck, Test, Validate cards, Seed DB twice
```

```bash
# scripts/check.sh: gates default to (lint format typecheck test); each maps to a pnpm command
case $gate in lint) … ;; format) … ;; typecheck) … ;; test) cmd=(pnpm test) ;; *) die "unknown gate: …" ;; esac
```

D31 (docs/DECISIONS.md): `pnpm test` stays quick. Whole-game soaks are `*.soak.test.ts` files that only `pnpm test:soak` runs, in their own CI job, and `pnpm test` keeps a short smoke game. Core's perf tests run after every other test, one file at a time (`pnpm test:perf`, the last step of `pnpm test`).

## Deliverables

1. **Perf tests run alone.**
   - `packages/core/package.json`: `test` leaves out `perf.test.ts` files (`vitest run --exclude '**/perf.test.ts'`). A new `test:perf` runs only those, one file at a time, and retries a failed test once: `vitest run --no-file-parallelism --retry=1 perf.test`. Other worktrees share the laptop, so one slow run happens. A real regression fails twice.
   - Root `package.json`: `test` runs every package's `test`, then every package's `test:perf` one package at a time: `pnpm -r --if-present run test && pnpm -r --if-present --workspace-concurrency=1 run test:perf`. Add `test:perf` (`pnpm -r --if-present --workspace-concurrency=1 run test:perf`) so it can run by itself.
   - The budgets and the perf test files stay as they are.
2. **Soaks get their own tier.**
   - Rename the three soak files with `git mv`: `done-when.test.ts`, `m2-done-when.test.ts` and `plan-abilities.test.ts` become `*.soak.test.ts`. Their contents don't change.
   - `tools/sim-cli/package.json`: `test` leaves out `*.soak.test.ts`, and a new `test:soak` runs only those.
   - Root `package.json`: `"test:soak": "pnpm -r --if-present run test:soak"`.
   - New `tools/sim-cli/test/smoke.test.ts`: 5 games between 4 RandomBots with `--check`, as `done-when` does with 100, expecting `errors: none`. Keep it under 10 seconds on this laptop.
3. **CI.** In `ci.yml`, add a second job, `soak`, beside `checks`: the same setup and install steps, then one step "Soak tests" that runs `pnpm test:soak`, with `timeout-minutes: 20`. `checks` keeps its steps. Its Test step now runs the perf tests last, through `pnpm test`.
4. **check.sh.** Add a `soak` gate (`pnpm test:soak`). It isn't one of the defaults, so `scripts/check.sh` still runs the four quick gates. The unknown-gate message lists it. Update the `check.sh` row in `scripts/README.md`.
5. **Docs.**
   - WORKER.md › 4. Work (the gates bullet) and › 7. Verify: when your scope touches `packages/core/src/**`, `packages/bots/src/**`, `packages/cards/data/**` or `tools/sim-cli/**`, also run `scripts/check.sh soak` before handing off. It takes a few minutes, so give the shell command a timeout of 600000 ms or run it in the background. Say in "How it was checked" that it passed.
   - CLAUDE.md › Commands: add rows for `pnpm test:soak` (the whole-game soaks: their own CI job, run before handing off a core, bots, card data or sim-cli change) and `pnpm test:perf` (core's perf tests alone; `pnpm test` runs them last). Add `soak` to the `scripts/check.sh` row.
   - `tools/sim-cli/README.md` › Tests: the new file names, the smoke test, and which script runs which file.

## Acceptance

- [ ] `scripts/check.sh` is green.
- [ ] `scripts/check.sh soak` is green.
- [ ] `pnpm --filter @chaosgrid/sim-cli test 2>&1 | grep -c soak` prints `0`: the quick tests don't run the soaks.
- [ ] `pnpm --filter @chaosgrid/core test 2>&1 | grep -c perf.test` prints `0`, and `pnpm --filter @chaosgrid/core test:perf` runs all three perf files.
- [ ] `git diff -M --stat main...HEAD -- tools/sim-cli/test` shows the three soak files as renames with no line changes.

## Out of scope

- The perf test files and their budgets. `projectiles/perf.test.ts` is in T-091's scope.
- Core's README. T-093 adds its Caches section at the same time.
- The soaks' game counts and timeouts.
- `apps/web` and the browser tests. T-068 adds its own CI step after this task.

## Notes

- From T-046's open questions 1 and 4 (2026-10-22). The human chose to run the perf tests alone and keep their budgets, and to move the long soaks to their own CI job.
- Check each Vitest flag on the pinned version (`pnpm --filter @chaosgrid/core exec vitest --help`). If a flag above doesn't exist, use the closest one that gives the same behaviour and say so in the PR.
- T-062 replaces `m2-done-when.soak.test.ts` with `m3-done-when.soak.test.ts` later, and T-068 adds the browser tests to `checks`. Both start from this task's root files and CI.
- No golden, no core code and no protocol change, so `PROTOCOL_VERSION` stays as it is.
