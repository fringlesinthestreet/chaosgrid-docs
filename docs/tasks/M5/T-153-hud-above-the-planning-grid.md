---
id: T-153
title: HUD above the planning grid
milestone: M5
depends_on: []
branch: agent/T-153-hud-above-the-planning-grid
model: sonnet
effort: medium
scope:
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/battlefield/Battlefield.tsx
  - apps/web/e2e/m4.spec.ts
context:
  - apps/web/README.md#Tests
---

# T-153 — HUD above the planning grid

## Goal

The human's playtest (2026-11-04): during Plan the planning grid lies over the tray, so the hand can't be scrolled and part of the resources can't be seen. After this task every HUD panel is drawn above the planning layers wherever they overlap and takes its own clicks and wheel, and the e2e checks it.

## Interfaces

The cause, found by the lead (copied from the code on 2026-11-04):

```tsx
// apps/web/src/match/planning/PlanGrid.tsx:58-78, placedStyle: a grid over its place on the battlefield
return {
  position: 'absolute',
  left: …, top: …, transform: …,
  zIndex: 1,
  background: clear ? 'transparent' : 'var(--cg-bg)',
};

// apps/web/src/match/battlefield/Battlefield.tsx:111-117
// The canvas host is appended after the children, so they need a z-index to lie on top of it.
<div ref={element} style={{ position: 'relative', width: '100%', height: '100%', overflow: 'hidden' }}>
  {children}
</div>

// apps/web/src/match/MatchScreen.tsx:229-262: the screen, the battlefield's wrapper, the layers, the HUD
<div ref={screen} data-match-screen="" style={{ position: 'absolute', top, left: 0, right: 0, bottom: 0, minWidth: 1024, overflow: 'hidden' }}>
  <div style={{ position: 'absolute', inset: 0 }}>
    <Battlefield …>
      <div ref={setLayerHost} data-plan-layer="" />
    </Battlefield>
  </div>
  …
  <Overlays freeArea={freeArea} pieces={{ …, tray: <div ref={setTrayHost} />, … }} />
</div>

// apps/web/src/match/overlays/Hud.tsx:33-40, the HUD's root: positioned, no z-index
const hudStyle: CSSProperties = { pointerEvents: 'none', position: 'absolute', inset: 0, display: 'grid', … };
```

No element between PlanGrid and the page sets a z-index or `isolation`, so none of them makes a stacking context. PlanGrid's `zIndex: 1` then competes with the HUD in the page's stacking context, and a positioned box with z-index 1 paints over one with z-index auto wherever they overlap, whatever the DOM order. The grid takes the clicks and the wheel there too. The target picker's grids on other seats (T-118) use the same style.

`apps/web/e2e/m4.spec.ts` › `checkHud(page)` (lines 81-121) runs during Plan. It checks that the battlefield fills the screen, nothing scrolls, the own grid lies in the HUD's free area, and the panels leave each other room. `boxOf(locator)` measures a box, and `panelOf('Your cards')` is the tray's panel. The camera zooms with `+` and `-` and the wheel (D51).

## Deliverables

1. **The fix.** The battlefield's wrapper in `MatchScreen.tsx` makes its own stacking context (`isolation: 'isolate'`, or `zIndex: 0` on the positioned wrapper), so the planning layers stay above the canvas and below every HUD panel. One line of comment says why. `Battlefield.tsx` is in scope only if the fix sits better there.
2. **The check,** a new step at the end of `checkHud`: zoom in until the own grid reaches under the tray (`+` once or twice, whatever is deterministic at the spec's viewport), then:
   - `document.elementFromPoint` at the centre of the tray's last hand entry and of its last resource entry lands inside `[data-tray]`;
   - a wheel over the tray leaves `[data-plan-grid]`'s box as it was, so the battlefield didn't zoom under it;
   - the camera goes back as it was (`-` as many times), so the rest of the spec runs as before.
3. Nothing else changes: the target picker still picks on other seats' grids, and the planning layers still take clicks where no panel covers them.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm test:e2e` passes with the new step. Run the step once without the fix and say in the PR that it failed then.
- [ ] `pnpm --filter @chaosgrid/web test MatchScreen Layers Battlefield` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The tray's own layout and size: T-152 makes its tiles card faces.
- The free area the camera frames: T-136's.

## Notes

- Default: `isolation: 'isolate'` on MatchScreen's battlefield wrapper. jsdom has no layout, so only the e2e can see this bug.
