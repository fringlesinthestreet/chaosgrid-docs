---
id: T-220
title: Attached icons and picks follow units
milestone: M6
depends_on: []
branch: agent/T-220-attached-icons-and-picks-follow-units
model: sonnet
effort: medium
scope:
  - apps/web/src/match/battlefield/scene.ts
  - apps/web/src/match/battlefield/scene.test.ts
  - apps/web/src/match/battlefield/sprites.test.ts
  - apps/web/src/match/battlefield/pick.ts
  - apps/web/src/match/battlefield/pick.test.ts
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
context:
  - docs/APPS.md#The match
  - apps/web/README.md#How a match flows
  - apps/web/README.md#Rules a change must keep
---

# T-220 — Attached icons and picks follow units

## Goal

Two playback bugs on the battlefield. An attached card's icon stays on its squad's start cells while the units move, and a click on those start cells opens the squad after its units moved away or died. After this PR the icons ride with the squad's units, and a click opens only what stands there now.

## Interfaces

On `main` (grep the names, the lines move):

- `scene.ts`: `class PermanentView` sets its node's position once in `sync()`, and `update()` moves nothing. `Scene.permanentRect()`'s `case 'attached'` places the icon from `this.squadRect(arena, squad)`, the footprint, in its top-right corner, the next ones stacked to its left. `Scene.syncPermanents()` assigns the slots.
- The pattern to copy: `class SquadCues` keeps a `lead: UnitView | null` and a `follow()` that copies the lead unit's tweened position. `Scene.placeCues()` picks the first living unit as lead once a unit stands off the footprint, moves the cues to `layers.air`, and hides them while every unit is dead; `Scene.update()` calls `cues.follow()` every frame. The scene stops drawing a footprint once its units are out ("A squad whose units are out draws as its units").
- `pick.ts`: `pickAt(model, world, strips)`. Its `unit` uses live positions and skips dead units; its `squad` comes from `squadHolding()`, which tests the footprint and skips only `squad.retired`.
- `MatchScreen.tsx`: `onPick` → `subjectOf()`, which falls back to `squadSubject(squad.squad, squad.seat, squad.cardId)` when no unit or permanent was picked.

## Deliverables

1. **Icons.** Once a squad's units are out, its attached icons follow its lead unit as `SquadCues` does: the same stacking order from the lead unit's corner, on `layers.air`, hidden while every unit of the squad is dead, and back on the footprint corner when the squad is drawn as its footprint again.
2. **Picks.** `pickAt`'s `squad` matches a footprint only while the scene draws that squad as its footprint. Share one predicate between `scene.ts` and `pick.ts` instead of writing it twice. During playback a click on empty start cells opens nothing, a click on a living unit opens it, and a dead unit is never picked. Plan doesn't change: a click on a squad's footprint opens it (D71).
3. **Tests**, next to the code:
   - An attached icon follows the lead unit, tween included, and hides while the squad is dead (after "rides the badge row with the first alive unit, tween included" in `scene.test.ts`).
   - `pickAt` during playback: an empty footprint gives no squad; a living unit off its footprint gives that unit.
   - `MatchScreen`: during playback, a click on the start cells of a squad whose units moved opens nothing.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test battlefield MatchScreen` green

## Out of scope

- The pools and strips (T-222) and the trap code in `scene.ts` (T-223).
