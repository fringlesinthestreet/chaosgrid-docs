---
id: T-246
title: Mana spent and Extra Chaos in the sim-cli report
milestone: M6
depends_on: []
branch: agent/T-246-mana-spent-and-extra-chaos-in-the-sim-cl
model: sonnet
effort: medium
scope:
  - tools/sim-cli/src/game.ts
  - tools/sim-cli/src/game.test.ts
  - tools/sim-cli/src/stats.ts
  - tools/sim-cli/src/stats.test.ts
  - tools/sim-cli/src/report.ts
  - tools/sim-cli/src/report.test.ts
  - tools/sim-cli/README.md
  - tools/sim-cli/test/smoke.test.ts
context:
  - tools/sim-cli/README.md#Usage
  - tools/sim-cli/README.md#JSON report
---

# T-246 — Mana spent and Extra Chaos in the sim-cli report

## Goal

A balance run reports how much mana the seats spend as a game goes on, and how often Extra Chaos comes, so the next baseline can read the economy (D60, D83) and the Chaos pressure (D80) without hand counts.

## Interfaces

On `main` (grep the names, the lines move).

- `recordPlan(seatRecord, state, seat, snapshot, plan, firstRound)` in `src/game.ts`: runs `checkPlan(state, seat, plan)` (core) and adds what the Plan left to the seat's record (`unspentResources`: the floating mana left, `cardsInHand`). `checkPlan` returns a `plan.checked` event: the seat's snapshot after its plan, and the actions `playRound` would refuse.
- `SeatRecord` (`game.ts`) and `Summary` (`stats.ts`): `plans: { count, unspentResources, cardsInHand }`, `lengths`, `ends`, `firstContact`; `mergeSummaries` adds two summaries; the text report prints `plans … mana unspent …`.
- `ChaosRevealedEvent` (`chaos.revealed`): `cardId`, `kind`, `extra: boolean` ("Drawn on top of the round's normal draw").
- `report.ts`: `JsonReport { version: 2, setup, summary }`, `toJsonReport`, `mergeReports` (refuses to merge setups that disagree), `parseJsonReport`, which reads version 1 and 2; `tierLine` prints `Chaos: off`.
- `replayCommand(setup: Omit<RunSetup, 'chaos' | 'tierStarts'>, seed)` in `stats.ts`: the command that replays one game; it never adds `--no-chaos`.

## Deliverables

1. **Mana spent.** For each round a seat plans, the mana spent is the mana value of every cost its accepted actions paid: casts, level-ups and Plan abilities. `Summary` keeps the total and the seat-Plans counted for each round number, and the text report prints the mean for rounds 1, 3, 5 and 10, for example `mana spent a round: r1 1.4 · r3 2.6 · r5 3.1 · r10 4.0`, with `—` for a round no game reached.
2. **Extra Chaos.** `Summary` counts the Extra Chaos cards revealed (`chaos.revealed` with `extra: true`) and the games they came in; the text report prints them with the share of games that had at least one, and `Chaos: off` stays as it is.
3. **JSON.** `JsonReport.version` 3 with both figures. A version 1 or 2 report reads with the figures missing, `mergeReports` refuses to merge a report without them with one that has them, and the text report says `not recorded` when a merged report has none.
4. **Replay.** `replayCommand` adds `--no-chaos` when the run played without Chaos.
5. **Docs.** The README's JSON report section lists the new fields and version 3.
6. **Tests:** `stats.test.ts` sums mana spent and Extra Chaos across two games and merges them; `report.test.ts` reads a version 2 report and refuses the mixed merge; `game.test.ts` records the mana a scripted plan paid; a replay command with Chaos off ends in `--no-chaos`; `smoke.test.ts` checks both lines of the text report.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/sim-cli test stats report game smoke` green
- [ ] `pnpm sim --games 4 --seed 1` prints the mana spent and the Extra Chaos lines
- [ ] `pnpm test:perf` and `pnpm test:soak` green

## Out of scope

- Core and the bots: everything here is read from what core already returns.
- The balance write-up in `docs/balance/`: the next baseline uses the figures.
- The golden streams: nothing here changes a game.

## Notes

- `tierStarts` comes from core's `DEFAULT_CONFIG` because sim-cli never overrides it; leave it.
- A Plan's mana spent counts what its accepted actions paid, so mana a resource or an ability added and the Plan spent counts once. Read the accepted actions from `checkPlan`'s refusals, and the costs from the snapshot's cards; if core's payment can't be read that way, ask the lead before computing it another way.
