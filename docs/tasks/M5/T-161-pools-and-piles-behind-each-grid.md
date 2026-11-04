---
id: T-161
title: Pools and piles behind each grid
milestone: M5
depends_on: [T-153, T-154, T-160, T-163, T-172]
branch: agent/T-161-pools-and-piles-behind-each-grid
model: opus
effort: high
scope:
  - apps/web/src/match/battlefield/**
  - apps/web/src/match/CardView.tsx
  - apps/web/src/match/CardView.test.tsx
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/src/i18n/en/battlefield.json
  - apps/web/src/i18n/en/match.json
  - apps/web/e2e/m4.spec.ts
  - docs/APPS.md
context:
  - docs/APPS.md#The match
  - docs/ART.md#Stills
  - docs/ART.md#The grid and the camera
  - apps/web/README.md#Text (D50)
  - apps/web/README.md#Tests
---

# T-161 — Pools and piles behind each grid

## Goal

From the human's playtest (2026-11-04): resources in play are public, and they "should be visible outside the grid on a new section behind player's grid", where every player can focus one to see its card. The main deck, the resource deck and the discard pile show their sizes, and the two decks show as "piles of reversed cards". D57 makes it a rule.

After this task, the battlefield draws a strip behind every seat's grid, outside the arena: the two decks as piles of card backs with their sizes, the resources in play as stills, rested ones darker and attached ones marked, and the discard pile with its newest card on top. A click on any of them opens the card view.

## Interfaces

What exists (copied on 2026-11-04, and from the T-153, T-157, T-160 and T-163 cards):

```ts
// packages/protocol: ArenaSeat { seat, origin, right, back, chaosEdge }. Grid cell { col, row } is world cell
// origin + col × right + row × back: row 0 faces the Chaos Grid, col 0 is on its player's left.
// ArenaLayout { width, height, cols, rows, seats, chaosGrid }. The default box is 130 × 130, and
// every grid's last row lies on the box's edge, so nothing fits behind a grid inside the box.
// PlayerSnapshot { ..., deckCount, resourceDeckCount, discardPile: { card, cardId, size, cost }[], pool: PoolCard[] }
// PoolCard { card, cardId, rested, attachedTo: SquadId | null }

// apps/web/src/match/battlefield
// view.ts: ViewTransform { turns, point, unpoint, rect, center, arena }; viewFor(arena, viewer) turns
//   the view so the viewer's `back` points down the screen.
// camera.ts: Camera { cellPx, center }. bounds(length, viewportPx, cellPx) keeps the centre inside
//   the arena; fitSize(arena, viewport); zoomSteps(arena, viewport) = 32, 16, 8, 4, then the fit;
//   initialCamera: 16 px per cell on the viewer's grid; frameCamera(seat) frames one grid.
// scene.ts: CELL = 16 world px per cell; DETAIL_PX = 16, below which units and permanents draw as
//   markers; LAYERS = ['cells', 'permanents', 'ground', 'projectiles', 'air', 'effects'];
//   Scene.draw(model, step). IconView draws pixel digits (glyphs.ts).
// pick.ts: BattlefieldPick { world, seat, cell, unit, permanent, squad } (squad: T-172); worldAt(point, camera, viewport, view);
//   pickAt(model, world).
// units-list.ts: unitListItems(model, cards): one line per living unit, which Battlefield.tsx
//   keeps in a visually hidden list beside the canvas.
// Battlefield.tsx: BattlefieldProps { model, step, viewer, cards, ..., onPick, onGrids, ... }.

// apps/web/src/match/CardView.tsx
export type CardViewSubject =
  | { kind: 'card'; card: Card; caption?: string; attached?: readonly Card[] }
  | { kind: 'prize'; seat: Seat; hp: number };
// MatchScreen.tsx › subjectOf(pick, state, cards): the pick's subject, with 'You' or `Seat ${n}`.
// match/planning/draft.ts › planView(state) = state.checked?.snapshot ?? state.snapshot.

// apps/web/src/art (T-160): ArtView(key, size), BackView(width, height), CardBack({ width, height }).
// apps/web/src/match/model (T-163): MatchModel.pools: Record<Seat, PoolCard[]>, from the events, so
// during Plan it's as Plan opened, the viewer's own pool included; attachedResources(model, squad).
```

## Deliverables

1. **The strip's layout**, a pure function in `battlefield/pools.ts` that the scene draws with and `pickAt` hits with. Each seat's strip is the `STRIP_ROWS` = 4 rows past its grid's last row, along `back`, as wide as the grid. From its player's left:
   - the main deck's pile and the resource deck's pile, each 2 × 3 cells;
   - the resources, in pool order, grouped into stacks: one card id in one state (unrested, rested, or attached to one squad), each 2 × 2 cells with its count when over 1, in up to two rows. When they don't fit, they take 1 × 1 cells. When even those don't fit, the last stack shows "+N";
   - the discard pile, 2 × 3 cells, at the right end.
2. **A wider world.** The camera's bounds, the fit size and the zoom steps use the arena box plus `STRIP_ROWS` on every side. `initialCamera` and `frameCamera` take a seat's strip with its grid.
3. **Drawing**, in a layer under `permanents`:
   - A deck pile is a few `BackView`s, each 1 px up and to the right of the one under it: one back for up to 5 cards, two up to 20, three above. Its size is in pixel digits under it. An empty pile draws its outline only.
   - The discard pile draws its newest card's still (`ArtView`) the same way.
   - A stack draws its card's still in its box. A rested stack draws as a rested unit does: `PALETTE.muted` tint, alpha 0.6. An attached stack has a 1 px outline in its seat's color.
   - Below `DETAIL_PX`, each one draws as a marker, as units do: a rect in the seat's color, darker when rested.
4. **Where the data comes from.** `BattlefieldProps` gains two props:
   - `piles?: Readonly<Record<Seat, PileSizes>>`, with `PileSizes = { deck: number; resourceDeck: number; discard: number; discardTop: CardId | null }`.
   - `planPools?: Readonly<Record<Seat, readonly PoolCard[]>>`, drawn instead of the model's pools.

   `MatchScreen` fills `piles` from the latest snapshot's `players`. While planning, it fills `planPools` from `planView(state)`'s players. That is the viewer's live pool, with its planned rests and attaches, and the others' as Plan opened (D57). Otherwise the strips draw the model's pools. A replay passes neither prop, so it draws the model's pools and no piles.
5. **Picks:** `BattlefieldPick` gains `pool: { seat: Seat; cards: readonly PoolCard[] } | null` (a stack) and `pile: { seat: Seat; pile: 'deck' | 'resourceDeck' | 'discardPile' } | null`.
6. **The card view:**
   - A stack opens `{ kind: 'card', card }` with a caption: "Seat 2's pool", then ", rested", ", attached to {squad}" or ", ×{n}" as they apply.
   - A deck pile opens a new subject, `{ kind: 'pile'; seat: Seat; pile: 'deck' | 'resourceDeck'; count: number }`. It shows `CardBack` in the large face's box and says "Seat 2's main deck: 87 cards" or "resource deck".
   - The discard pile opens its newest card, captioned "Seat 2's discard pile: 12 cards". An empty one opens nothing.
   - A unit's card view lists its squad's attached resources after its attached cards (`attachedResources`).
7. **The accessible list:** `poolListItems(...)` beside `unitListItems`, one line per seat, in a visually hidden list labelled "Pools and piles": "Seat 2: main deck 87, resource deck 24, discard pile 12. Pool: Ember Shard ×2, 1 rested; Tide Pearl, attached to Cinder Grunt."
8. **Text** in `en/match.json` (the captions and the pile subject) and `en/battlefield.json` (the list), with ICU plurals for the counts.
9. **`docs/APPS.md`** › The match: a bullet on the strips. Say what they show, and that they come from the model, the planning view while planning, and the latest snapshot's sizes.
10. **Tests:**
    - `pools` layout: the bottom seat's strip lies past its last row, and the left seat's is turned with its grid. Stacks group by card and state. Many resources take 1 × 1 cells, then "+N".
    - `camera.test.ts`: the bounds and the fit include the strips.
    - `pick.test.ts`: a stack and each pile are picked from their cells.
    - `CardView.test.tsx`: the pile subject shows the back and its count.
    - `MatchScreen.test.tsx`: during Plan the viewer's strip lists a resource rested for mana in its plan. A click on another seat's stack opens its card with the caption.
    - `e2e/m4.spec.ts`: after the first round's playback, the "Pools and piles" list has a line per seat, and the viewer's line names a resource.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test battlefield CardView MatchScreen` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `pnpm test:e2e` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Resting a resource from the strip: the tray's Mana button does it (T-158).
- Rested permanents drawn darker, rested squads in PlanGrid, and the Charge glow: T-162.
- Spells that target resources: no card has one yet (D57).

## Notes

- Defaults: the piles and stacks keep their place in the strip as the camera turns, so a seat's deck is always at its player's left. The opening camera may show part of the strip when the free part of the viewport is too short for both.
- PlanGrid lies over the viewer's grid only, so the strip behind it stays the battlefield's.
- The PR gives the sizes it settled on and lists the keys it added.
