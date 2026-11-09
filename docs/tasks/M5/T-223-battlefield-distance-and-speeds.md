---
id: T-223
title: Battlefield distance and speeds
milestone: M5
depends_on: [T-206, T-219]
branch: agent/T-223-battlefield-distance-and-speeds
model: opus
effort: high
scope:
  - packages/core/src/arena/**
  - packages/core/src/state/config.ts
  - packages/core/src/state/config.test.ts
  - packages/core/README.md
  - docs/balance/**
context:
  - docs/balance/2026-11-08-baseline.md
  - docs/RULES.md#Balance knobs and open questions
  - docs/CORE.md
  - tools/sim-cli/README.md
---

# T-223 — Battlefield distance and speeds

## Goal

First contact happens at second 1 (median) and second 2 (p90) in both runs (11-02: 2 and 5 to 6), and 48 generated rounds had no attack. Units reach each other almost at once, so movement and placement matter little. After this PR the median first contact is after second 3.

## Deliverables

1. Measure with sim runs which knob moves first contact: the gap between a grid and the Chaos Grid (RULES.md: 10 cells), the grid sizes or the unit speeds. Move the smallest one that gets the median past second 3 and the p90 no later than second 8.
2. Update the config, the tests and the README lines that name it; write `docs/balance/<date>-contact.md` with the runs that show it.

## Acceptance

- [ ] `crew check`, `pnpm test:perf` and `pnpm test:soak` green
- [ ] A sim run's report shows a median first contact after second 3

## Out of scope

- The point target (T-219) and card stats.

## Notes

Changing the gap or the grid sizes changes RULES.md and the layout: if it does, stop and ask the lead before editing it. Moving only a speed default stays inside this card.
