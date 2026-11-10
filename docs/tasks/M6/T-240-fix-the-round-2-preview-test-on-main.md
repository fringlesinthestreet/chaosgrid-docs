---
id: T-240
title: Fix the round 2 preview test and the e2e hand window clicks on main
milestone: M6
depends_on: []
branch: agent/T-240-fix-the-round-2-preview-test-on-main
model: sonnet
effort: medium
scope:
  - packages/core/src/round/preview.test.ts
  - packages/core/src/round/preview.ts
  - packages/core/test/fixtures/**
  - apps/web/e2e/**
  - apps/web/src/match/planning/HandWindow.tsx
  - apps/web/src/match/planning/HandWindow.test.tsx
context:
  - docs/CORE.md
---

# T-240 — Fix the round 2 preview test and the e2e hand window clicks on main

## Goal

`pnpm test` is green on `main` again. "matches round 2 of seed 3, where nothing is hidden from seat 0" in `packages/core/src/round/preview.test.ts` fails on `main` with `earlierBuffs: 1` instead of `0`, so every worker's `crew check` reports it as a failure they didn't cause. The e2e specs `bot-worker.spec.ts` ("bots run in one worker") and `new-player.spec.ts` ("a new player plays a game") also fail on `main`: the hand window (`data-hand-window-box`, `cg-tray-hand`) intercepts the clicks on the Skip and 4x buttons.

## Interfaces

- `hiddenFromSeatZero(round)` and `NOTHING_HIDDEN` in `preview.test.ts`: the test expects nothing to be hidden from seat 0 in round 2 of seed 3.
- `previewRound`, `expectPreviewMatchesRound` and the seeded rounds `begunRound`, `playedWithSeatZero`.

## Deliverables

1. Find why `earlierBuffs` is 1: a card or rule change since the test was written, or a real preview bug.
2. If the preview is wrong, fix it, so it matches the real round. If the test's premise is stale (the seed now hides something from seat 0 for a legitimate reason), pick another seed and round where nothing is hidden, and say why in the report.

3. Make the e2e clicks reach Skip and 4x: fix the hand window so it doesn't cover them (preferred, if it is a layout or pointer-events bug), or the specs if the window is meant to be there. Say which and why in the report.

## Acceptance

- [ ] `crew check` green, with no failing test in core
- [ ] `pnpm --filter @chaosgrid/core exec vitest run src/round/preview.test.ts` passes
- [ ] `pnpm test:e2e` passes, including `bot-worker.spec.ts` and `new-player.spec.ts`

## Out of scope

- Weakening the assertion, skipping the test, or changing the cards' behavior.
- The faceDown removal (T-239) and the resources-as-cards change (T-234): rebase on `main` if either has merged, and check the failure still reproduces.

## Notes

The failure reproduces on `main` at 76d6b9e without any open task's changes. Use the `diagnose` approach: find which commit made `earlierBuffs` 1 before choosing a fix.
