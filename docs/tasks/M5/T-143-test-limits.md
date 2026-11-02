---
id: T-143
title: Test limits under load
milestone: M5
depends_on: []
branch: agent/T-143-test-limits
model: haiku
effort: medium
scope:
  - packages/core/src/round/perf.test.ts
  - apps/web/src/host/host.test.ts
context:
  - docs/APPS.md#Web layout and ownership
---

# T-143 — Test limits under load

## Goal

Two test files come close to their time limits when the machine is busy, though the code didn't get slower (the T-129, T-135 and T-140 handoffs):

- Core's `round/perf.test.ts` (T-129): the 120-unit round capped at half its length takes about 0.85 s against a 1 s limit. `test:perf` retries once, which hides a miss.
- The web's `host/host.test.ts`: the two whole games at :125 run on a 10 s timeout, and so do six shorter tests.

On 2026-11-02 the human chose to give both files more room instead of making bot planning cheaper, which would weaken the bots. After this task each preview limit is twice what it was, and every 10 s timeout in `host.test.ts` is 30 s, as its other whole-game tests already have.

## Interfaces

What exists (copied from the code on 2026-11-02):

```ts
// packages/core/src/round/perf.test.ts, describe('preview performance')
it('previews the 120-unit round to its end in under 2 seconds', () => {
  …
  expect(ms).toBeLessThan(2000); //                     :82
}, 30_000); //                                          :70-83
it('stops the 120-unit round at half its length in under 1 second', () => {
  …
  expect(ms).toBeLessThan(1000); //                     :95
}, 30_000); //                                          :85-96
it('previews 3,000 ticks of the busiest scripted snapshot in under 1 second', () => {
  …
  expect(long.ms).toBeLessThan(1000); //                :118
}, 120_000); //                                         :98-119

// apps/web/src/host/host.test.ts: `}, 10_000);` closes these tests
//   :125 a bots-only match › "plays to game.ended within 100 rounds, and the same setup plays the same game" (:132)
//   :291 a human seat › "ignores another seat's command, one after the seat's player.ready, and any after game.ended" (:331)
//   Cleanup's Discard step › the five tests from :441 to :490 (:449, :460, :476, :488, :496)
// The tests at :134 and :177 already end in `}, 30_000);`.
```

What this task changes: three limits, two test names and seven timeouts. No test body.

## Deliverables

1. **The preview limits.** In `round/perf.test.ts`, `toBeLessThan(2000)` becomes `4000`, and both `toBeLessThan(1000)` become `2000`. The names say the new limits: "in under 4 seconds" for the uncapped round, "in under 2 seconds" for the other two. The timeouts (`30_000`, `120_000`) and the console lines stay.
2. **The host timeouts.** Every `}, 10_000);` in `host.test.ts` becomes `}, 30_000);`.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/core test:perf` passes.
- [ ] `pnpm --filter @chaosgrid/web test src/host/host.test.ts` passes.
- [ ] `grep -c "10_000" apps/web/src/host/host.test.ts` prints 0, and `grep -c "toBeLessThan(1000)" packages/core/src/round/perf.test.ts` prints 0.
- [ ] `git diff -U0 origin/main...HEAD | grep '^[+-][^+-]'` shows only the limits, the two names and the timeouts.

## Out of scope

- What bot planning costs, and the preview budget (`PreviewBudget`) T-129 set from these times.
- Core's other perf tests, and any other test's timeout. If another test fails on time in the full run, list it in the PR with its time alone, and send `lead` a `request` naming its folder.

## Notes

- This loosening is the human's call (2026-11-02), not a precedent: a worker never loosens a test to make it pass on its own.
- The uncapped round's limit doubles too. It plays about twice the ticks of the capped one, so it has the same small margin.
- The PR gives each preview's time from the console lines, and how long `host.test.ts` takes alone.
- T-135 and T-137 edit `host.test.ts` after this, so T-135 waits for this card.
