---
id: T-117
title: Plan on the battlefield
milestone: M4
depends_on: [T-116]
branch: agent/T-117-plan-on-battlefield
model: opus
effort: high
scope:
  - apps/web/src/match/battlefield/**
  - apps/web/src/match/planning/**
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/test/fixtures/planning/**
  - apps/web/test/fixtures/session.ts
  - apps/web/e2e/m4.spec.ts
context:
  - docs/APPS.md#The match
  - apps/web/README.md#Rules a change must keep
---

# T-117 — Plan on the battlefield

## Goal

One grid to plan on (D43, the human's playtest on 2026-10-29). During Plan the planning grid lies on the battlefield, over the player's own grid, and follows the camera, which frames that grid when Plan starts. Placing a unit, a free-standing permanent or the Leader, moving the Leader, attaching a permanent to a squad and inspecting a squad all happen there. The separate grid under the battlefield goes. Targets on any grid move in T-118.

## Interfaces

What exists (copied from the code on 2026-10-29, and from the T-111 card):

```tsx
// apps/web/src/match/planning/PlanGrid.tsx
// Props (:116-129): { view: Snapshot; seat: Seat; preview?: (hovered: Cell) => readonly Cell[];
//   onCell?: (cell: Cell) => void; onSquad?: (squad: SquadSnapshot) => void;
//   onPermanent?: (permanent: PermanentSnapshot) => void; pickable?: readonly SquadId[]; disabled?: boolean }
// CELL = 18 px (:28). Each cell is <button aria-label="col C, row R" data-col data-row data-preview>
//   (:84-114) in a root role="group" aria-label="Seat N grid" data-plan-grid (:202-206). One
//   delegated click (:160-172) calls onCell, then onSquad (if pickable), then onPermanent. The
//   footprint preview outlines preview(hovered) clipped to the grid (:139-148). Arrow keys move a
//   roving tabindex (:186-199). Row 0, the front row facing the Chaos Grid, is at the top (:1-4).
//   It draws gridContents(view, seat) (draft.ts:57): squads, free-standing permanents and the prize
//   as blocks (data-squad, data-permanent, data-prize) with pointer-events none (:235-300, :49).
// planning/index.tsx PanelBody: the left column renders PlanGrid with seat={view.seat} (:226-243):
//   onCell={place} (:232; place :132-155, for the selections castUnit, castLeader, moveLeader and
//   castPermanent freeStanding, with preview footprint(hovered, size, rotated), :126-130), pickable
//   own squads with onSquad={attachPermanent} for an attached castPermanent (:233-237), and
//   onSquad / onPermanent = inspect otherwise (:238-242). TargetPicker replaces the grid while a
//   target is picked (:218-224); its grids are T-118's.

// apps/web/src/match/battlefield
// Battlefield.tsx: BattlefieldProps { model, step?, viewer, cards, stepMs?, chaosBanner?,
//   focusRequest?: { seat }, onPick? (T-111) }. mount.ts: focus(seat); the camera keys (arrows, +,
//   −, Home); the wheel zooms. camera.ts: Camera { cellPx, center }, initialCamera(arena, viewport,
//   seat) (:62), zoom (:79), pan (:97), OPEN_CELL_PX = 16 (:23). scene.ts: setCamera (:501-507)
//   places root at round(viewport / 2 − center × cellPx). view.ts: viewFor(arena, viewer) turns
//   the world so the viewer's grid is at the bottom, its row 0 facing up toward the Chaos Grid.
//   grid.ts: gridRect(seat) (:31). T-111's pick.ts maps the other way.

// apps/web/src/match/MatchScreen.tsx: the battlefield box (position relative, height
//   min(70vh, 640px)). apps/web/e2e/m4.spec.ts:115-116: "Place Leader", then the cell
//   getByRole('button', { name: 'col 7, row 0', exact: true }). Component tests find cells with a
//   cell(col, row) helper (PlanningPanel.test.tsx:84-85, PlanningActions.test.tsx:68-69,
//   Zones.test.tsx:48-49) and squads with squadBlock (PlanningActions.test.tsx:78-85).
```

What this task adds:

```ts
// battlefield, exported from battlefield/index.tsx
/** Where a seat's grid is on screen: px from the battlefield box's top left, the size of a cell, and the grid's quarter turns in the view. */
export interface GridOnScreen { left: number; top: number; cellPx: number; turns: 0 | 1 | 2 | 3 }
// BattlefieldProps gains:
/** Called after every camera change and resize, with every seat's grid. */
onGrids?: (grids: Readonly<Record<Seat, GridOnScreen>>) => void;
/** A new object frames that seat's grid: centred, and zoomed so the whole grid fits the box. */
frameRequest?: { seat: Seat };

// planning/PlanGrid.tsx gains:
/** Lie on the battlefield: absolute, at the grid's place and cell size, turned with it. */
placement?: GridOnScreen;
/** 'opaque' draws the planning view's contents over the battlefield's copy of the grid; 'clear' draws only previews and outlines (T-118). */
look?: 'opaque' | 'clear';
```

## Deliverables

1. **The battlefield says where its grids are.** `onGrids` comes from the forward mapping, and it's called after every pan, zoom and resize. `frameRequest` centres and zooms on a seat's grid. A wheel over a layer in the box still zooms the battlefield.
2. **The layer.**
   - **Where.** During Plan the panel's own-grid PlanGrid renders in the battlefield box, absolutely positioned over the viewer's grid from `onGrids`. It's `opaque`: it draws the planning view as PlanGrid does today, so the player's new placements show and the canvas's Plan-start copy of that grid is covered.
   - **The camera.** When Plan starts, the screen sends a `frameRequest` for the viewer's grid.
   - **What happens there.** Everything listed above that used the panel's grid: placing, moving the Leader, attaching, inspecting a squad or a permanent. The cells stay buttons with the same labels and keys.
   - **Outside Plan** the layer isn't there.
3. **The separate grid goes.** The panel's left column keeps its status line, Rotate, SquadPanel and PermanentPanel. TargetPicker keeps its own grids until T-118.
4. **Tests.**
   - The layer's position follows `GridOnScreen`, using a stub `Battlefield`, since jsdom has no WebGL.
   - Placing a unit and moving the Leader through the layer's cells.
   - `onGrids` and `frameRequest` in the battlefield's own tests: the grid rect matches `gridRect` after a pan and a zoom.
   - Update the tests that found the grid in the panel.
5. **The e2e.** "Place Leader", then "col 7, row 0" on the battlefield: the spec passes, at 1280×720.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test -- battlefield planning MatchScreen` passes
- [ ] `pnpm test:e2e` passes

## Out of scope

- Targets on any seat's grid, and the revive's cell (T-118).
- Art or hover cards in the layer: it draws what PlanGrid draws today.
- Dragging a card from the tray onto the grid. A click on a tile, then a cell, stays the way to place.

## Notes

- D43: the battlefield draws only the model, and the layer (planning/) draws the seat's snapshot.
- The viewer's grid sits at the bottom of the view with row 0 at its top edge, facing the Chaos Grid: the same way up as PlanGrid, so the viewer's layer has `turns` 0. Other seats' turns matter in T-118.
- Default: dragging on the layer doesn't pan, since its cells are buttons. The player pans by dragging outside the grid, or with the keys, and the wheel zooms anywhere.
- Default: at the framing zoom a cell is about 20 px in a 640 px box. If the box is smaller, frame anyway: the player can zoom.
- Default: the camera frames the viewer's grid only when Plan starts. Home brings back the camera's start, as now.
