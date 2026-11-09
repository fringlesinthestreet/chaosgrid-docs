---
id: T-225
title: Tune light cards
milestone: M5
depends_on: [T-206, T-229, T-222]
branch: agent/T-225-tune-light-cards
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

# T-225 — Tune light cards

## Goal

`judgment_angel` wins 63.9% when played (294 plays; 67.7% in starter decks). `second_chance`, `radiant_purge` and `purging_light` are played in under 10% of draws, which may be a bot gap (T-229). After this PR a generated run shows no light card above 45% when played.

## Deliverables

1. Tune `judgment_angel`, changing as few numbers as it takes. For the three rarely played cards, first check the rerun after T-229: change a card only if it is still unplayed because of its cost or text, and say which in the write-up.
2. Rerun the generated baseline and write `docs/balance/<date>-light.md` with before and after.

## Acceptance

- [ ] `crew check` and `pnpm cards:validate` green
- [ ] The generated run's card list shows no light card above 45% when played

## Out of scope

- Other elements; the bot's play rules (T-229).

## Notes

Tuning cards run one after another.
