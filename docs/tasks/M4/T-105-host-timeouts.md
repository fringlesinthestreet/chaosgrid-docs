---
id: T-105
title: Timeouts for the host's whole-game tests
milestone: M4
depends_on: [T-080]
branch: agent/T-105-host-timeouts
model: sonnet
effort: low
scope:
  - apps/web/src/host/host.test.ts
  - apps/web/src/match/session.test.ts
context:
  - docs/tasks/M4/README.md#Web layout and ownership
---

# T-105 — Timeouts for the host's whole-game tests

## Goal

`scripts/check.sh` fails for web tasks on this laptop (T-085's handoff, 2026-10-28). In the full test run, `src/host/host.test.ts` › a bots-only match › "plays the game sim-cli's loop plays" goes over Vitest's default 5 seconds. It takes about 3.9 s alone, but `pnpm test` runs several packages' tests at once (`pnpm -r`), and a test that keeps a CPU busy runs slower there. After this task the file's slow tests have their own timeouts, by T-103's rule (at least 5 times their time alone), and the full run passes.

## Interfaces

What exists (copied from the code on 2026-10-28):

```ts
// apps/web/src/host/host.test.ts, every test on Vitest's default timeout (5 s)
/** Steps one microtask at a time until `done()` holds, so a game that never ends can't hang. */
async function until(done: () => boolean, steps = 2000): Promise<void>; // :65, counts microtasks, not time

describe('a bots-only match', () => {
  // :125, two whole games through the host: not timed yet
  it('plays to game.ended within 100 rounds, and the same setup plays the same game', async () => { … });
  // :134, a whole game through the host, then the same game through sim-cli's loop: about 3.9 s alone
  it("plays the game sim-cli's loop plays (game.ts: newGame, beginRound, botSeed bots, playRound)", async () => { … });
});
// :167 'a human seat' (7 tests) and :387 'setup' (3 tests): not timed yet
```

What this task adds: timeouts in `host.test.ts`, and nothing else.

## Deliverables

1. **Time the file** alone, three runs: `pnpm --filter @chaosgrid/web test src/host/host.test.ts --reporter=verbose`. Take each test's slowest time.
2. **Timeouts.** Give each test that takes more than a second a timeout of at least 5 times its slowest time (3.9 s → `20_000` or more). Pass it as the last argument (`}, 30_000);`), as core's `round/round.test.ts` does (T-103). A test under a second keeps the default.
3. **The full run.** Run `scripts/check.sh test` three times. A test in this file that still fails on time gets 10 times its time alone; say which in the PR.

## Acceptance

- [ ] `scripts/check.sh` is green, three runs in a row.
- [ ] In `pnpm --filter @chaosgrid/web test src/host/host.test.ts --reporter=verbose`, every test that takes more than a second has a timeout of at least 5 times its time.
- [ ] `git diff -U0 main...HEAD -- apps/web | grep '^[+-][^+-]'` shows only timeouts: no test body changes.

## Out of scope

- Any other test file, and `vitest.config.ts`: one `testTimeout` for every web test would hide the next slow one. If another web test takes more than a second alone, or fails on time in the full run, list it in the PR with its time, and send `lead` a `request` naming its folder and that folder's owner (M4/README.md › Web layout and ownership).
- Shorter games or a faster host: each test keeps what it plays.

## Notes

- The PR lists each test's time alone and the timeout it got, as T-103's card lists its tests.
- Default: a test that takes more than a second in some runs and less in others gets a timeout.
