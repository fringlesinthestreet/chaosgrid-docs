---
id: T-226
title: Tune dark cards
milestone: M5
depends_on: [T-206, T-229, T-225]
branch: agent/T-226-tune-dark-cards
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

# T-226 — Tune dark cards

## Goal

`soul_drain` wins 46.7% when played (30 plays). `dark_bargain` (18 plays in 274 draws), `raise_dead` (24 of 283), `oblivion` (25 of 286) and `grave_hex` (28 of 269) are played in under 10% of draws, likely a bot gap (T-229). After this PR a generated run shows no dark card above 45% when played.

## Deliverables

1. Tune `soul_drain`. For the four rarely played cards, check the rerun after T-229 first, and change one only if it is still unplayed because of its cost or text, saying which in the write-up.
2. Rerun the generated baseline and write `docs/balance/<date>-dark.md` with before and after.

## Acceptance

- [ ] `crew check` and `pnpm cards:validate` green
- [ ] The generated run's card list shows no dark card above 45% when played

## Out of scope

- Other elements; the bot's play rules (T-229).

## Notes

Thirty plays is a small sample: report the interval and tune only if it stays above 45%.
