---
id: T-095
title: sim-cli slow test timeouts
milestone: M3
depends_on: []
branch: agent/T-095-sim-cli-timeouts
model: haiku
effort: low
scope:
  - tools/sim-cli/src/command.test.ts
  - tools/sim-cli/src/game.test.ts
context:
  - tools/sim-cli/README.md#Tests
---

# T-095 — sim-cli slow test timeouts

## Goal

Since T-047 every game has 4 seats, and a game takes 5 to 7 seconds on this laptop. Two tests in `pnpm test` play whole games with Vitest's default timeout of 5 seconds, so they fail locally when the code is fine. Give them the timeout that `tournament.test.ts` already uses.

## Interfaces

What exists (copied from the code on 2026-10-26):

```ts
// tools/sim-cli/src/command.test.ts:138, no timeout
it("saves the first game's events with --log, each one a protocol Event", () => { … });
// tools/sim-cli/src/game.test.ts:50, no timeout
it('plays the same game for the same seed (D8)', () => { … });
// tools/sim-cli/src/tournament.test.ts:43-53: the pattern to copy
it('accounts for every game, deterministically', () => { … }, 30_000);
```

## Deliverables

1. Pass `30_000` as the last argument of the two tests above, the way `tournament.test.ts` does.
2. Time every other test in the two files (`pnpm --filter @chaosgrid/sim-cli exec vitest run command game --reporter=verbose`). Give any that takes more than 2 seconds the same timeout, and list them in the PR.

## Acceptance

- [ ] `scripts/check.sh` is green.
- [ ] `pnpm --filter @chaosgrid/sim-cli exec vitest run command game` passes.
- [ ] `git diff -U0 main...HEAD | grep '^[+-][^+-]'` shows only lines that add a timeout: no test body changes.

## Out of scope

- Fewer games or rounds in a test, and any change to what a test checks.
- The soaks (`*.soak.test.ts`, D31) and the golden test.
- Making games faster.

## Notes

- From the merged M3 tasks' open questions (2026-10-26): "two sim-cli tests (command --log, game same seed) time out at 5 s locally; games take 5-7 s." T-059's worker saw the `--log` test time out on `main` too, so it's the machine's speed, not a branch.
- T-061 changes these two files too (its scope has `tools/sim-cli/src/**/*.test.ts`), so it waits for this task.
