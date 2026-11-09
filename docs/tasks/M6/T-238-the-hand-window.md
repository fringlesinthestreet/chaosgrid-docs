---
id: T-238
title: The hand window
milestone: M6
depends_on: [T-221, T-222]
branch: agent/T-238-the-hand-window
model: sonnet
effort: high
scope:
  - apps/web/src/match/planning/**
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/src/match/battlefield/Battlefield.tsx
  - apps/web/src/match/battlefield/Battlefield.test.tsx
  - apps/web/src/match/battlefield/mount.ts
  - apps/web/src/match/battlefield/camera.ts
  - apps/web/src/match/battlefield/camera.test.ts
  - apps/web/src/i18n/en/planning.json
  - apps/web/src/i18n/en/match.json
  - apps/web/src/theme/theme.css
  - apps/web/test/fixtures/planning/**
  - apps/web/README.md
context:
  - docs/DECISIONS.md#Decision log
  - docs/APPS.md#The match
  - apps/web/README.md
---

# T-238 — The hand window

## Goal

The tray becomes a window the player drags over the battlefield, clamped inside it, and the planning panel goes: the window holds the hand, the floating mana, Ready with the Plan clock and the round's rules (D87). The grid is never hidden behind a fixed tray, and the camera needs no inset.

## Interfaces

On `main` (grep the names, the lines move).

- `MatchScreen.tsx`: the tray mounts through a portal into `trayHost` in the HUD; `ReadyBar` (the Ready button and the Plan timer, `sendReady`) and `PlanningPanel` (`planning/index.tsx`: `FloatingMana`, `RulesBar`, the clocks) sit beside the battlefield; `freeArea` is a ref to the part of the screen the grids must stay in.
- `battlefield/Battlefield.tsx` passes `freeArea` to `createBattlefield` (`mount.ts`), whose `insetsOf(host, area)` turns it into camera `Insets`; `camera.ts` keeps every grid inside the free part (`freePart`).
- `planning/Tray.tsx` draws the hand and the Leader's slot; `planning/clock.ts` has `formatClock`, `HURRY_SECONDS`, `NO_LIMIT_SECONDS`.

## Deliverables

1. **The window.** `planning/HandWindow.tsx` replaces the tray's host and the planning panel: a titled, draggable window (pointer events on its title bar; keyboard: arrow keys move it 16 px) whose position is clamped at every move and on every resize of the battlefield so that all four edges stay inside the battlefield element's box, whatever the window's or the box's size. It opens centred at the bottom. Its position is per-viewer state (`localStorage`, in a `try`), restored on the next match when it still fits.
2. **Contents.** The hand and the Leader's slot (the `Tray`), the floating mana (`FloatingMana`), Ready with the Plan clock (`ReadyBar`, moved in), and the round's rules (`RulesBar`) as one line. The discard step's chooser (`DiscardHand`) shows in the window too.
3. **No planning panel.** `PlanningPanel` goes with its tests; `PlanningProvider` stays. `MatchScreen` passes the battlefield no `freeArea`, and `createBattlefield` accepts none: `insetsOf` and the camera's `Insets` go when nothing else uses them.
4. **Tests:** the window clamps on each side (a drag past the left edge leaves it at 0, past the right at `box.width - window.width`), on a resize that shrinks the box, and on restore from a stored position that no longer fits; Ready sends once from the window; the camera test that covered the inset goes with it.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test planning MatchScreen camera` green

## Out of scope

- What the hand window shows for resources and searches (T-236), and the mana artifacts' pips (T-228).
- The overlays (T-221, T-229).

## Notes

- The "playing grid" the window stays inside is the battlefield element's box on screen, not a seat's grid in world cells.
- jsdom reports no sizes: test the clamp as a pure function (`clampWindow(box, window, position)`), and the component with a stubbed `getBoundingClientRect`.
- Lead default: the window has no close button; a hidden hand would hide the only way to act.
