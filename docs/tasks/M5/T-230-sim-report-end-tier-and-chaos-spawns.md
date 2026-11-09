---
id: T-230
title: Sim report: end tier and Chaos spawns
milestone: M5
depends_on: [T-206, T-229]
branch: agent/T-230-sim-report-end-tier-and-chaos-spawns
model: sonnet
effort: medium
scope:
  - tools/sim-cli/src/**
  - tools/sim-cli/README.md
context:
  - docs/balance/2026-11-08-baseline.md
  - tools/sim-cli/README.md
  - docs/RULES.md#Chaos deck and Emblems
---

# T-230 — Sim report: end tier and Chaos spawns

## Goal

The sim report shows neither the tier a game ends in nor the Chaos cards spawned a round, so a baseline cannot say which tier most games end in (D65, D76). After this PR the report prints both, and `--merge` adds them up across parts.

## Interfaces

The report and its merge are in `tools/sim-cli/src/` (`report.ts`, `cli.ts`, `game.ts`); read them for the existing line format. The tier and the spawn counts come from the events the sim already reads: add no field to the protocol.

## Deliverables

1. A line with the share of games that end in each tier, and a line with the mean and the median of Chaos cards spawned per round.
2. Both survive `--merge` of several parts (counts add up, medians recompute from merged counts), with tests, and the README names the new lines.

## Acceptance

- [ ] `crew check` and `pnpm test:soak` green
- [ ] `pnpm sim --merge <parts>` prints a tier line and a spawn line

## Out of scope

- Protocol changes. If the events lack what is needed, stop and ask the lead.

## Notes

Old report JSON files in `docs/balance/` lack the new fields: merging them prints "n/a" for the new lines instead of failing.
