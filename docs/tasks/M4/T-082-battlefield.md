---
id: T-082
title: Battlefield scene and the replay viewer
milestone: M4
depends_on: [T-075, T-081]
branch: agent/T-082-battlefield
model: opus
effort: high
scope:
  - apps/web/src/match/battlefield/**
  - apps/web/src/art/**
  - apps/web/src/replay/**
  - apps/web/e2e/replay.spec.ts
context:
  - docs/tasks/M4/README.md#The match
  - docs/tasks/M4/README.md#Web layout and ownership
  - docs/PROTOCOL.md#Coordinates
  - docs/PROTOCOL.md#Arena layout
  - docs/PROTOCOL.md#Timeline
---

# T-082 — Battlefield scene and the replay viewer

## Goal

The match and the replay both need to show the arena. After this task `match/battlefield/` draws a `MatchModel` with PixiJS: the four grids, the Chaos edges and the Chaos Grid, squads, units, projectiles, permanents, prizes and Emblems, through a camera that pans and zooms in whole-pixel steps. Sprites are keyed by card id (D13): placeholders drawn in code, or real art when the art manifest lists it (D39). `/replay` loads a sim-cli event log and shows it one step at a time, which is how the scene is checked before the live match exists.

## Interfaces

What exists (T-068, T-081, and the protocol):

```ts
// apps/web/src/match/model (T-081)
export interface MatchModel { arena; squads; units; projectiles; permanents; points; round; phase; tick; … }
export const EMPTY_MODEL: MatchModel;
export function applyEvents(model: MatchModel, events: readonly Event[]): MatchModel;
// apps/web/test/fixtures/logs/*.json (T-081): sim-cli logs, one with an Emblem

// @chaosgrid/protocol
export function groupByTick(events: readonly Event[]): TimelineStep[]; // { tick, events }, Simulate only
export const Event; export const ArenaLayout; // Zod schemas
// PROTOCOL.md › Arena layout: grid cell → world cell is origin + col × right + row × back.
// The arena is 130 × 130 cells today: four 30 × 30 grids around the 50 × 50 Chaos Grid (x, y ∈ [40, 90)).
// Owner = Seat | 'chaos': a Chaos unit's owner is 'chaos'; a token's is its seat, and neither has a `squads` entry.

// apps/web/src/cards (T-075): useCards() → { status: 'ready', cards, byId: Map<CardId, Card>, … } | …; GET /api/cards needs no login
// @chaosgrid/cards: Card.keywords.shield and .extraLife are a number or a formula like '{level}'
// apps/web/src/art (T-068): spriteFor(key: string): SpriteSpec { color: string; url?: string }, for a card id or a `ui.<name>` key:
//   today the placeholder color from the key's hash and no url. CardArt({ cardId, size }) draws a card's art in the DOM.
// apps/web/src/theme (T-068): PALETTE.seat (four colors) and PALETTE.chaos, as numbers for Pixi
// apps/web/src/vite-env.d.ts (T-068): import.meta.env.VITE_CHAOSGRID_ART_URL?: string, unset in the repo (D39)
// apps/web/test/fixtures/api.ts (T-068): stubApi(routes) and cardsBody(cards)
// apps/web/src/replay/index.tsx (T-068 placeholder): ReplayPage
```

What this task adds:

```ts
// apps/web/src/match/battlefield/
export function gridToWorld(seat: ArenaSeat, cell: Cell): WorldCell;
// camera.ts, pure, no Pixi
export interface Camera { cellPx: number; center: { x: number; y: number } } // center in world cells
export interface Viewport { width: number; height: number }                   // CSS px
/** Whole-pixel cell sizes, largest first: 32, 16, 8, 4, then the largest that fits the whole arena (at least 1). */
export function zoomSteps(arena: ArenaLayout, viewport: Viewport): number[];
/** 16 px per cell on `seat`'s grid; for null, the whole arena at its fit size. */
export function initialCamera(arena: ArenaLayout, viewport: Viewport, seat: Seat | null): Camera;
export function zoom(camera: Camera, steps: number, arena: ArenaLayout, viewport: Viewport): Camera; // +1 in, −1 out
export function pan(camera: Camera, dx: number, dy: number, arena: ArenaLayout, viewport: Viewport): Camera; // px, clamped
/** Mounts a Pixi canvas in the element and draws the model. Pure drawing: it never reads core or the transport. */
export function createBattlefield(element: HTMLElement, options: { viewer: Seat | null; cards: ReadonlyMap<string, Card> }): Battlefield;
export interface Battlefield {
  /** Draws `model`. `step` are the events that took it there, for one-off effects (a hit, a death, a trigger). */
  draw(model: MatchModel, step?: readonly Event[]): void;
  /** Tween length for moves, in ms; playback (T-083) sets it from the speed. */
  setStepDuration(ms: number): void;
  /** Moves the camera back to `initialCamera` for `seat`. */
  focus(seat: Seat | null): void;
  destroy(): void;
}
export function Battlefield(props: { model: MatchModel; step?: readonly Event[]; viewer: Seat | null; cards: ReadonlyMap<string, Card>; stepMs?: number }): JSX.Element;

// apps/web/src/art/ (D39)
/** Reads `${baseUrl}/manifest.json` (art key → file name) once. No base URL, a failed fetch or a bad file: placeholders only. */
export function loadArtManifest(baseUrl: string | undefined): Promise<void>; // art/manifest.ts
export function spriteFor(key: string): SpriteSpec; // T-068's, plus url = `${baseUrl}/${file}` for a key the manifest lists
export const UI_ART_KEYS = ['ui.cardBack', 'ui.emblem', 'ui.prize', 'ui.fear', 'ui.shield', 'ui.extraLife', 'ui.token'] as const;

// apps/web/src/replay/
export function parseLog(text: string): Event[]; // throws a LogError with a readable message
export function ReplayPage(): JSX.Element;
```

## Deliverables

1. **The scene** (`battlefield/`, PixiJS):
   - Layers, bottom to top: the cells (each seat's grid tinted with its seat color, the Chaos edges, the Chaos Grid), permanents and prizes, ground units, projectiles, air units, effects.
   - Squads: a squad not yet spawned (Plan) shows its footprint from `squad.placed` (`gridToWorld` of `cell`, `size`, `rotated`), with the card's sprite and level. A squad with `retired: true` stays in the model for the round log (T-081, T-088), and the scene draws nothing for it.
   - Units: the sprite at `at`, tweened from `from` over the step duration; an HP bar (`hp` / `maxHp`); dead units fade out; rested ones are greyed; the Leader has a marker.
   - Chaos and token units (no `squads` entry): a Chaos unit (owner `'chaos'`) in the neutral color, a token in its seat's color with a token marker.
   - Unit state (T-081): a fear icon while `fearedUntil` is set; a Shield icon with `shieldLeft`, and an Extra life icon with `livesLeft`. While those are null, a unit whose card (from `cards`) has `keywords.shield` or `keywords.extraLife` gets the icon without a number.
   - Permanents: traps face down as a card back (only the owner's are in the model face up), artifacts and enchantments by sprite, Emblems on the Chaos Grid with their HP.
   - Prizes: a 2×2 sprite on each grid at its `cell` and `size`, in its seat's color, with an HP bar; greyed and cracked while `alive` is false.
   - Effects from `step` (drawn once, ~300 ms): `unit.attacked` a line from attacker to target, `unit.damaged` a red number, `unit.healed` a green one, `unit.died` a puff, `ability.triggered` and `trap.fired` a flash on the source, `chaos.revealed` a banner.
   - M3 effects, the same way: `unit.shielded` a shield flash, `unit.saved` a flash and "+life", `squad.sacrificed` a flash, `squad.revived` and `unit.respawned` and `permanent.respawned` a glow, `squad.despawned` and `chaos.despawned` a puff, `card.banished` a fade, `emblem.broken` a burst.
   - `viewer` is the seat drawn at the bottom; `null` (replay) keeps the layout as it is. Rotate the view with the seat's `back`, so the viewer's grid is always the bottom one.
   - **Camera** (decision, 2026-10-28): it opens on the viewer's grid at 16 px per cell (`initialCamera`), and on the whole arena when `viewer` is null. Drag or the arrow keys pan, clamped to the arena; the wheel or `+` and `−` step through `zoomSteps`; `Home` calls `focus(viewer)`. Cell sizes stay whole pixels and sprites draw at whole multiples (`roundPixels`, nearest scaling), so pixel art stays sharp. Below 16 px per cell, units draw as seat-colored markers one cell wide (neutral for Chaos), and permanents and prizes as colored squares. The camera keeps its place across `draw`s.
2. **Art** (`art/`, D13, D39): no image files are committed; the repo keeps only placeholders.
   - `loadArtManifest` runs once, the first time `art/` is used, with `import.meta.env.VITE_CHAOSGRID_ART_URL`, and checks the manifest with Zod. A key it lists gets its `url`. An image loads the first time it's drawn, and its hashed name lets the browser cache it.
   - An unset URL, a failed or bad manifest, an unlisted key or an image that fails to load draws the placeholder, in the scene and in `CardArt`.
   - Placeholders drawn in code for `UI_ART_KEYS`, each with its own shape: the card back, the Emblem, the prize, and the fear, Shield, Extra life and token icons. Every other key keeps T-068's colored square.
   - Sizes, for placeholders and real art alike: 16×16 for a unit, 32×32 for the card back, the Emblem and the prize.
   - Once the manifest has loaded, `CardArt` re-renders with the images, and the scene uses them from its next `draw`.
   - `src/art/` is the only place that knows art URLs and file names. `art/manifest.ts` is the only file outside `src/api/` that calls `fetch` (T-068's lint rule allows it).
3. **An accessible list.** Next to the canvas, a visually hidden `<ul aria-label="Units">` with one item per living unit, "<card name> (seat <n>) <hp>/<maxHp> at <x>,<y>" ("(Chaos)" for a Chaos unit, the card id when `cards` doesn't have it), updated on each `draw`. Tests and screen readers read it.
4. **Replay viewer** (`/replay`): it waits for `useCards()` (an error shows with Retry), then you pick a file (`<input type="file">`) or drop it; `parseLog` checks it with the protocol's `Event` schema and shows the first bad line on failure. Then it shows the battlefield and a step list: Previous, Next, a round picker, a focus picker (the arena or a seat's grid, calling `focus`), and the current round, phase and tick. The model at a step is `applyEvents` up to that step: Begin and Plan events count as one step each round, then one per `TimelineStep`, then Cleanup. T-083 replaces the buttons with timed playback.
5. **Tests:**
   - `gridToWorld` against PROTOCOL.md's example and each seat's corners on a 4-seat layout from a fixture's `round.started`
   - camera: `zoomSteps` are whole numbers, largest first, and end with a size at which the arena fits the viewport; `initialCamera` for each seat is 16 px per cell and centred on that seat's grid, and for null is the last zoom step centred on the arena; `zoom` stops at both ends; `pan` never shows past the arena's edge
   - `parseLog`: the fixtures parse; a bad line names its line number; a non-array file fails
   - with a fixture: the page's step list stepping to the end of round 1 shows the units of the model at that point in the hidden list
   - the page's tests stub `GET /api/cards` with `stubApi` and `cardsBody` (T-068), and the e2e serves it (its config runs the API from T-074)
   - the scene builds and destroys in jsdom with Pixi's canvas mocked (no WebGL), and `draw` updates the list
   - with hand-built models: a token gets the token marker and a Chaos unit the neutral color; a feared unit gets the fear icon; a prize with `alive: false` is drawn destroyed; a squad with `retired: true` draws nothing
   - art, with `fetch` stubbed (`vi.stubGlobal`; the manifest isn't an API route, so not `stubApi`): a listed key gets its `url`; an unlisted key, a failed fetch and a malformed manifest give the placeholder; with no base URL `fetch` is never called
6. **e2e** (`replay.spec.ts`, no login, no art URL, so placeholders): open `/replay`, load `starter-2-rounds.json`, step to the end of round 1: the canvas is visible, the units list isn't empty, and the console has no errors.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test -- battlefield replay` and `pnpm test:e2e -- replay` pass
- [ ] With the web on 4082, `/replay` with `emblem.json` shows the Emblem on the Chaos Grid and its HP going down
- [ ] With the web on 4082, `/replay` focused on seat 0 shows its grid at 16 px per cell with placeholder sprites; zooming out to the whole arena shows units as markers

## Out of scope

- Timed playback and speed (T-083); the planning panel's placement preview (T-086); overlays and the round log (T-088).
- Sound, particles beyond the effects above, a minimap, following a unit with the camera.
- Real art, animated sprites, the bucket and the upload: D39 leaves the art pipeline for later.

## Notes

- Default: one Pixi `Application` per battlefield; React holds the element and calls `draw` on each new model. Don't rebuild sprites every draw: keep a sprite per id and update it.
- Default: seat colors are `PALETTE.seat` (T-068), and the neutral color for Chaos is `PALETTE.chaos`.
- Default: the manifest is `${baseUrl}/manifest.json`, a JSON object from art key to file name, and a file's URL is `${baseUrl}/${file}`.
- Why a camera: the arena is 130 cells wide, so 16 px sprites need 2080 px; scaled to fit, a cell is about 6 px and a sprite unreadable. The match opens where the player looks most, their own grid.
- Default: zoom steps 32, 16, 8, 4 and the fit size. Ask lead before adding sizes that aren't whole multiples or halvings of 16.
- `gridToWorld` is a copy of the snippet in PROTOCOL.md, not an import from core.
