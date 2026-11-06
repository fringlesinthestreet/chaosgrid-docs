---
id: T-188
title: Grid clear of the tray and seat colors on the TopBar
milestone: M5
depends_on: []
branch: agent/T-188-grid-clear-of-the-tray-and-seat-colors-o
model: sonnet
effort: medium
scope:
  - apps/web/src/match/battlefield/camera.ts
  - apps/web/src/match/battlefield/camera.test.ts
  - apps/web/src/match/battlefield/mount.ts
  - apps/web/src/match/battlefield/scene.ts
  - apps/web/src/match/battlefield/scene.test.ts
  - apps/web/src/match/battlefield/Battlefield.tsx
  - apps/web/src/match/battlefield/Battlefield.test.tsx
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/src/theme/theme.css
  - apps/web/src/i18n/en/match.json
context:
  - docs/DECISIONS.md#Decision log
  - docs/APPS.md#The match
  - apps/web/README.md#Rules a change must keep
---

# T-188 — Grid clear of the tray and seat colors on the TopBar

## Goal

Two things from the human's playtest (2026-11-05). The viewer's grid went behind the tray (the hand and the resources) during Plan; after this PR the camera keeps the grid and its strip in the part of the screen the panels leave free, whenever that part changes size (D71). The TopBar's points also show each seat in its color, so the scores match the grids.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// apps/web/src/match/overlays/Hud.tsx:33 — the HUD is a grid: rows 'auto minmax(0, 1fr) auto', columns 'auto 1fr auto';
// the bottom row (playback, the tray's HudPanel, Ready) grows with the tray, so the centre region shrinks.
// :134 <div ref={freeArea} data-hud-region="center" …>  — the free area MatchScreen passes to the battlefield

// apps/web/src/match/battlefield/mount.ts
function insetsOf(host: Element, area: Element | null): Insets   // :62: how far the free area lies inside the host
// :113 the scene reads `insets: () => insetsOf(host, options.freeArea?.() ?? null)` only when it frames
// :163 const observer = … new ResizeObserver(resize); observer?.observe(host);   — the host only, never the free area

// apps/web/src/match/battlefield/camera.ts
export interface Insets { top; right; bottom; left }             // :23
function freePart(viewport: Viewport, insets: Insets): Viewport  // :33
export function initialCamera(arena, viewport, seat, insets = NO_INSETS): Camera  // :128: 16 px a cell, centred on the
//   seat's grid and strip, moved the least that keeps the whole grid in view *when it fits*
export function frameCamera(arena, viewport, seat, insets = NO_INSETS): Camera | null // :152: the largest whole cell size at which both fit

// apps/web/src/match/battlefield/scene.ts
setViewport(viewport: Viewport): void          // :898
focus(seat: Seat | null): void                 // :904 → initialCamera(…, this.insets())
frame(seat: Seat): void                        // :910 → frameCamera(…, this.insets())
// :1141-:1146 the camera keeps its place across draws and rounds, unless the arena changes size.
// Nothing records whether the player has panned or zoomed since the last automatic framing.

// apps/web/src/match/MatchScreen.tsx:57-:90 TopBar:
<ul aria-label="Points" …>
  {model.seats.map((seat) => (
    <li key={seat} data-seat={seat}>{seat === state.seat ? <strong>{name(seat)}</strong> : name(seat)}: {model.points[seat] ?? 0}</li>
  ))}
</ul>
// The seat colors are CSS custom properties: `var(--cg-seat-0)` … `var(--cg-seat-3)` (theme/palette.ts, checked by palette.test.ts).
```

## Deliverables

1. **The free area is watched.** The battlefield observes the free area's size as well as the host's, and tells the scene when the insets change.
2. **The grid stays clear.** When the insets change, or Plan starts, the scene frames the viewer's grid and strip in the free part, unless the player has panned or zoomed since the last automatic framing; then their camera stays. A new Plan starts automatic framing again. When the grid and strip don't fit the free part at 16 px a cell, the framing zooms out to the largest whole size at which they fit (`frameCamera`), so no row hides behind the tray or the planning panel. Spectating and replays keep today's camera.
3. **Seat colors in the points.** Each points item starts with a small swatch in its seat's color (`var(--cg-seat-N)`, a class in `theme.css`, `aria-hidden`), before the name, which stays as text ("You" in bold). The color never carries the meaning alone. The swatch's edge has 3:1 contrast with the panel.
4. **Tests.**
   - `camera.test.ts`: with a bottom inset as tall as a tray, the framed grid and strip lie inside the free part, zoomed out when needed.
   - `scene.test.ts`: an insets change re-frames when the camera was automatic, and keeps the camera after a pan.
   - `MatchScreen.test.tsx`: each points item has a swatch with its seat's color.
   - `Battlefield.test.tsx` where it builds the battlefield with a free area.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test camera scene Battlefield MatchScreen` passes.
- [ ] `pnpm test` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The tray's own size: T-199 makes it one row high.
- `planning/**` and `CardView`: T-185 edits them beside you.
- The strips' piles: T-190.

## Notes

- Lead default: "automatic" means the camera hasn't been dragged, zoomed or moved by keys since the last framing. Home ("back to the viewer") frames again and counts as automatic.
- jsdom has no ResizeObserver (`mount.ts` already guards for that). Drive the scene's insets change directly in the tests.
