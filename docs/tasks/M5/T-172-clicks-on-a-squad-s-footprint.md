---
id: T-172
title: Clicks on a squad's footprint
milestone: M5
depends_on: [T-153]
branch: agent/T-172-clicks-on-a-squad-s-footprint
model: sonnet
effort: medium
scope:
  - apps/web/src/match/battlefield/pick.ts
  - apps/web/src/match/battlefield/pick.test.ts
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
context:
  - apps/web/README.md#How a match flows
  - apps/web/README.md#Tests
---

# T-172 — Clicks on a squad's footprint

## Goal

The human's playtest (2026-11-04): "BUG: focus on permanents (details on card) stopped working mid round".

The lead's diagnosis: a battlefield click opens a living unit on the cell, else a free-standing permanent, a prize or an Emblem. A squad's footprint isn't pickable, and neither are the icons of the cards attached to it (`holds` returns false for them). At round start a squad's units stand on its footprint, so a click there opens one of them, and its card lists the attachments. Once they walk off or die, the same click opens nothing. On `apps/web/test/fixtures/logs/emblem.json`, the cell of Bark Armor's icon picks unit u617 at tick 0 and nothing at tick 1967.

Units, free-standing permanents, prizes and Emblems were all checked mid-round and open as they should. After this task a click anywhere on a squad's footprint opens its card for the whole round.

## Interfaces

What exists (copied on 2026-11-04):

```ts
// apps/web/src/match/battlefield/pick.ts
export interface BattlefieldPick { world; seat; cell; unit: UnitModel | null; permanent: PermanentModel | null }
function holds(model, permanent, world): boolean; // :43, 'attached' → false: "An attached one has no cell of its own."
export function pickAt(model: MatchModel, world: WorldCell): BattlefieldPick; // the air unit over the ground one
// battlefield/grid.ts:13 footprintRect(seat, cell, size, rotated): WorldRect.
// scene.ts:824 draws an attached card as an icon in its squad's top-right corner, the next ones to its left.

// apps/web/src/match/MatchScreen.tsx:128 subjectOf(pick, state, cards): a unit → its card, with
// "You, level 2" and the cards attached to its squad; else the permanent's card, a prize as itself;
// else null (:147).

// apps/web/src/match/model/types.ts:31 SquadModel { squad, seat, cardId, leader, cell, rotated, size, level, ... }
```

## Deliverables

1. **`BattlefieldPick.squad`**: the squad whose footprint holds the cell, from `footprintRect` on its seat's grid, else null.
2. **`subjectOf`** keeps its order and adds the squad last: a living unit on the cell, then a permanent, then the squad. A squad opens the subject one of its units opens: its card, the caption with its level, and the cards attached to it. Share that code between the unit and the squad; don't copy it.
3. **The comments** on `BattlefieldPick.permanent` and `holds` say where an attached card is picked: through its squad.
4. **Tests:**
   - `pick.test.ts`:
     - every cell of a 2×1 squad's footprint picks the squad, turned and not;
     - the cell beside it doesn't;
     - a unit standing on the footprint is picked with the squad.
   - `MatchScreen.test.tsx`:
     - a click on a squad's footprint, with no unit on the cell, opens the squad's card, its level and its attached cards;
     - with one of its units there, the click opens that unit as before.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test pick MatchScreen` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `pnpm test:e2e` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Hit-testing each attached card's icon: the squad's card lists them all.
- Tokens and Chaos squads, which have no footprint, and PlanGrid, which has its own buttons.

## Notes

- A squad and a free-standing permanent never share a cell, so their order in `subjectOf` only matters for a unit standing on either.
