---
id: T-204
title: Preview cost with the bigger Chaos waves
milestone: M5
depends_on: [T-183]
branch: agent/T-204-preview-cost-with-the-bigger-chaos-waves
model: sonnet
effort: high
scope:
  - packages/core/src/round/**
  - packages/bots/**
context:
  - docs/CORE.md
  - packages/core/README.md
---

# T-204 — Preview cost with the bigger Chaos waves

## Goal

After T-183 the Chaos factor makes rounds 5 to 8 hold far more Chaos units, and one round preview costs about 2.7x more. The perf test "previews 3,000 ticks of the busiest scripted snapshot in under 2 seconds" in `packages/core/src/round/perf.test.ts` takes 5.5 to 5.9 s against its 2 s limit. Bring the cost back under the bound, or set a new preview budget on purpose.

## Interfaces

The test is `packages/core/src/round/perf.test.ts`. A bot's `PreviewBudget` is set from its bound (see the comment in that test).

## Deliverables

1. Either a faster preview in core, or a justified new bound and `PreviewBudget`, so the perf test passes.

## Acceptance

- [ ] `crew check` green, `pnpm test:perf` included
- [ ] The report gives the preview time before and after, and what the bots' `PreviewBudget` is now

## Out of scope

- Changing the Chaos squad sizes: they belong to T-183's tuning. If the sizes are the problem, ask the lead.
- Loosening the bound with no reason given.

## Notes

Prefer making the preview cheaper over loosening the bound. A new bound has to say what it means for bots that preview.
