---
id: T-141
title: Test follow-ups
milestone: M4
depends_on: [T-112]
branch: agent/T-141-test-follow-ups
model: sonnet
effort: low
scope:
  - apps/web/src/host/host.test.ts
  - packages/protocol/src/plan.test.ts
  - packages/core/src/combat/perf.test.ts
context:
  - docs/APPS.md#Web layout and ownership
---

# T-141 — Test follow-ups

## Goal

Three small test fixes from the T-110 to T-118 handoffs (2026-10-30):

- `host/host.test.ts` › a human seat › "gets only what isVisibleTo lets it see" plays a whole game on Vitest's default 5 seconds. It's the only whole-game test in the file without its own timeout (T-105).
- `plan.test.ts` › "rejects %s" has a row for each retired plan action name, but none for v25's `discard`, which T-112 removed (protocol v26, D42).
- Core's combat `perf.test.ts`: the worst case has run 18,000 ticks (180 s) since T-110, but the file's header still says 10,000 ticks (100 s) and a 2 s target. Its 10 s limit is too tight for a loaded full run, so the human set a new limit of 20 s on 2026-10-30.

After this task each of the three tests checks what its text says, and the full run passes.

## Interfaces

What exists (copied from the code on 2026-10-30):

```ts
// apps/web/src/host/host.test.ts
describe('a bots-only match', () => {
  // :125 two whole games through the host, `}, 10_000);` at :132
  // :134 a whole game, then the same game through sim-cli's loop, `}, 30_000);` at :173
});
describe('a human seat', () => {
  // :177, seat 0 readies on every snapshot and the game plays to game.ended: no timeout (ends :199)
  it('gets only what isVisibleTo lets it see, in batches: newGame, begin, snapshot, round', async () => {
    …
    seat0.transport.onSnapshot(() => seat0.transport.send(ready(0)));
    host.start();
    await until(() => hasEnded(seat0.events()));
    …
  });
});

// packages/protocol/src/plan.test.ts:104, the retired and wrong action names
it.each([
  ['a v4 sorcery action', { action: 'castSorcery', card: 'c1' }],
  ['a v3 sorcery action', { action: 'queueSorcery', card: 'c1' }],
  ['a v3 ritual action', { action: 'castRitual', card: 'c1' }],
  ['a missing action', { card: 'c1' }],
  ['an action in the wrong case', { action: 'CastUnit', card: 'c1' }],
  ['a command type', { type: 'plan.submit', seat: 0, plan: [] }],
])('rejects %s', (_, input) => { … }); // each fails at ['action']

// packages/core/src/combat/perf.test.ts
// :12-20, the header: "… for all 10,000 ticks of the round timer (100 s). … Its target is under
// 2 s on a laptop too; its limit is generous so a busy CI machine passes."
it('keeps 120 units fighting for 18,000 ticks in good time', () => {
  …
  // About 6 seconds here (3 at 100 s); CI's thread is up to twice as slow.   :103
  expect(ms).toBeLessThan(10_000); //                                         :104
}, 30_000);
```

v25's plan action, removed by T-112: `{ action: 'discard', cards: CardInstanceId[] }`.

What this task adds: one timeout, one table row, and a new limit with its comments. Nothing else changes.

## Deliverables

1. **The host test's timeout.** Time `host.test.ts` alone, three runs: `pnpm --filter @chaosgrid/web test src/host/host.test.ts --reporter=verbose`. Give the test at :177 a timeout by T-103's rule, at least 5 times its slowest time. Use `30_000`, as the whole game at :173 does, unless 5 times its time is more. Pass it as the last argument (`}, 30_000);`).
2. **The v25 row.** Add `['a v25 discard action', { action: 'discard', cards: ['c1'] }]` to the "rejects %s" table, first, so the retired names read newest first. It fails at `['action']` like the other rows.
3. **The perf limit.** In `perf.test.ts`, `expect(ms).toBeLessThan(20_000)`. The timeout stays `30_000`, above the limit.
4. **The perf comments.** The header says 18,000 ticks (180 s), and its last sentence gives the new limit and why: about 6 s alone, and a loaded full run or CI's thread can be several times slower. The comment at :103 agrees with it. Keep the rest of the header.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm test:perf` passes.
- [ ] `pnpm --filter @chaosgrid/web test src/host/host.test.ts` and `pnpm --filter @chaosgrid/protocol test plan` pass.
- [ ] `grep -c "a v25 discard action" packages/protocol/src/plan.test.ts` prints 1.
- [ ] `grep -n "10,000\|(100 s)\|under 2 s on" packages/core/src/combat/perf.test.ts` prints nothing. The real round's "under 2 seconds" at :12 and in the test name at :81 stays.
- [ ] `git diff -U0 main...HEAD | grep '^[+-][^+-]'` shows only the timeout, the row, the limit and the comments: no test body changes.

## Out of scope

- Any other test's timeout or limit. If another test fails on time in the full run, list it in the PR with its time alone, and send `lead` a `request` naming its folder and that folder's owner (M4/README.md › Web layout and ownership).
- The perf scenario itself: 120 units, 180 s, nobody dies.

## Notes

- The PR lists the host test's time alone and the timeout it got, as T-105's PR did.
- Default: if the perf test takes much more than 6 s alone on this laptop, keep the 20 s limit and give the time in the PR.
