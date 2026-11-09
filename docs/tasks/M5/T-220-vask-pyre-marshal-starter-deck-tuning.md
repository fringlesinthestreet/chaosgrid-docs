---
id: T-220
title: Vask Pyre Marshal starter deck tuning
milestone: M5
depends_on: [T-206, T-219]
branch: agent/T-220-vask-pyre-marshal-starter-deck-tuning
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

# T-220 — Vask Pyre Marshal starter deck tuning

## Goal

Vask Pyre Marshal wins 53.6% of 343 starter seats (48.4% to 58.9%, wholly above 35%; 55.4% on 11-02). After this PR the starter baseline puts Vask under 35%.

## Deliverables

1. Tune Vask's starter deck and the cards that drive it (the ember cards `flare_sprite`, `spark_skirmisher` and `ember_imps` win 62% to 70% in starter decks), changing as few numbers as it takes.
2. Rerun the starter baseline at the point target main has then, T-206's sizing, and write `docs/balance/<date>-vask.md` with before and after.

## Acceptance

- [ ] `crew check` and `pnpm cards:validate` green
- [ ] The starter run's report shows Vask under 35% of seats

## Out of scope

- The generated-deck findings (T-222 and later). Cards that also appear in them are changed only as far as Vask needs.

## Notes

Cards are JSON files, never the DB. Tuning cards share `packages/cards/data/**`, so they run one after another, not in one wave. The Leaders' part in the ember win rates is part of this task.
