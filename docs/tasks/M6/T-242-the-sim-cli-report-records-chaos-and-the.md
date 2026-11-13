---
id: T-242
title: The sim-cli report records Chaos and the final tier
milestone: M6
depends_on: [T-229, T-236]
branch: agent/T-242-the-sim-cli-report-records-chaos-and-the
model: sonnet
effort: medium
scope:
  - tools/sim-cli/src/**
  - tools/sim-cli/README.md
  - tools/sim-cli/test/smoke.test.ts
context:
  - docs/RULES.md#Chaos deck and Emblems
  - docs/DECISIONS.md#Decision log
  - tools/sim-cli/README.md
---

# T-242 — The sim-cli report records Chaos and the final tier

## Goal

A sim-cli report says whether its games had Chaos and in which tier they ended, so `--merge` never adds a Chaos-off run to a Chaos run, and the balance baseline (T-233) can say which tier most games end in without working it out by hand.

## Interfaces

On `main` (grep the names, the lines move).

- `tools/sim-cli/src/report.ts`: `JsonSetup { bots, decks, rounds, target, runs }`, `JsonReport { version: 1, setup, summary }`, `toJsonReport`, `formatJsonReport` (the text report) and `mergeReports(reports)`, which sums the summaries (`mergeSummaries` in `stats.ts`).
- `tools/sim-cli/src/stats.ts`: `Summary` has `lengths: Record<number, number>` (games per final round), `ends: Record<EndReason, number>`, `pointsByReason`, …
- `tools/sim-cli/src/game.ts`: `GameOptions.chaos?: boolean` (`--no-chaos`, D82) and the `config` it passes to core, whose `chaosTierStarts` defaults to `[1, 6, 11]`.
- `tools/sim-cli/src/command.ts` builds the `JsonSetup` and runs `--merge`.

## Deliverables

1. `JsonSetup` gains `chaos: boolean` and `tierStarts: [number, number, number]`, from the options and the config the run used. `JsonReport.version` becomes 2; `--merge` still reads version 1 files, taking `chaos: true` and `[1, 6, 11]` for them.
2. `mergeReports` throws, naming the field, when two reports disagree on `chaos` or `tierStarts`.
3. The text report prints, after the round figures, how many games ended in each tier, from `lengths` and `tierStarts`: "Ended in tier 1: 12% · tier 2: 61% · tier 3: 27%". With Chaos off it prints "Chaos: off" instead.
4. The README's report section follows.
5. **Tests** (`report.test.ts`, `command.test.ts`): a `--no-chaos` run writes `chaos: false`; merging a Chaos run with a Chaos-off one throws; a version 1 file merges as Chaos on; the tier line from a known `lengths`.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm sim --seed 1 --games 2 --json /tmp/a.json && pnpm sim --merge /tmp/a.json` prints the tier line

## Out of scope

- The balance write-up (T-233) and any tuning.
- The golden streams and the soak tests.

## Notes

- Tier boundaries come from the config the run used, never from RULES.md's defaults, so a run with other `chaosTierStarts` reports itself right.
