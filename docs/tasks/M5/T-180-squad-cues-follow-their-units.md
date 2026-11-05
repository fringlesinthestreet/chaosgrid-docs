---
id: T-180
title: Squad cues follow their units
milestone: M5
depends_on: [T-179]
branch: agent/T-180-squad-cues-follow-their-units
model: sonnet
effort: medium
scope:
  - apps/web/src/match/battlefield/scene.ts
  - apps/web/src/match/battlefield/scene.test.ts
context:
  - docs/ART.md#Sizes
  - docs/RULES.md#Round structure
  - docs/tasks/M5/T-162-rested-and-charged-cues.md
  - apps/web/README.md#Tests
---

# T-180 — Squad cues follow their units

## Goal

T-162 draws a squad's state cues, the Charge glow and the badge row, in a view of its own on the squad's footprint, whether or not its units are out. In Simulate the units leave the footprint, and the cues stay behind on the grid: the human found it in their playtest on 2026-11-05. Once a squad's units leave its footprint, its cues go with them.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// apps/web/src/match/battlefield/scene.ts
export const CELL = 16; // px per cell; ICON_PX = 8
class SquadCues { // :335, node label `cues:<squad>`, in layers.permanents
  readonly glow: Graphics; // label 'glow': a two-line PALETTE.charge outline of the rect, when charged
  readonly badges: Container; // label 'badges': the BADGES icons and the 'level' digits, left to right
  sync(rect: WorldRect, cue: SquadCue): void; // puts the node at rect; redraws on a new size or cue
  // layoutBadges leaves out the badges that don't fit in rect.width, from the end
}
interface SquadCue { badges: (BadgeName | 'level')[]; durability: number | null; level: number; charged: boolean }
// syncSquads (:1179): for each squad not retired, cues.sync(its footprint rect, cueOf(model, squad));
// then, unless its units are out (some unit in model.units has that squad), its SquadView.
// cueOf (:1220) reads the squad's alive units for `rested` and their keywords.
class UnitView { // :193, node label `unit:<id>`
  // a 'status' row of its own icons (shield, extraLife, fear) at y = -ICON_PX - 1; the HP bar at y = CELL - 2
}
// Scene.update(now) (:932) moves every unit view along its tween (view.move), each frame.
```

RULES.md › Round structure, Cleanup: dead units respawn on their squad's start cells, survivors stay where the fight left them, and the next round puts every unit back on its start cells.

## Deliverables

1. **Where a squad's cues are:**
   - no unit of the squad in the model: on its footprint, as T-162 draws them;
   - units out, every alive one on the footprint's cells (as in Plan): on the footprint too;
   - units out, at least one alive off the footprint: with the units (deliverable 2);
   - units out and none alive: nowhere, until they respawn.
2. **With the units:**
   - each alive unit of a charged squad glows on its own cell, in the glow's colors;
   - the badge row rides with the squad's first alive unit, in `model.units` order, above it and clear of that unit's own status icons; it keeps the footprint's width for what fits, so it shows the same badges as on the footprint;
   - both move with the units every frame, tweens included;
   - when that unit dies, the row moves to the next alive one.
3. **Tests in `scene.test.ts`**, beside T-162's state cue tests:
   - a charged squad with a unit moved off the footprint: no glow on the footprint, a glow on each alive unit;
   - the badge row follows the first alive unit through a `unit.moved` and its tween, and moves to the next one when that unit dies;
   - with every unit of the squad dead, none of its glows or badges shows;
   - with every alive unit on the footprint, the cues are on the footprint.

   T-162's tests keep their expectations. Two of them take a unit from `fighting`, which may stand off the squad's footprint: put it on the footprint.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test scene` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- PlanGrid's cues (T-166), which have no units to follow.
- What `cueOf` puts in a cue, and the units' own icons.

## Notes

- A glow or a badge row drawn inside a unit view's node moves with that unit, so it needs no code per frame.
- Defaults: a unit is on the footprint when its cell is one of the footprint's cells.
