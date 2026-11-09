---
id: T-222
title: Tune ember cards
milestone: M5
depends_on: [T-206, T-221]
branch: agent/T-222-tune-ember-cards
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

# T-222 — Tune ember cards

## Goal

`flare_sprite` wins 58.1% when played (351 plays) and `phoenix_whelp` 57.6% (342). In starter decks `flare_sprite` is at 70.3%, `spark_skirmisher` 70.0% and `ember_imps` 62.3%, partly the Leaders (T-220, T-221). After this PR no ember card is above 45% when played in the generated run.

## Deliverables

1. Tune the ember cards, changing as few numbers as it takes. Start from the state after T-220 and T-221: those may already have moved the starter figures.
2. Rerun the generated baseline (T-206's sizing) and write `docs/balance/<date>-ember.md` with before and after.

## Acceptance

- [ ] `crew check` and `pnpm cards:validate` green
- [ ] The generated run's card list shows no ember card above 45% when played

## Out of scope

- Other elements (T-225 to T-228).

## Notes

Cards are JSON, never the DB. Tuning cards run one after another.
