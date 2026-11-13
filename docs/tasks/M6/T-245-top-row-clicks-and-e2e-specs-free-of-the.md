---
id: T-245
title: Top row clicks and e2e specs free of the seed's Chaos
milestone: M6
depends_on: []
branch: agent/T-245-top-row-clicks-and-e2e-specs-free-of-the
model: sonnet
effort: high
scope:
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/src/match/overlays/Hud.tsx
  - apps/web/src/match/overlays/overlays.test.tsx
  - apps/web/src/match/battlefield/camera.ts
  - apps/web/src/match/battlefield/camera.test.ts
  - apps/web/src/match/planning/targets.ts
  - apps/web/e2e/new-player.spec.ts
  - apps/web/e2e/bot-worker.spec.ts
  - apps/web/e2e/support/**
  - apps/web/README.md
context:
  - docs/DECISIONS.md#Decision log
  - docs/APPS.md#The match
  - apps/web/README.md#How a match flows
  - apps/web/README.md#Tests
---

# T-245 — Top row clicks and e2e specs free of the seed's Chaos

## Goal

A player can click every cell of their grid: the match status bar no longer covers its top row. `pnpm test:e2e` is green on `main` again, and its specs don't break when the seed's Chaos draws change, which happens whenever cards are added.

## Interfaces

On `main` (grep the names, the lines move).

- `MatchScreen.tsx`: the screen is one absolute box; the `Battlefield` fills it (`inset: 0`), and `Overlays` lays the HUD over it. `TopBar` (`<header aria-label="Match status" className="cg-panel">`, with `[data-match-round]`, `[data-match-phase]`, `[data-match-target]`) is the `topBar` piece in the HUD's top region.
- `overlays/Hud.tsx`: `Overlays({ pieces })`, a grid over the whole screen (`hudStyle`: `inset: 0`, rows `auto minmax(0, 1fr) auto`, `padding: 8`), with regions `[data-hud-region="top" | "left" | "center" | "right" | "bottom"]`.
- `battlefield/camera.ts`: `initialCamera` and `frameCamera` fit the whole world into the viewport (`fitSize`) with no insets (D87).
- The hand window (`planning/HandWindow.tsx`, `[data-hand-window]`) is clamped to the battlefield's box at every move and resize (D87).
- `e2e/new-player.spec.ts`, step 5: `const floating = page.locator('[data-floating-mana] [data-mana]')` expects 1 before the Volcano, 2 after it, 1 after the Spark Skirmisher. The 1 is a generic mana from seed `e2e-1`'s round-1 Chaos; the seed reveals something else since the card pool grew, so it fails at `toHaveCount(1)`. The grid's top-row cells are picked with `press('Enter')` because the status bar covers them.
- `e2e/bot-worker.spec.ts` (D56): seed `e2e-worker`, Ember Aggro against three hard bots, plays nothing in round 1 and then clicks `Discard N`. A hand of 7 plus round 1's draw is 8, the limit, so it only discards when round 1's Chaos draws an extra card; it times out waiting for the button.
- The lobby's Chaos checkbox (`lobby.more.chaos`, D82): with Chaos off, Reveal draws nothing and the Chaos pause is 0.
- `planning/targets.ts` opens with a doc comment that names "the pool", which isn't in the game (D60, D85).

## Deliverables

1. **The status bar.** At the camera a match opens with, and after the "frame my grid" camera, no cell of the viewer's grid lies under the match status bar. Default: the status bar sits above the battlefield's box instead of over it, so the camera fits the world into the space below and the hand window's clamp follows that box (D87). Choose a camera-side fix only if it's clearly smaller, and say which in the PR.
2. **new-player.spec.ts.** Its round-1 expectations don't depend on what the seed's Chaos reveals: the floating mana is read when Plan opens and the spec expects one more after the Volcano and one less after the Spark Skirmisher, or an equivalent that holds for any Chaos. The top-row cells are clicked like the others. The journey's steps stay the same.
3. **bot-worker.spec.ts.** The spec plays with Chaos off, so nothing revealed changes the hand, and goes from round 1 to round 2 without a Discard step. It still checks one bot worker during the match and none after leaving it.
4. **targets.ts.** Its doc comment names the floating mana, not a pool.
5. **Tests.** `MatchScreen.test.tsx` or `overlays.test.tsx` checks that the status bar is outside the battlefield's box, or that the camera keeps the bar's rows clear; `camera.test.ts` only if the camera changes.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test MatchScreen overlays camera` green
- [ ] `pnpm test:e2e` green, run twice

## Out of scope

- The replay's round clock after Skip: not planned.
- `scene.ts`'s `ui.cardBack` fallback for a permanent without a card id: `PermanentModel.cardId` is null only for a prize, and the fallback is what the shared type asks for.
- Renaming `data-tray`: it marks the hand's list inside the hand window, which tests still query.
- The other e2e specs, unless they fail on this branch for the same reasons.

## Notes

- The e2e runs on ports 4999 and 5999 by default (`e2e/ports.ts`); set `CHAOSGRID_WEB_PORT` and `CHAOSGRID_API_PORT` if another checkout is running them.
- A spec that still needs a seeded state should get it from the lobby's options, never from a seed's Chaos.
