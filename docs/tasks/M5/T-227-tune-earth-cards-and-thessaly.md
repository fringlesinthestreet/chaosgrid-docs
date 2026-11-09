---
id: T-227
title: Tune earth cards and Thessaly
milestone: M5
depends_on: [T-206, T-226]
branch: agent/T-227-tune-earth-cards-and-thessaly
model: sonnet
effort: medium
scope:
  - packages/cards/data/**
  - packages/cards/stats/**
  - docs/balance/**
context:
  - docs/balance/2026-11-08-baseline.md
  - docs/tasks/M5/T-139-balance-baseline.md
  - packages/cards/README.md
---

# T-227 — Tune earth cards and Thessaly

## Goal

`stone_skin` (9.8%), `thornfield` (9.7%) and `overgrowth` (9.9%) win about one game in ten when played. Thessaly wins 11.3% of generated seats (8.5% to 15.0%) and 12.9% of starter seats. After this PR Thessaly is above 15% in both runs and no earth card is below 15% when played.

## Deliverables

1. Tune the three cards and Thessaly, changing as few numbers as it takes.
2. Rerun both baselines (T-206's sizing) and write `docs/balance/<date>-earth.md` with before and after.

## Acceptance

- [ ] `crew check` and `pnpm cards:validate` green
- [ ] Thessaly above 15% of seats in the generated and the starter runs

## Out of scope

- Other elements.

## Notes

Tuning cards run one after another. Check the rerun after T-229 first: if the cards are weak only because the bot misplays them, report that instead.
