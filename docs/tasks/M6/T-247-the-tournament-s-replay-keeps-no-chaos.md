---
id: T-247
title: The tournament's replay keeps --no-chaos
milestone: M6
depends_on: []
branch: agent/T-247-the-tournament-s-replay-keeps-no-chaos
model: sonnet
effort: low
scope:
  - tools/sim-cli/src/tournament.ts
  - tools/sim-cli/src/tournament.test.ts
  - tools/sim-cli/src/game.ts
  - tools/sim-cli/src/command.ts
  - tools/sim-cli/src/stats.ts
  - tools/sim-cli/src/stats.test.ts
context:
  - tools/sim-cli/README.md#Tournaments
  - tools/sim-cli/README.md#JSON report
---

# T-247 — The tournament's replay keeps --no-chaos

## Goal

A game that fails in `pnpm sim --tournament … --no-chaos` prints a replay command that plays it again without Chaos, as a plain run's does, so the replay reproduces the failure.

## Interfaces

On `main` (grep the names, the lines move).

- `replayCommand(setup: Omit<RunSetup, 'chaos' | 'tierStarts'> & { chaos?: boolean }, seed)` in `src/stats.ts`: adds `--no-chaos` only when `setup.chaos === false`.
- `playMatchup(lineup, options: SimOptions, cards, starters)` in `src/tournament.ts`: plays each game with `runGame(seed, { ...options, bots }, …)`, which honours `options.chaos`, and builds each error's `replay` with `replayCommand({ games, seed, bots, decks, rounds, target }, seed)`, without `chaos`.
- `GameResult.extraChaos?: number` in `src/game.ts`. `runGame` in `src/command.ts` builds a `GameResult` literal without it when choosing the decks throws, and `src/stats.ts` reads it as `result.extraChaos ?? 0`.

## Deliverables

1. **Replay.** `playMatchup` passes `options.chaos` to `replayCommand`, so a tournament run with `--no-chaos` prints replays ending in `--no-chaos`.
2. **`extraChaos` required.** `GameResult.extraChaos: number`; the deck-choice error's result in `command.ts` sets it to 0, and `stats.ts` reads it without a fallback.
3. **Tests:** `tournament.test.ts` checks that a failed game's replay ends in `--no-chaos` when the options have Chaos off, and has no `--no-chaos` when Chaos is on; `stats.test.ts`'s game builder sets `extraChaos`.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/sim-cli test tournament stats` green
- [ ] `pnpm test:perf` and `pnpm test:soak` green

## Out of scope

- The JSON report: tournaments don't write one, and its version stays 3.
- The README: it says a replay ends in `--no-chaos` when the run had no Chaos, which this makes true for tournaments.

## Notes

- A game fails without a broken core when choosing the decks throws: with `decks: 'starter'` and no starter decks, `chooseDecks` calls core's `pick` on an empty list, which throws, and `runGame` returns an error result. That gives the test a failed game.
- Keep `replayCommand`'s `chaos` optional if another caller has no setup with it; `playMatchup` passes it either way.
