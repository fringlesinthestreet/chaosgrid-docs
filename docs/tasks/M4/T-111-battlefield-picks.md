---
id: T-111
title: Click the battlefield to pick what's there
milestone: M4
depends_on: []
branch: agent/T-111-battlefield-picks
model: sonnet
effort: high
scope:
  - apps/web/src/match/battlefield/**
context:
  - docs/APPS.md#The match
  - apps/web/README.md#Rules a change must keep
---

# T-111 — Click the battlefield to pick what's there

## Goal

A click on the battlefield says what it landed on: the world cell, the seat's grid cell under it, and the unit and the permanent there. With it, T-115 opens the card view for anything on the battlefield, of any owner, Chaos included (D43), and T-117 and T-118 build planning on the same mapping. Today the battlefield only pans and zooms. Nothing hit-tests, and nothing maps a screen point back to a cell.

## Interfaces

What exists (copied from the code on 2026-10-29):

```ts
// apps/web/src/match/battlefield/mount.ts
export interface Battlefield { draw(model, step?); setStepDuration(ms); focus(seat); destroy(); } // :9-17
export interface BattlefieldOptions { viewer; cards; chaosBanner? }                              // :19-24, no callbacks
export function createBattlefield(element: HTMLElement, options: BattlefieldOptions): Battlefield; // :35
// :37-41 the host div: tabIndex 0, aria-label "Battlefield", data-battlefield, min-height 320px.
// :120-161 plain DOM listeners on it: pointerdown starts a drag, captures the pointer and focuses
//   (:122-126); pointermove pans (:127-131). There's no click-versus-drag threshold. The wheel zooms;
//   arrows, +, − and Home work too.

// Battlefield.tsx:7-17
export interface BattlefieldProps { model; step?; viewer; cards; stepMs?; chaosBanner?; focusRequest? }
// :34-42 it's rebuilt when viewer, cards or chaosBanner change. replay/ReplayPage.tsx:341 mounts it too.

// scene.ts: CELL = 16 world px per cell (:24). Scene (:367) has the root Container 'world' and views
//   per id: UnitView (:130, 'unit:<id>'), SquadView (:222), PermanentView (:269). `centers`
//   (:378-379) keeps each unit's, squad's and permanent's last drawn centre, in view px.
//   cameraState (:405), layout (:409), setViewport (:417), focus (:423), zoomBy (:427), panBy (:432).
//   Forward mapping: view px = viewFor(…).rect(world) × CELL (rectPx, :519-527), and
//   screen = root.position + view px × (cellPx / CELL), where
//   root.position = round(viewport / 2 − center × cellPx) (setCamera, :501-507).
// camera.ts (pure): Camera { cellPx, center: { x, y } } with the centre in view cells (:7-11); Viewport (:14-17).
// view.ts: viewFor(arena, viewer): ViewTransform { turns, point, rect, center, arena } (:12-23, :76-94),
//   so the viewer's grid is at the bottom; turnPoint (:33-44) is private.
// grid.ts: gridToWorld(seat, cell) (:5-10), footprintRect (:13), gridRect (:31). A seat cell is
//   (world − origin)·right and (world − origin)·back, with the seat's ArenaLayout vectors.
// The model: UnitModel.cardId (model/types.ts:56), SquadModel.cardId (:36),
//   PermanentModel.cardId: CardId | null (:99) and faceDown (:102); model.arena (:134).
// packages/protocol: WorldCell { x, y } (primitives.ts:115), Cell { col, row } (:111).
```

What this task adds:

```ts
// battlefield/pick.ts: pure, so it's tested without Pixi
/** What a click on the battlefield landed on. */
export interface BattlefieldPick {
  /** The cell under the pointer, in world cells. */
  world: WorldCell;
  /** Whose grid that cell is in: null on the Chaos Grid and in free space. */
  seat: Seat | null;
  /** The cell in that seat's grid, in the seat's own coordinates (what PlanGrid and plans use); null when seat is. */
  cell: Cell | null;
  /** The living unit drawn on that cell, if any. */
  unit: UnitModel | null;
  /** The permanent whose footprint holds the cell, if any: a prize and an Emblem count. */
  permanent: PermanentModel | null;
}
/** The world cell under a point of the host element, given the camera and the view. */
export function worldAt(point: { x: number; y: number }, camera: Camera, viewport: Viewport, view: ViewTransform): WorldCell;
/** What the model has on that world cell. */
export function pickAt(model: MatchModel, world: WorldCell): BattlefieldPick;

// mount.ts: BattlefieldOptions.onPick?: (pick: BattlefieldPick) => void
// Battlefield.tsx: BattlefieldProps.onPick?: (pick: BattlefieldPick) => void, kept current without
//   rebuilding the scene (a ref), since callers pass a new function each render.
// battlefield/index.tsx exports the BattlefieldPick type.
```

## Deliverables

1. **The way back from the screen.** `worldAt` inverts the forward mapping above: the point minus `root.position`, divided by `cellPx`, gives a view cell, which `turnPoint`'s inverse turns back into a world cell. A seat cell then comes from the seat's arena vectors, as `gridToWorld` in reverse. Tests round-trip `gridToWorld` and `worldAt` for every seat, every viewer and two zoom levels.
2. **What's there.** `pickAt` finds the living unit on the cell, from the model's unit positions (what the scene draws once a step ends). It also finds the permanent whose footprint holds the cell, and the seat whose grid holds it. Tests cover a unit, a prize, an Emblem on the Chaos Grid, a Chaos unit in free space, and an empty cell of an opponent's grid.
3. **Click versus drag.** A pointerup within 4 px of its pointerdown is a click: it calls `onPick` and doesn't pan. A longer drag pans as today. Keys and the wheel don't change.
4. **The prop.** `onPick` on `BattlefieldOptions` and `BattlefieldProps`. A new function on every render neither rebuilds the scene nor drops a click.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test -- battlefield` passes
- [ ] `grep -c -E "onPick" apps/web/src/match/battlefield/Battlefield.tsx` prints at least 1
- [ ] `pnpm test:e2e` passes: nothing that pans or zooms broke

## Out of scope

- What a click opens. The card view is T-115, which passes `onPick` from `MatchScreen`.
- Planning on the battlefield (T-117, T-118).
- Hover effects, and a pick by keyboard. The hidden Units list stays as it is.

## Notes

- Default: a cell can hold a unit and a permanent at once (a trap's area, a unit on a trap). `pickAt` gives both, and the caller chooses. T-115 shows the unit.
- The viewer's model holds only what the viewer may see: an opponent's face-down trap isn't in it, so `pickAt` can't reveal one.
- The replay mounts the battlefield too, so `onPick` stays optional, and the replay passes none.
- A unit tweening between two cells mid-step is picked at its model cell. That's at most one cell off for a fraction of a step, and it keeps `pickAt` free of the scene.
