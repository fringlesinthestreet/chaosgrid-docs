---
id: T-118
title: Pick targets on the battlefield
milestone: M4
depends_on: [T-117]
branch: agent/T-118-targets-on-battlefield
model: sonnet
effort: high
scope:
  - apps/web/src/match/planning/**
  - apps/web/src/match/battlefield/**
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/test/fixtures/planning/**
  - apps/web/e2e/m4.spec.ts
context:
  - docs/APPS.md#The match
---

# T-118 — Pick targets on the battlefield

## Goal

The last step of D43. A spell's or an ability's target on a grid is picked on that grid on the battlefield, the player's own or an opponent's, and a revive's cell on the player's own grid. After this PR the planning panel draws no grid of its own: PlanGrid exists only as the layer on the battlefield (T-117).

## Interfaces

What exists (copied from the code on 2026-10-29, and from the T-117 card):

```tsx
// apps/web/src/match/planning/TargetPicker.tsx
// Props (:25-30): { spec, view, onPick(target, copyTarget?), onCancel }; dispatch (:31-37).
// RevivePicker (:40-120): your discard pile as buttons (:75-93), then your PlanGrid with a
//   footprint preview and R to rotate (:98-106); result { kind: 'discardPileCard', card, cell, rotated }.
// CopyPicker (:123-208): lists, and a nested TargetPicker on copiedSpec (:155-164).
// BoardPicker (:210-362): `seat` targets are a button list (:320-330); `row` (:295) and `area`
//   (:297, spec.size) a cell click; `squad` pickable squads plus onSquad (:299-303), and a "Squads
//   without a grid" button group for spawned and Chaos squads (:343-349); `squadToCell` a squad
//   click then a cell click with the squad's footprint (:305-312). Its PlanGrid shows the "Grids"
//   tab's seat (seat={tab}, :285-287; the tab buttons at :333-339). Candidates come from
//   seatsFor / squadsFor (targets.ts:60, :78), and previews from targetCells(spec, hovered) (:97).
// Target kinds: packages/protocol/src/target.ts:29-65 (seat, row, area, squad, squadToCell,
//   discardPileCard, spell).

// T-117: GridOnScreen { left, top, cellPx, turns }; BattlefieldProps.onGrids and frameRequest;
//   PlanGrid's placement and look ('opaque' | 'clear'); the own-grid layer during Plan.
// Tests that pick targets: PlanningActions.test.tsx and Zones.test.tsx query 'Target picker'
//   and click cells with cell(col, row).
```

## Deliverables

1. **Board targets on the battlefield.** While BoardPicker picks a `row`, `area`, `squad` or `squadToCell`, a `clear` PlanGrid layer lies over the tab's seat's grid on the battlefield. It shows the previews and the pickable squads' outlines, and picks as the panel's grid did. The "Grids" tabs stay as the way to choose the seat, and each one frames that seat's grid (`frameRequest`). Only one layer shows at a time: the target layer replaces the own-grid layer while a target is picked.
2. **Turned grids.** A seat on the left, top or right is turned in the view, and its layer turns with it (`turns`). Its "col C, row R" button then lies on that cell of the battlefield, and the arrow keys move in the grid's own coordinates, as now.
3. **The revive's cell** is picked on the own-grid layer, with its footprint preview and R to rotate.
4. **Back home.** After a pick or Cancel, the camera frames the viewer's grid again, and the own-grid layer is back.
5. **No grid in the panel.** No PlanGrid renders inside the planning panel any more. Lists stay lists: a seat target, spawned and Chaos squads, the revive's card, copies.
6. **Tests.**
   - A layer for seat 1 and one for seat 2 (turned) put "col 0, row 0" where `GridOnScreen` says.
   - Picking a row, an area, a squad, a squad to a cell, and a revive's cell through the layers.
   - Update the target tests that clicked the panel's grid.
7. **The e2e** passes.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test -- planning MatchScreen battlefield` passes
- [ ] `grep -c -E "placement=" apps/web/src/match/planning/TargetPicker.tsx` prints at least 1
- [ ] `pnpm test:e2e` passes

## Out of scope

- New target kinds, or new ways to pick them.
- Picking a Chaos squad on the battlefield itself. Spawned and Chaos squads have no grid, so they stay in "Squads without a grid". A later card can use T-111's picks for them.

## Notes

- `look: 'clear'` draws no blocks: the battlefield shows what stands on that grid, which is what that seat looked like when Plan began (D34).
- Default: a target on the viewer's own grid uses the own-grid layer (`opaque`, as in T-117), since the planning view has the viewer's new placements.
- Rotation: CSS `rotate(turns × 90deg)` about the layer's centre is one way. Check it against T-111's `worldAt` in a test: the two mappings must agree.
