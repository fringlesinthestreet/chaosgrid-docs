---
id: T-243
title: Web leftovers after the hand window and the one deck
milestone: M6
depends_on: [T-238, T-240]
branch: agent/T-243-web-leftovers-after-the-hand-window-and
model: sonnet
effort: medium
scope:
  - apps/web/src/match/battlefield/mount.ts
  - apps/web/src/match/battlefield/scene.ts
  - apps/web/src/match/battlefield/scene.test.ts
  - apps/web/src/match/battlefield/camera.ts
  - apps/web/src/match/battlefield/camera.test.ts
  - apps/web/src/match/battlefield/Battlefield.tsx
  - apps/web/src/match/battlefield/Battlefield.test.tsx
  - apps/web/src/match/battlefield/index.tsx
  - apps/web/src/match/overlays/Hud*.tsx
  - apps/web/src/match/planning/HandWindow.tsx
  - apps/web/src/match/planning/HandWindow.test.tsx
  - apps/web/src/match/planning/Tray.tsx
  - apps/web/src/theme/theme.css
  - apps/web/src/decks/editor/DeckPanel.tsx
  - apps/web/src/decks/editor/editor.test.tsx
  - apps/web/src/i18n/en/deckEditor.json
  - apps/web/src/i18n/en/overlays.json
  - apps/web/e2e/new-player.spec.ts
  - apps/web/README.md
  - apps/web/src/match/overlays/index.tsx
context:
  - docs/DECISIONS.md#Decision log
  - docs/APPS.md#The match
  - apps/web/README.md
---

# T-243 — Web leftovers after the hand window and the one deck

## Goal

The code the hand window (D87) and the one deck (D60) made dead is gone, the inactive-reason tooltip isn't clipped by the window, and the deck editor's headings come from the language files (D50).

## Interfaces

On `main` (grep the names, the lines move).

- Camera insets, which nothing sets since the hand window: `BattlefieldOptions.freeArea?: () => Element | null` and `insetsOf(host, area)` in `battlefield/mount.ts`; `SceneOptions.insets?: () => Insets` in `scene.ts`, passed to `initialCamera` and `frameCamera`; `Insets`, `NO_INSETS` and `freePart` in `camera.ts`; the `freeArea` tests in `scene.test.ts` and `camera.test.ts`.
- `overlays/Hud.tsx`: `HudPieces` still has `planning`, `tray` and `ready`, which `MatchScreen` no longer passes; `HudPanel`'s fold (`unfoldKey`, `useTrayKey`) and the `overlays.hud.planning` string served them.
- The tooltip: `.cg-inactive-reason { position: absolute; bottom: 100% }` on a `.cg-tray-entry` (theme.css), inside `.cg-hand-window { overflow: auto }`, so a tooltip above the top row of tiles is clipped.
- `decks/editor/DeckPanel.tsx`: `<section aria-label="Cards">` and `'Unknown cards'` are literals; the group headings reuse the singular `cards.type.*` strings.
- `e2e/new-player.spec.ts` finds the hand through `[data-tray]` (`Tray.tsx`'s `data-tray=""`) and the Ready group; the hand window is `[data-hand-window]`.

## Deliverables

1. **Camera.** `freeArea`, `insetsOf`, `SceneOptions.insets`, `Insets`, `NO_INSETS` and `freePart` go; `initialCamera` and `frameCamera` lose the insets parameter; their tests follow.
2. **HUD.** `HudPieces` loses `planning`, `tray` and `ready`; the fold goes if no remaining piece folds, and the strings only it used go from `overlays.json`.
3. **Tooltip.** An inactive reason shows whole on every hand tile, the top row included: the hand window's scroll container is the hand list, with room above the tiles for the tooltip, or the tooltip opens below the tile when the window's top is too close; whichever it is, no change to `HandEntry.tsx` (another task edits it). Check it in a browser once (`pnpm dev`) and say what you saw in the PR.
4. **Deck editor.** The "Cards" region's label, "Unknown cards" and each type's heading come from `deckEditor.json`, the headings as plural type names.
5. **e2e.** The spec finds the hand through `[data-hand-window]` and the hand region; `data-tray` goes from `Tray.tsx` when nothing else uses it. The spec's steps and expectations don't change.
6. **Tests:** the camera tests without insets; `HandWindow.test.tsx` checks the tooltip's container; the editor test reads the headings through `t()`.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test battlefield overlays planning decks` green
- [ ] `pnpm test:e2e` green

## Out of scope

- `planning/HandEntry.tsx`, `HandCardActions.tsx`, `draft.ts`, `rules.ts`, `targets.test.ts` and the planning fixtures: another task edits them this wave.
- Resources on the grid, the search panel and the strips (T-236).
- The replay's round clock after Skip, which reads the full round again: not planned.

## Notes

- The hand window has no close button and the window itself must stay inside the battlefield's box (D87): don't trade either for the tooltip.
