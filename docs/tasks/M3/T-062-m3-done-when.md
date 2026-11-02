---
id: T-062
title: 'M3 done-when: bot soak'
milestone: M3
depends_on: [T-061, T-065, T-097]
branch: agent/T-062-m3-done-when
model: sonnet
effort: high
scope:
  - tools/sim-cli/test/m3-done-when.soak.test.ts
  - tools/sim-cli/test/m2-done-when.soak.test.ts
  - tools/sim-cli/test/golden-script.ts
  - tools/sim-cli/test/golden.test.ts
  - tools/sim-cli/test/golden/**
  - tools/sim-cli/test/fixtures/golden/**
  - tools/sim-cli/README.md
  - packages/bots/src/greedy-bot.ts
  - packages/bots/src/greedy-bot.test.ts
  - packages/bots/src/turtle-bot.ts
  - packages/bots/src/turtle-bot.test.ts
  - packages/bots/test/fixtures/greedy.ts
  - packages/bots/test/fixtures/turtle.ts
  - packages/bots/README.md
  - packages/bots/src/pool.ts
  - packages/bots/src/pool.test.ts
  - packages/bots/src/draft.ts
  - packages/bots/src/draft.test.ts
  - tools/sim-cli/test/scripted.ts
context:
  - docs/PLAN.md#M3
  - docs/RULES.md#Simulation rules
  - docs/RULES.md#Card colors
  - docs/RULES.md#Non-unit permanents and spells
  - docs/RULES.md#Zone mechanics
  - docs/PROTOCOL.md#Events
  - packages/bots/README.md#The greedy bot
  - packages/bots/README.md#The turtle bot
  - tools/sim-cli/README.md#Tests
  - docs/RULES.md#Balance knobs
---

# T-062 — M3 done-when: bot soak

## Goal

Pin M3's done-when in tests (PLAN.md › M3). The M2 bots still meet M2's bars on the new rules: 4 seats on the new battlefield, with 100-card decks in all five colors. Every round's events form a valid timeline, and a golden round locks every new mechanic. Fix the bots where they break it, and report what the games say about speed and the balance knobs.

## Interfaces

What exists after T-061 and T-097:

```ts
// tools/sim-cli/src/command.ts:150
export function runGame(seed: string, options: SimOptions, cards: readonly Card[], starters: readonly Deck[],
  onEvents?: (events: readonly Event[]) => void): PlayedGame;
// onEvents gets each batch core returns: the game start, each round's Begin, and each played round.
// tools/sim-cli/test/m2-done-when.soak.test.ts: M2's one-bot tables and skill check (T-039).
// A soak (D31): only `pnpm test:soak` and CI's soak job run it, not `pnpm test` (T-092).
// packages/protocol: groupByTick(events) throws on a malformed timeline (T-045)
// tools/sim-cli/test/golden-script.ts: GOLDEN_SCRIPT (two scripted rounds), GOLDEN_CARDS_DIR
// (test/fixtures/golden/cards); golden.test.ts compares test/golden/round-<n>.json
// Mechanics: five colors (T-041), Plan abilities and rest (T-042), card colors and costChange
// (T-043), free-standing traps (T-044), the 4-player battlefield (T-047), the prize (T-048),
// banish, sacrifice and the void (T-049), dump, discard and revive (T-050), Shield, Extra life and
// Ward (T-051), fear (T-052), copy (T-053); deck rules: Unique and 4 copies (T-063)
// UnitSnapshot.keywords: printed plus granted (T-064); the M3 rulings in core, D34 (T-097)
```

Nothing new is exported.

## Deliverables

1. `tools/sim-cli/test/m3-done-when.soak.test.ts` replaces `m2-done-when.soak.test.ts`. It's a soak too (D31), so `pnpm test` doesn't run it. It has the same one-bot tables, all at 4 seats since T-047, and the same skill check, plus:
   - Every played round's batch passes `groupByTick` without throwing. Collect the batches with `runGame`'s `onEvents`.
   - Over each deck source's games, the Leaders' colors cover all five colors.
   - A failure message names the table, the game's seed, and the reasons, the error or the timeline problem.
   - Aim for under 3 minutes in total. If it runs slower, play fewer games per table, never fewer tables, and say so in the PR.
2. Golden round 3: add a third round to `GOLDEN_SCRIPT` that uses each new mechanic at least once, with new cards in `test/fixtures/golden/cards`. If one round can't hold them all, add as many rounds as it takes. You may add cards to the golden decks and resource decks so the new cards get drawn.
   - banishes from the grid (with `chosenEnemyUnit`, one with `scores` and one without), from a discard pile and from a hand, and a sacrifice
   - a dump, a discard by an effect, a revive during Plan and one during Simulate
   - a Shield that absorbs damage, an Extra life that saves a unit, and a Ward that turns a `nearestEnemy` away
   - a unit that rests itself for a Plan ability, and an enemy spell that rests a unit
   - a fear that makes a unit walk away and then retarget, and a trap's fear with the `sourceArea` zone, which flees from the middle of the trap's cells (no test plays it yet)
   - a Plan copy with a new `copyTarget`, and a trap that copies an enemy spell back at its caster
   - a prize that takes damage, and one that's destroyed for points
   - a `color` filter that skips a Colorless unit, and a `costChange` that the next round's costs show
   - a cost with an `E`, `D` or `L` pip
   - a Chaos squad that spawns on the Chaos Grid's edge facing its seat
   Store each round as `test/golden/round-<n>.json`, and have `golden.test.ts` check it.
3. Bot fixes, in the greedy, turtle, pool and draft files only, until the tests pass. Every fix that makes a rejection go away gets a unit test. Keep each bot's character, and don't tune for win rates.
4. `tools/sim-cli/README.md` › Tests: the new test and how long it takes, and the golden rounds. `packages/bots/README.md`: the decision tables, if a fix changed them.
5. In the PR body, reported and not gated:
   - seconds per game for `pnpm sim --bots greedy,greedy,greedy,greedy --games 20 --seed 1 --decks starter`
   - the median tick of each round's first `unit.attacked`, from a `--log` of the same command
   - the table from `pnpm sim --tournament greedy,turtle,random --games 100 --seed 1 --decks starter` (every matchup fills the 4 seats by repeating its lineup, T-047)
   - prize points per game, and how many prizes were destroyed per game
   - one line per balance knob (RULES.md › Balance knobs and open questions) that the numbers make look off

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `scripts/check.sh soak` green
- [ ] `pnpm --filter @chaosgrid/sim-cli exec vitest run m3-done-when` passes
- [ ] `pnpm --filter @chaosgrid/sim-cli test -- golden` passes, with a `round-<n>.json` for every scripted round
- [ ] `pnpm --filter @chaosgrid/bots test` passes, with a test for every rejection the bots no longer make

## Out of scope

- Win-rate targets between the bots
- Changing rules, cards or balance knobs: they belong to M5. Only report them.
- Core, the random bot, `placement.ts` and the tournament code. If you need a change there, send `lead` a `request`.

## Notes

- M3's test checks everything M2's does, so delete `m2-done-when.soak.test.ts` and its README line: CI's soak job shouldn't play the tables twice.
- A timeline that `groupByTick` refuses is a core bug, not a bot bug. Send `lead` a `request` with the game's seed.
- If round 3's new cards change rounds 1 and 2 (for example by changing the draws), regenerate those files too and say why in one line in the PR.
- Same advice as T-039: replay one game with `--log`, read its `plan.rejected` events, and try fixes on fewer games first.
- A `forbidden` rejection counts like any other (human, 2026-10-27). T-099 makes the bots respect `noSpells` from `Snapshot.rules`, so one that's left is a bot bug to fix here, not one for the test to tolerate.
