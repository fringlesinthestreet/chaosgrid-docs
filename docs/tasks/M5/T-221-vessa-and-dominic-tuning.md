---
id: T-221
title: Vessa and Dominic tuning
milestone: M5
depends_on: [T-206, T-220]
branch: agent/T-221-vessa-and-dominic-tuning
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

# T-221 — Vessa and Dominic tuning

## Goal

In the generated run Vessa Twinflame wins 41.6% of 317 seats (36.3% to 47.1%) and Dominic Fire Marshal 40.5% of 338 (35.4% to 45.8%), both intervals above 35%. Kettle at 38.8% is not settled. After this PR a generated baseline puts both under 35%.

## Deliverables

1. Tune the two Leaders, changing as few numbers as it takes, and leave Kettle alone unless the rerun puts its interval wholly above 35%.
2. Rerun the generated baseline at the point target main has then, T-206's sizing, and write `docs/balance/<date>-vessa-dominic.md` with before and after.

## Acceptance

- [ ] `crew check` and `pnpm cards:validate` green
- [ ] The generated run's report shows Vessa and Dominic under 35% of seats

## Out of scope

- Per-card findings (T-222 and later).

## Notes

Tuning cards share `packages/cards/data/**`: one after another, not in one wave.
