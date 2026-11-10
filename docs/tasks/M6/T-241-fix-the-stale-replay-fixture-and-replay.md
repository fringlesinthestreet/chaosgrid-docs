---
id: T-241
title: Fix the stale replay fixture and replay e2e spec
milestone: M6
depends_on: [T-240]
branch: agent/T-241-fix-the-stale-replay-fixture-and-replay
model: sonnet
effort: medium
scope:
  - apps/web/test/fixtures/**
  - apps/web/e2e/replay.spec.ts
  - apps/web/src/match/overlays/overlays.test.tsx
  - apps/web/src/match/battlefield/sprites.test.ts
context:
  - docs/CORE.md
---

# T-241 — Fix the stale replay fixture and replay e2e spec

## Goal

`pnpm test:e2e` passes on `main`. The spec "a loaded log plays at 1x, and 4x then Skip ends the round" in `apps/web/e2e/replay.spec.ts` never shows "Round 2" for `test/fixtures/logs/starter-2-rounds.json`. The log is probably stale since resources became cards of the deck (T-234).

## Interfaces

- The fixture `apps/web/test/fixtures/logs/starter-2-rounds.json` and the spec in `apps/web/e2e/replay.spec.ts` that loads it.

## Deliverables

1. Find why the spec never reaches "Round 2": a stale log (regenerate it, with the same tool that wrote it) or a real replay bug.
2. If the log is stale, regenerate it so it plays two rounds on current `main`. If the replay is wrong, say so in the report and ask the lead: the replay code is outside this card's scope.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm test:e2e` passes in full, including `replay.spec.ts`

## Out of scope

- Weakening or skipping the spec.
- The hand window and the other e2e specs (T-240).

## Notes

T-240's worker saw the failure on `main` and ran only three specs, so run the whole e2e suite once. The log's format is a protocol contract: don't change it.
