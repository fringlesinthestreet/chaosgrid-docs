---
id: T-151
title: sim-cli test limits under load
milestone: M5
depends_on: []
branch: agent/T-151-sim-cli-test-limits
model: haiku
effort: medium
scope:
  - tools/sim-cli/src/command.test.ts
  - tools/sim-cli/src/game.test.ts
  - tools/sim-cli/src/game-discards.test.ts
  - tools/sim-cli/src/tournament.test.ts
  - tools/sim-cli/test/smoke.test.ts
  - tools/sim-cli/test/snapshot-positions.test.ts
context: []
---

# T-151 — sim-cli test limits under load

## Goal

A handoff reported a sim-cli test timing out while the machine was busy, though the code hadn't got slower. T-143 gave core's perf tests and `host.test.ts` more room but not sim-cli. On an otherwise idle machine on 2026-11-03, the `--log` test in `command.test.ts` took 29 s of its 60 s limit, and the tournament test took 41 s of its 120 s.

On 2026-11-03 the human chose to give these tests more room. After this task, every explicit time limit in sim-cli's regular tests is twice what it was.

## Interfaces

What exists (counted on 2026-11-03), 18 limits in all:

| File | `}, 30_000);` | `}, 60_000);` | `}, 120_000);` | `{ timeout: 120_000 }` |
| --- | --- | --- | --- | --- |
| `src/command.test.ts` | 5 | 3 | 1 | |
| `src/game.test.ts` | 2 | 1 | 1 | |
| `src/game-discards.test.ts` | | 1 | | |
| `src/tournament.test.ts` | 1 | | 1 | |
| `test/smoke.test.ts` | | | | 1 |
| `test/snapshot-positions.test.ts` | | | | 1 |

What this task changes: those 18 numbers. No test body and no test name.

## Deliverables

1. In the six files above, 120,000 becomes 240,000, then 60,000 becomes 120,000, then 30,000 becomes 60,000. Work in that order, largest first, or a 30,000 doubles twice.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/sim-cli test command tournament game smoke snapshot-positions` passes.
- [ ] `grep -c "30_000" tools/sim-cli/src/command.test.ts tools/sim-cli/src/game.test.ts tools/sim-cli/src/tournament.test.ts` prints 0 for each file.
- [ ] `grep -c "240_000" tools/sim-cli/src/command.test.ts tools/sim-cli/src/game.test.ts tools/sim-cli/src/tournament.test.ts tools/sim-cli/test/smoke.test.ts tools/sim-cli/test/snapshot-positions.test.ts` prints 1 for each file.
- [ ] `git diff -U0 origin/main...HEAD | grep -c '^+[^+]'` prints 18.

## Out of scope

- The soak and perf tests (`*.soak.test.ts`, `*.perf.test.ts`), and any test without an explicit limit. If another test fails on time in the full run, list it in the PR with its time alone, and send `lead` a `request` naming its folder.
- What the tests cost, and the game code they run.

## Notes

- This loosening is the human's call (2026-11-03), not a precedent: a worker never loosens a test to make it pass on its own.
