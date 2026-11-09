---
id: T-224
title: Opening hands with nothing castable
milestone: M5
depends_on: [T-206]
branch: agent/T-224-opening-hands-with-nothing-castable
model: opus
effort: high
scope:
  - packages/core/src/zones/**
  - packages/core/src/round/**
  - packages/bots/src/draft.ts
  - packages/bots/src/draft.test.ts
  - packages/cards/data/**
  - docs/balance/**
context:
  - docs/balance/2026-11-08-baseline.md
  - docs/balance/2026-11-02-baseline.md
  - docs/RULES.md#Balance knobs and open questions
  - tools/sim-cli/README.md
---

# T-224 — Opening hands with nothing castable

## Goal

12.6% of starter opening hands (222 of 1764) and 12.8% of generated ones (855 of 6660) have nothing castable, over the 10% limit. On 11-02 it was 0.0% and 0.5%. The cause is not found. After this PR the sim report says under 10% for both runs.

## Deliverables

1. Find the cause: bisect between the 11-02 baseline's main and now (the Chaos, Unique, colorless and removal cards, the draw and mulligan rules, the bots' draft), with a test that fails on it.
2. Fix it in the smallest place. If the fix is a rule or a card change rather than a defect, stop and ask the lead.
3. Rerun both baselines (T-206's sizing) and add the result to `docs/balance/<date>-opening-hands.md`.

## Acceptance

- [ ] `crew check`, `pnpm test:perf` and `pnpm test:soak` green
- [ ] Both runs' reports show nothing-castable hands under 10%

## Out of scope

- Card tuning (T-220 to T-228).

## Notes

A "castable" hand is the report's definition; read it in sim-cli's README first.
