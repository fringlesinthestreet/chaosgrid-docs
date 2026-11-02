---
id: T-120
title: Animated units and permanents on the battlefield
milestone: M5
depends_on: [T-119, T-136]
branch: agent/T-120-unit-animations
model: sonnet
effort: high
scope:
  - apps/web/src/match/battlefield/**
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/replay/ReplayPage.tsx
context:
  - docs/ART.md#Sizes
  - docs/ART.md#Animations
  - docs/ART.md#Events
  - docs/ART.md#Per card kind
  - docs/ART.md#Fallbacks
  - docs/APPS.md#The match
  - apps/web/README.md#Rules a change must keep
---

# T-120 — Animated units and permanents on the battlefield

## Goal

The battlefield draws units, squads, permanents, traps, the prize and Emblems with T-119's `SpriteView`, and plays their own animations on the events ART.md › Events lists (D45). Where a key has no sprite, or a higher animation is playing, the event shows today's code effect, so with no art manifest the battlefield looks as it does today.

## Interfaces

What exists (copied from the code on 2026-10-29). T-111, T-115, T-117, T-118 and T-136 (the battlefield fills the match screen, D51) change these files first, so re-read them:

```ts
// apps/web/src/match/battlefield/scene.ts
const CELL = 16;        // :24, view px per cell
const EFFECT_MS = 300;  // :26
export interface SceneOptions { viewer; cards: ReadonlyMap<string, Card>; onBanner?; clock? } // :38-45
class IconView {}       // :106: ArtView(`ui.${name}`, 6), :113
class UnitView {}       // :130: the art is ArtView(unit.cardId, CELL) (:155); the owner frame, HP bar,
                        //   leader mark, token ArtView('ui.token', 6) at (CELL − 6, 0) (:140), status icons
                        //   at (0, −7); fadeStart and wasAlive drive the death fade; sync(unit, squad, card, now) :166
class SquadView {}      // :222: a squad with no spawned unit yet, its art on the footprint's top-left cell (:233-238)
class PermanentView {}  // :269: the art is re-created when its key or size changes (:297); visible while
                        //   alive, or always for a prize (:292); the muted tint when dead, the owner's for the
                        //   prize (:305); the crack when dead
function artKeyOf() {}  // :340-351: prize → 'ui.prize', emblem → 'ui.emblem', a trap → 'ui.cardBack' when
                        //   face down or with no card id, else the card id; a permanent → its card id
class Scene {}          // :367: stepMs (:391), setStepDuration (:413), draw (:437), update (:454, every Pixi
                        //   tick through mount.ts:80 and :101), permanentRect (:539: attached → an 8 × 8 card
                        //   at the squad's top-right, :552-558), syncSquads (:603), syncPermanents (:627),
                        //   syncUnits (:651; the move tween lasts stepMs, :671), playEffects (:717)
// playEffects' handlers (:744-799): unit.attacked → a 1 px line; unit.damaged → the number; unit.died →
//   puff; ability.triggered → flash(source); trap.fired → flash; unit.respawned and permanent.respawned →
//   glow; permanent.destroyed and the placing events have none. `centers` holds what's drawn, in view px.
// mount.ts: Battlefield (:9-17), BattlefieldOptions (:19-24).
// Battlefield.tsx: BattlefieldProps (:7-17); setStepDuration (:43-45) and draw (:47-49) run in effects,
//   without a rebuild.
// match/MatchScreen.tsx:118 `const { model, step, stepMs, playing } = state.playback;`, <Battlefield> :131-138.
// replay/ReplayPage.tsx:241 `const { model, speed } = state;`, <Battlefield> :341.
// match/playback/playback.ts:21 `export type Speed = 1 | 2 | 4;` and PlaybackState.speed (:23-35).
// packages/cards: `stats.speed`, in cells per second (0 for static), for units, Leaders and Chaos units.
//   The web model has no current Speed.
// From T-119, through '../../art': SpriteView, hasSprite, ICON_PX (8), AnimationName.
```

What this task adds:

```ts
// scene.ts
export interface SceneOptions { /* … */ speed?: number }   // the playback speed, 1 by default
class Scene { setSpeed(speed: number): void }              // every sprite and the walk timeout follow it
// mount.ts
export interface BattlefieldOptions { /* … */ speed?: number }
export interface Battlefield { /* … */ setSpeed(speed: number): void }
// Battlefield.tsx
export interface BattlefieldProps { /* … */ speed?: number } // applied in an effect, like stepMs, without a rebuild
// MatchScreen.tsx passes state.playback.speed; ReplayPage.tsx passes its speed.
```

## Deliverables

1. **Sprites in the views.** Each view's art becomes a `SpriteView`, bottom-anchored, and `Scene.update` updates every one:
   - a unit's on its cell, and a squad not yet spawned on its footprint's top-left cell, as today
   - a free-standing permanent's, a trap's and the prize's on their rect, a face-down trap too (as `ui.cardBack`, so a reveal doesn't jump)
   - an Emblem's: `artKeyOf` gives its chaos card id when `hasSprite(cardId)`, else `ui.emblem`

   An attached permanent keeps its `ArtView`: it has no sprite, only its icon. The owner frame, HP bars, the level, tints, the crack and the alpha stay code.
2. **Events.** Each handler plays the thing's own animation first. When `play()` returns false, it shows today's effect:

   | Event | Plays | Else, as today |
   | --- | --- | --- |
   | `unit.spawned` | `enter` | nothing |
   | `unit.moved` | `walk` (deliverable 3) | the tween alone |
   | `unit.attacked` | `attack` started at `now − hitMs()`, so its hit frame shows now | the 1 px line |
   | `unit.damaged` | `hurt`; the number always shows | the number |
   | `unit.died` | `die`; the fade starts when it ends (`durationMs('die')`) | the puff and the fade now |
   | `unit.respawned`, `permanent.respawned` | `enter` | the glow |
   | `permanent.placed`, `prize.placed`, `emblem.placed`, `trap.set`, `trap.revealed` | `enter` | nothing |
   | `permanent.damaged` | `hurt`, with no number | nothing |
   | `permanent.destroyed` | `die`; it hides when that ends. The prize holds the last frame and greys and cracks then | it hides now; the prize greys now |
   | `trap.fired` | the trap's `ability` | the flash |
   | `ability.triggered` | the source's `ability`: a unit's, each living unit's of a squad, or a permanent's | the flash; nothing for a source off the battlefield |

   Every other event keeps today's effect. T-122 puts the `fx.*` sprites between the two columns.
3. **Walk.** `unit.moved` calls `setLoop('walk')`. An attack stops it, and so do 1.5 cell-times without a move: a cell-time is 1000 ÷ the card's printed `stats.speed` ms, divided by the playback speed. A unit with Speed 0 never walks. The move's tween still lasts stepMs.
4. **Facing and order.** ART.md › Animations' facing, in view coordinates (`centers`): a move or an attack toward the left of the screen mirrors the unit, a vertical move keeps its facing, and a new unit faces the view's centre. Permanents never mirror. In the 'ground' and 'air' layers, units sort by screen y, lower on top.
5. **Icons.** Status icons and the token marker grow from 6 px to `ICON_PX`. The status icons stay above the cell, and the token stays inside its top-right corner. Attached permanents stack leftward from the squad's top-right corner, one icon apart, in the model's order.
6. **The speed prop.** `speed` on the three option types, `setSpeed` on `Scene` and `Battlefield`, and the two screens passing it.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test battlefield` passes, with tests for:
  - [ ] each row of deliverable 2, with the sprite and without it
  - [ ] the walk timeout at speed 1 and 4, and a Speed 0 unit
  - [ ] facing for two viewers, and the y-order
  - [ ] `die` then the fade, and the prize holding its last frame
  - [ ] `setSpeed` reaching the sprites without a rebuild
- [ ] `grep -c -E "SpriteView" apps/web/src/match/battlefield/scene.ts` prints at least 1
- [ ] The existing scene tests pass, changed only where they check the 6 px icons, and `pnpm test:e2e` passes: with no manifest nothing looks different

## Out of scope

- Starting an attack's wind-up before its step, and projectile sprites: T-121.
- `fx.*` sprites, spell casts, and the two same-step rules that need `fx` sprites: T-122.
- The art module (T-119), PlanGrid and the DOM pages.

## Notes

- Default: tests replace `SpriteView` with a fake through `vi.mock('../../art', importOriginal)`. The fake says which animations a key has and records `play`, `setLoop`, `setFacing` and `setSpeed`. The tests keep scene.test.ts's Pixi mock and its fixture.
- Default: the printed Speed, since the model has no current one.
- The same-step rules that need no `fx` come from the priority order: `die` replaces `hurt`, and `attack` refuses `hurt`.
- Without `upcoming` (T-121), an attack has no wind-up: it starts at its hit frame, as ART.md › Attack timing allows.
- The viewer's model holds only what the viewer may see, so `trap.set`'s `enter` shows only to the trap's owner.
- T-117's framing fits a grid to the screen (T-136: to the free area), which gives cells that aren't a whole multiple of 16 px. That's accepted: D46 fixes the art's scale in world units (`CELL`), and ART.md › The grid and the camera takes the browser's scaling at the fit step and the Plan framing as overviews. Don't snap the camera to whole multiples.
