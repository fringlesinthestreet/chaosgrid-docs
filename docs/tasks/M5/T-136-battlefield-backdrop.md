---
id: T-136
title: The battlefield behind the match
milestone: M5
depends_on: [T-118, T-124, T-128, T-140]
branch: agent/T-136-battlefield-backdrop
model: opus
effort: high
scope:
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/src/match/CardView.tsx
  - apps/web/src/match/CardView.test.tsx
  - apps/web/src/match/overlays/**
  - apps/web/src/match/planning/**
  - apps/web/src/match/battlefield/**
  - apps/web/src/theme/theme.css
  - apps/web/test/fixtures/session.ts
  - apps/web/e2e/m4.spec.ts
  - apps/web/src/i18n/en/overlays.json
context:
  - docs/tasks/M4/README.md#The match
  - apps/web/README.md#Rules a change must keep
  - apps/web/README.md#Text
---

# T-136 — The battlefield behind the match

## Goal

D51: the battlefield fills the match screen in every phase, and everything else floats over it. The screen fills the window under the page header. The top bar, the tray, the card view, the playback controls with T-128's timeline, and the overlays become panels in five regions over the canvas's edges, and the planning panel and the tray fold. When the camera frames a grid, it uses the part no region covers, so a framed grid isn't under a panel. Later overlays plug into the regions without editing `MatchScreen.tsx`.

## Interfaces

What exists (copied from the code on 2026-10-30, and from the T-128, T-140 and T-142 cards). Those cards change these files first, so re-read them:

```tsx
// apps/web/src/match/MatchScreen.tsx
// Screen (:150-231): onPick opens subjectOf(pick) (:125) in the card view; onGrids sets `grids`;
//   frameRequest is { seat: framed ?? seat, round } while planning, so Plan's start, a "Grids" tab
//   and a pick each frame a grid. It renders, in flow:
<SessionContext.Provider value={session}>
  <div data-match-screen="">
    <TopBar state={state} />                {/* header "Match status" (:39) */}
    {/* the error Panel "The game stopped: …" with "Back to Play" */}
    <div style={{ position: 'relative', height: 'min(70vh, 640px)', minHeight: 360 }}>
      <Battlefield model step viewer={seat} cards stepMs chaosBanner={false}
        frameRequest={frameRequest} onPick={onPick} onGrids={setGrids}>
        <div ref={setLayerHost} data-plan-layer="" />
      </Battlefield>
      {/* isRoundOver (:35): the absolute "Round over" status */}
    </div>
    {playing && state.error === null && <PlaybackControls playback={session.playback} />}
    {planning && model.settings !== null && (
      <ReadyBar key={model.round} session={session} planSeconds={model.settings.planSeconds} />
    )}                                       {/* group "Ready" (:85) */}
    <LayerSpaceContext.Provider value={layerSpace}>
      <PlanningProvider>
        {planning && <PlanLayer />}
        <Tray />
        {planning && <PlanningPanel />}
      </PlanningProvider>
    </LayerSpaceContext.Provider>
    <Overlays />
    <CardView />
  </div>
</SessionContext.Provider>
// MatchScreen (:233) wraps Screen in CardViewProvider.
// PlanLayer (planning/Layers.tsx) holds T-117's own-grid layer and T-118's target layer, and
//   portals them into div[data-plan-layer] (Layers.tsx:30). The comment above layerHost says why:
//   "the provider remounts every round and the battlefield must not".
// CardView.tsx: an aside, .cg-card-view (theme.css:135-143: fixed, top, right and bottom 0,
//   z-index 30, width 360px). From T-142 its Escape listener runs in the capture phase and marks
//   the event, so the first Escape closes the card view and the second cancels a selection. From
//   T-140 a unit's view lists the cards attached to its squad, and the shown card is CardView's own
//   state.

// apps/web/src/match/overlays
// index.tsx:7-16: Overlays() renders div[data-overlays] with layerStyle, then RoundBanner,
//   RoundSummaryCard, LogDrawer and GameOver.
// panels.tsx: layerStyle (:26-31: fixed, inset 0, pointerEvents none, zIndex 20); interactive =
//   { pointerEvents: 'auto' } (:32). Each piece places itself in the layer:
//   RoundBanner (:35): the "Chaos" button (aria-label "Chaos cards of this round", top 8, right 8,
//     :51-52) and the region "Round banner" (top 12%, centred, :60-67)
//   RoundSummaryCard (:95): the region "Round summary" (top 48, left 8, maxWidth 320, :126-127),
//     not while playing
//   LogDrawer (:169): `open` state (:173), the "Log" button (aria-expanded, top 8, right 84, :188)
//     and the complementary "Round log" (top 48, right 8, bottom 8, width 360, :196-197)
//   GameOver (:228): the dialog "Game over", centred (:250)
// T-128: jump links in the summary and the log; TimelineBar under PlaybackControls' buttons, as
//   wide as its container.

// apps/web/src/match/planning
// index.tsx: PanelBody (:110): div[data-planning-panel] (:194, display flex, gap 24) holds a left
//   column (the selection's status line with Rotate, TargetPicker, SquadPanel, PermanentPanel) and
//   div[data-plan-side] (:220, flex 1): the Leader, the rules bar, the Plan list and Zones. The
//   selection's Escape and R listen on the window (:138-155). PlanningProvider (:289) mounts
//   <PlanProvider key={view.round}> (:294) whenever there's a snapshot, so everything inside it
//   remounts when a round's snapshot arrives. PlanningPanel (:301): section "Planning panel" > h2
//   "Planning".
// Tray.tsx: the "Hand" (:44), "Resources" (:56) and "Discard pile" (:82) groups as rows; while
//   state.discarding, the "Discard" group (DiscardHand) takes the hand's place (:46-47).

// apps/web/src/match/battlefield
// mount.ts: BattlefieldOptions (:23-32). The host is position relative, 100% × 100%, min-height
//   320px, overflow hidden (:52). A ResizeObserver resizes the canvas and calls scene.setViewport
//   (:123-129). A drag pans and pointerdown focuses the host (:141-172; a pointerup within
//   CLICK_SLOP_PX, 4 px, is a pick), the wheel zooms (:174), and the arrows, + and =, − and Home
//   act on the focused host only (:179).
// camera.ts: initialCamera(arena, viewport, seat) (:63): 16 px per cell (OPEN_CELL_PX, :24),
//   centred on the seat's grid and not clamped; for null, the whole arena at its fit size.
//   frameCamera(arena, viewport, seat) (:83, T-117) centres the seat's grid, zoomed so it fits.
//   zoom (:105) clamps to zoomSteps (:33); pan (:123) never shows past the arena's edge.
//   cameraOrigin (:97) puts the root at round(viewport / 2 − center × cellPx).
// scene.ts: SceneOptions (:48-57); setViewport (:436), focus(seat) (:442), frame(seat) (:447), and
//   the first camera, built in draw (:601-605); setCamera (:526).
// Battlefield.tsx: BattlefieldProps (:9-27); the scene is rebuilt on [viewer, cards, chaosBanner]
//   (:54-68), and frameRequest calls frame (:83-85).

// apps/web/src/theme: Panel (components.tsx:22) is div.cg-panel: --cg-panel background, a 2 px
//   --cg-border border, 1rem padding (theme.css:78-82). body has min-width 1024px (theme.css:26).
// apps/web/src/app/Layout.tsx: header.cg-header (the page's banner), then main.cg-main (padding
//   1.5rem, app.css:34-36). match/index.tsx puts <h1>Match</h1> above the screen.
// apps/web/e2e/m4.spec.ts:174-197: in round 2's Plan the summary's box is apart from the "Ready"
//   group and the "Planning panel" (the `apart` helper, :187-195). The viewport is Desktop
//   Chrome's, 1280 × 720.
```

What this task adds:

```tsx
// overlays/Hud.tsx. overlays/index.tsx exports Overlays and the HudPieces type.
/** What MatchScreen hands the HUD. Each piece goes to its region; MatchScreen passes one only while it shows. */
export interface HudPieces {
  topBar?: ReactNode;   // top
  status?: ReactNode;   // center: the error and "Round over"
  planning?: ReactNode; // left, under the round summary; folds
  playback?: ReactNode; // bottom: PlaybackControls, with T-128's bar
  tray?: ReactNode;     // bottom, under the controls; folds
  ready?: ReactNode;    // bottom, at the tray's right
  cardView?: ReactNode; // right, under the log
}
/** The regions over the battlefield, the overlays' own panels in them, and the game over modal over all. `freeArea` gets the center region. */
export function Overlays({ pieces, freeArea }: { pieces?: HudPieces; freeArea?: Ref<HTMLDivElement> }): JSX.Element;
/** Folds to its toggle, a button named `label` with aria-expanded. Folded, the content stays mounted and hidden. */
function HudPanel({ label, unfoldKey, children }: { label: string; unfoldKey?: string | null; children: ReactNode }): JSX.Element;

// battlefield/camera.ts
/** Px of the viewport that panels cover, from each edge. */
export interface Insets { top: number; right: number; bottom: number; left: number }
export const NO_INSETS: Insets; // all 0
export function initialCamera(arena: ArenaLayout, viewport: Viewport, seat: Seat | null, insets?: Insets): Camera;
// frameCamera (T-117) takes `insets` last in the same way.
// scene.ts
export interface SceneOptions { /* … */ insets?: () => Insets } // read each time the scene builds a camera
// mount.ts
export interface BattlefieldOptions { /* … */ freeArea?: () => Element | null }
// Battlefield.tsx
export interface BattlefieldProps {
  // …
  /** The part of the battlefield no panel covers: the first camera, Home and the frames centre on its box. Read when a camera is built, so it never rebuilds the scene. */
  freeArea?: RefObject<HTMLElement | null>;
}
```

## Deliverables

1. **The screen fills the window.** `div[data-match-screen]` is absolute against the page. Its top is its parent's top on the page (`main`, right under the header), and it has left 0, right 0, bottom 0, min-width 1024 px and overflow hidden. A layout effect measures the top on mount, on window resize, and when the body's size changes (a ResizeObserver, when there is one: a web font can change the header's height after mount). The page's `<h1>Match</h1>` stays in the DOM under the screen.
2. **The battlefield behind everything.** In every phase the battlefield box is absolute at inset 0 of the screen. It holds `<Battlefield … freeArea={freeArea} />` and T-117's and T-118's layers, as now. After it comes `<Overlays pieces={…} freeArea={freeArea} />`, with everything else the screen shows as a piece. A panel opening, closing or folding never changes the box.
3. **The regions** (`Hud.tsx`). The HUD is a CSS grid over the screen, at inset 0: columns `auto 1fr auto`, rows `auto 1fr auto`. Each region carries `data-hud-region`:

   | Region | Holds, in order |
   | --- | --- |
   | `top`, across all columns | the top bar |
   | `left` | the round summary, then the planning panel (folds as "Planning") |
   | `center` | the status: the error and "Round over". It's the free area |
   | `right` | the round banner with its Chaos button, the round log with its button, the card view |
   | `bottom`, across all columns | the playback controls, then the tray (folds as "Your cards") with the Ready bar at its right |

   - The game over modal covers the whole screen, as now.
   - A region is a column of panels. A panel that doesn't fit shrinks and scrolls inside itself (min-height 0, overflow auto), so no panel leaves its region.
   - Left panels are 320 px wide and right ones 360 px. A side column with nothing in it takes no room.
   - The HUD and its regions have pointer-events none, and each panel auto, so the battlefield gets drags, clicks and the wheel wherever no panel is.
   - DOM order: top, left, center, right, bottom, then the modal.
4. **Each piece drops its own placement.**
   - panels.tsx: RoundBanner, RoundSummaryCard and LogDrawer lose their absolute positions, and `layerStyle` goes. GameOver stays a modal over the screen.
   - CardView (T-115) loses its fixed position and sits in the right region. Its Escape order (T-142), its list of attached cards (T-140) and the focus return stay.
   - TopBar and ReadyBar become `Panel`s and lose their margins.
   - The planning panel is one column (`data-planning-panel` and `data-plan-side` stay). The tray's groups sit side by side in one band, each scrolling sideways.
5. **Folding.** `HudPanel` wraps the planning panel and the tray.
   - Its toggle is a button named "Planning" or "Your cards", with `aria-expanded` and `aria-controls`.
   - Folded, the content is `hidden` but stays mounted, so the plan state, ticked checkboxes and T-117's layer stay.
   - The tray unfolds when the seat's Plan or Discard step starts. `unfoldKey` is `plan:<round>` while `state.planning`, `discard:<round>` while `state.discarding`, else null, and a non-null key other than the last non-null one unfolds it. The planning panel mounts open each Plan.
6. **The free area.** The center region is `freeArea`.
   - When the scene builds a camera for a seat or the arena (the first camera, Home and T-117's frame), it calls `insets()`. mount.ts makes the insets from the host's box and the free area's box: how far each edge of the free area sits inside the host, at least 0. With no free area they're `NO_INSETS`.
   - `initialCamera` centres the seat's grid in the free part, still at 16 px, and for null fits the whole arena into it. T-117's frame centres and fits the grid into it.
   - Pan, zoom and resize keep today's bounds. The replay passes no free area and is unchanged.
7. **Later overlays.** A later overlay is one more component in its region, in Hud.tsx: a standings strip in `top` after the top bar, a rules drawer in `left` or `right` with its own button. MatchScreen doesn't change for it. Hud.tsx's header comment says so.
8. **Text** (D50). "Planning" and "Your cards" go through `t()`, in `en/overlays.json`.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test MatchScreen overlays planning battlefield CardView` passes, with tests for:
  - [ ] each piece in its region in Plan, during playback, in the Discard step and at game over, and the Battlefield there in every phase
  - [ ] the overlays alone (`<Overlays />`): the summary in `left`, the banner and the log in `right`
  - [ ] pointer-events none on the HUD and its regions, and auto on each panel
  - [ ] folding: `aria-expanded`, the content hidden but mounted (a ticked checkbox stays ticked), and the tray unfolding on a new `plan:` or `discard:` key but not on the same key again
  - [ ] `initialCamera` and T-117's frame with insets: the grid's centre lands on the free part's centre, the frame fits the grid into it, and `NO_INSETS` gives today's cameras
  - [ ] the scene calling `insets()` when Home runs, not earlier (a stub getter whose value changes in between)
  - [ ] the card view in its place, with no fixed position
- [ ] `grep -rn -E "position: ?'?fixed" apps/web/src/match apps/web/src/theme/theme.css` prints nothing
- [ ] `pnpm --filter @chaosgrid/web test replay` passes unchanged. Write both filters with no `--`: after `--`, Vitest runs every file.
- [ ] `pnpm test:e2e` passes. m4.spec.ts checks these in round 2's Plan at 1280 × 720, then sets 1024 × 768 and checks them again in round 3's Plan:
  - [ ] `[data-battlefield]` has the box of `[data-match-screen]`, which starts at the bottom of the page's banner and ends at the window's bottom
  - [ ] the page doesn't scroll: the document's `scrollWidth` and `scrollHeight` are at most the window's
  - [ ] the own-grid layer (`[data-plan-grid]`) lies inside `[data-hud-region="center"]`, within 1 px
  - [ ] the summary is `apart` from "Ready", the "Planning panel" and "Match status", and the "Planning panel" from the tray's "Hand"
  - [ ] at 1280 × 720, "Your cards" folds the tray: "Hand" is hidden and the battlefield's box doesn't change. A second click shows "Hand" again

## Out of scope

- New overlays, such as a standings strip or a rules drawer: deliverable 7 only leaves room for them.
- Camera keys from anywhere in the match. The arrows, + and − and Home still need the battlefield's focus, which a click on it or Tab gives it.
- On-screen camera buttons, a way to pan without dragging (WCAG 2.5.7).
- Free-area bounds for pan and zoom: a framed camera that zooms is clamped as today.
- The replay's layout, and `playback/**`: T-128's bar is placed, not changed.
- Moving the existing text into `t()`, and hiding the page's h1 (`match/index.tsx`).
- `apps/web/README.md`: the lead updates its match section after this task merges.

## Notes

- D51: "The battlefield fills the match screen, and everything else floats over it. … Panels can collapse; none of them pushes the battlefield aside. Later panels plug into the overlay regions without editing `MatchScreen.tsx`." D51 accepts that panels hide much of the battlefield at 1024 px: there the planning panel takes the left 320 px, and it folds.
- Default: the panels keep the opaque `cg-panel` look, so their text stays readable over a busy battlefield.
- Without the free area, T-117's frame would fill the whole screen, and the grid's front row would lie under the top bar and its back rows under the tray. The e2e's "col 7, row 0" click would hit the top bar.
- The free area is read when a camera is built, after React commits, so the planning panel that mounts with Plan is already in place when T-117's frame runs. A side column changes width when a panel in it opens or folds; the camera doesn't move then.
- jsdom has no layout: every box is zeros, so the top and the insets are 0. Tests stub `getBoundingClientRect` where they check insets.
- PlanningProvider's PlanProvider is keyed by round, so everything inside it remounts when a round's snapshot arrives. Keep `<Overlays>` outside it, or the log's open state, the banner's, the summary's and the game over's would reset every round. The tray and the planning panel stay under the one PlanningProvider, as now, although they sit in different regions: MatchScreen passes host divs as `pieces.tray` and `pieces.planning` and portals `<Tray />` and `<PlanningPanel />` into them, the way the battlefield layers are portalled (planning/Layers.tsx:30). CardViewProvider wraps the screen, as now.
- The planning panel's Esc and R listen on the window, so they still work while it's folded. The card view's Escape still comes first (T-142): one press closes the card view, the next cancels the selection.
- A focused cell of T-117's layer can end up under a panel after a pan or a zoom. Folding or panning shows it.
- `Overlays` gains optional props, so `<Overlays />` still works in the overlay tests, as M4/README.md › Placeholders now says.
- T-120 (wave 23) adds `speed` beside `freeArea` and `insets` on the option and prop types, and T-121 adds `upcoming`. Keep `freeArea` out of the scene's rebuild dependencies.
- The e2e reaches round 3's Plan the way it reaches round 2's (`expect(await skipToPlan(page)).toBe('plan')`), after `page.setViewportSize`, so T-117's frame runs at the new size. Then the existing loop goes on. The page's banner is `page.getByRole('banner')`.
