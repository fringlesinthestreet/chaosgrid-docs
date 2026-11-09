---
id: T-228
title: Tune tide cards
milestone: M5
depends_on: [T-206, T-227]
branch: agent/T-228-tune-tide-cards
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

# T-228 — Tune tide cards

## Goal

`seer_s_lens` (8.6%, 58 plays), `mirror_snare` (9.7%, 124) and `chilling_tide` (10.0%, 50) win about one game in ten when played, and `resonance` is played in 8% of draws. After this PR a generated run shows no tide card below 15% when played.

## Deliverables

1. Tune the three cards, changing as few numbers as it takes; for `resonance`, say whether it is a cost or text problem or a bot gap (T-229).
2. Rerun the generated baseline and write `docs/balance/<date>-tide.md` with before and after.

## Acceptance

- [ ] `crew check` and `pnpm cards:validate` green
- [ ] The generated run's card list shows no tide card below 15% when played

## Out of scope

- Other elements; the bot's play rules (T-229).

## Notes

Tuning cards run one after another.
