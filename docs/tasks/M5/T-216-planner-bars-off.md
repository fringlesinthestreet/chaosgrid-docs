---
id: T-216
title: Planner bars off while the game is balanced
milestone: M5
depends_on: []
branch: agent/T-216-planner-bars-off
model: sonnet
effort: medium
scope:
  - tools/sim-cli/test/planner-early-chaos.test.ts
  - tools/sim-cli/test/planner.soak.test.ts
  - tools/sim-cli/README.md
  - packages/bots/README.md
context:
  - docs/DECISIONS.md#Decision log
  - tools/sim-cli/README.md#Tests
  - packages/bots/README.md#The planner bot
---

# T-216 — Planner bars off while the game is balanced

## Goal

While the human balances the Chaos and the cards, no test requires the planner bot to beat the greedy bot (D77). Two tests do, and the planner's lead over greedy is thin, so a balance change keeps turning them red and the fix goes into the bots instead of the game. After this PR both are skipped and listed as skipped, the planner's games still play in both soak tiers, and the tests come back when the human balances the bots' difficulty levels.

## Interfaces

What exists on `main` (copied on 2026-11-08; grep the names, the lines move):

```ts
// tools/sim-cli/test/planner-early-chaos.test.ts, in pnpm test: 6 games of 4 rounds, the planner's
// seat rotating; per game expect(result.error).toBeNull(), then
// expect(planner).toBeGreaterThanOrEqual(greedy / 3)
describe('the planner bot in the early Chaos waves', () => {
  it('scores at least as many points as the average greedy seat, without an error',
    { timeout: 120_000 }, () => { … });
});

// tools/sim-cli/test/planner.soak.test.ts: beforeAll plays the matchup and prints each seat's
// share of wins
it('plays every seat without an error', …);                       // both tiers: stays
it.runIf(FULL_SOAK)('beats the average of three greedy bots', …);  // the full tier's bar
```

What the READMEs say about the bars:

- `tools/sim-cli/README.md` › Tests, the `test/planner.soak.test.ts` line: "Full: 40 games, and the planner must win more games than the average greedy seat (three times its wins above the greedy seats' total), about 6 minutes. It prints each seat's share of wins."
- `packages/bots/README.md` › The planner bot, the end of "What a preview can't see": "`tools/sim-cli/test/planner.soak.test.ts` checks that the planner beats the average greedy seat on seed 1."

## Deliverables

1. **The early-rounds test skipped.** `planner-early-chaos.test.ts`'s test becomes `it.skip`, so `pnpm test` lists it as skipped and no longer plays its 6 games. The quick soak still plays the planner's games and checks them for errors (`plays every seat without an error`).
2. **The full tier's bar skipped.** `planner.soak.test.ts`'s `it.runIf(FULL_SOAK)('beats the average of three greedy bots', …)` becomes `it.skip(…)`. Both tiers still play the games, check them for errors and print each seat's share of wins. The file's header comment says the full tier no longer checks the bar.
3. **One comment above each skipped test**, stating the rule and when it ends: skipped while the Chaos and the cards are balanced (D77), back when the bots' difficulty levels are balanced. It cites D77 and no task id (D73).
4. **The READMEs** no longer say these tests check the bar: the sim-cli line says the full tier prints the shares and its bar is skipped (D77), and the bots README's sentence says the bar is skipped too. Keep the measured numbers already there.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check perf` green
- [ ] `crew check soak` green
- [ ] `grep -rn "it.skip" tools/sim-cli/test` finds exactly the two skipped tests, and `grep -n "runIf(FULL_SOAK)('beats" tools/sim-cli/test/planner.soak.test.ts` finds nothing
- [ ] The PR gives `pnpm --filter @chaosgrid/sim-cli test`'s summary line, with its skipped count

## Out of scope

- Greedy's bar against random (`bot-skill.soak.test.ts`, D33): it stays.
- The planner's unit tests (`packages/bots/src/planner-bot.test.ts`): they check how it ranks stubbed previews, not whether it beats greedy, so they stay.
- The bots themselves: their candidates, budgets and styles get balanced later, with the difficulty levels.
- The full soak: the lead runs it on `main` after this wave (D75).

## Notes

- Skip, don't delete or loosen: the tests, their assertions and their bars stay as they are, so bringing one back is one word (D77).
- T-212 waits for this card, since its scope has both test files and the bots' README.
