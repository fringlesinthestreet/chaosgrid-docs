---
id: T-121
title: Attack wind-ups and projectile sprites
milestone: M5
depends_on: [T-120]
branch: agent/T-121-attack-windup
model: sonnet
effort: high
scope:
  - apps/web/src/match/playback/**
  - apps/web/src/match/battlefield/**
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/replay/ReplayPage.tsx
context:
  - docs/ART.md#Playback
  - docs/ART.md#Attack timing
  - docs/ART.md#Animations
  - docs/ART.md#Sizes
  - apps/web/README.md#Rules a change must keep
---

# T-121 — Attack wind-ups and projectile sprites

## Goal

Attacks stay instant in core (D47): `unit.attacked` is the moment the blow lands or the projectile leaves. To show the swing, the bow's draw or the spell's preparation before it, playback publishes `upcoming`, the steps due in the next `LOOKAHEAD_TICKS`. The battlefield starts each attack's strip early from it, so the hit frame lands on the attack's step. Projectiles become sprites too: `fly` while they travel, turned to their heading, and `impact` where they land. With no art manifest the battlefield looks as it does today.

## Interfaces

What exists (copied from the code on 2026-10-29). T-113 and T-128 change playback first, and T-111, T-117, T-118, T-136 and T-120 the battlefield, so re-read both and keep their additions:

```ts
// apps/web/src/match/playback/playback.ts
export type Speed = 1 | 2 | 4;                          // :21
export interface PlaybackState { model; step; stepMs; playing; paused; speed; queued } // :23-35
const EPSILON = 1e-6;                                   // :55
const NO_EVENTS: readonly Event[] = [];                 // :57
interface Current { ticks; steps; post; next; elapsed } // :60: steps hold "Each step's events, its
                                                        //   `tick` event first" (:63); elapsed is "Ticks
                                                        //   elapsed since the first step, at the
                                                        //   playback's speed" (:69)
// createPlayback (:100): the first state (:113); stepMs() (:124); publish(model, step) builds the state
//   and calls the listeners (:133); sync() adds the time since the last look to `elapsed` (:150).
// run(seed) (:176) starts queued batches, plays each step with ticks[next] − ticks[0] ≤ elapsed, and
//   publishes only when something changed (:201):
//     // A frame with nothing due leaves `step` empty, so effects don't repeat.
//     if (out.length > 0 || state.step.length > 0 || state.playing !== (current !== null) ||
//       state.queued !== queue.length) { publish(…, out); }
// setSpeed (:219), pause (:226) and resume (:234) publish state.model and state.step again. skip (:241)
//   plays the rest of the timeline as one step (current.steps.slice(next).flat() and post), and run
//   then starts the next queued batch, if any.
// playback/index.tsx re-exports browserClock, createPlayback, the Clock, Playback, PlaybackState and
//   Speed types, PlaybackControls, shownTick and usePlayback.
// PlaybackState is used elsewhere only as a type (match/session.ts:16, :20; PlaybackControls.tsx:4,
//   :8), and playback.test.tsx checks it field by field.

// apps/web/src/match/battlefield/scene.ts
class ProjectileView {}  // :353: a Graphics labelled `projectile:<id>`, a 4 × 4 white rect
class Scene {}           // draw (:437-451): syncArena, syncSquads, syncPermanents, syncUnits,
                         //   syncProjectiles, playEffects(model, step, now), update(now). A landed
                         //   projectile's view is pruned before its events play.
                         // update (:454); syncProjectiles (:682): creates the views, tints them
                         //   ownerColor(owner), and moves each over stepMs from lastAt (or from) to
                         //   at, cell centres in view px; prune (:707); playEffects (:717) has nothing
                         //   for projectile.launched or projectile.landed; addEffect (:825)
// mount.ts: Battlefield.draw (:11) and setStepDuration (:13); scene.update() on every Pixi tick (:80, :101).
// Battlefield.tsx: the scene is rebuilt on [viewer, cards, chaosBanner]; setStepDuration runs in an
//   effect on [stepMs, viewer, cards, chaosBanner], draw in one on [model, step, viewer, cards,
//   chaosBanner]. React runs a component's effects in the order they're declared.
// match/MatchScreen.tsx:118 `const { model, step, stepMs, playing } = state.playback;`
// replay/ReplayPage.tsx:240 `const state = usePlayback(session.playback);`, `stepping` (:242),
//   <Battlefield … stepMs={stepping ? undefined : state.stepMs}> (:344)

// The web model: ProjectileModel { projectile, kind, owner, at, from, target } (model/types.ts:74-82),
//   deleted on projectile.landed (apply.ts:325).
// packages/protocol/src/event.ts: tick { tick } (:89-92); unit.attacked { unit, target } (:298-302);
//   projectile.launched { projectile, kind, source, owner, from, speed, target, aim } (:497-515);
//   projectile.landed { projectile, at, hit } (:536-546), with no kind.
// From T-119, through '../../art': SpriteView, a Container (constructor(key, box: { width, height },
//   { anchor }), has, play(animation, startMs) for a start now or earlier, cancel, setLoop('fly'),
//   setHeading(radians), hitMs(), durationMs(animation), update(now)), and hasSprite(key).
// From T-120: Scene.setSpeed and the speed prop. On unit.attacked a unit plays
//   play('attack', now − hitMs()), so its hit frame shows on the step, else the 1 px line.
```

What this task adds:

```ts
// playback.ts
/** How far ahead `upcoming` looks: 0.5 s of match time, more than any wind-up (ART.md › Attack timing). */
export const LOOKAHEAD_TICKS = 50;
/** A step that's due soon. */
export interface UpcomingStep {
  /** Ms until it plays at the current speed, counted from the publish. */
  inMs: number;
  /** Its events, its `tick` event first, as `step` will have them. */
  events: readonly Event[];
}
export interface PlaybackState {
  // …
  /** The steps due within LOOKAHEAD_TICKS, in tick order. Empty while paused or idle. */
  upcoming: readonly UpcomingStep[];
}
// playback/index.tsx also exports the UpcomingStep type.

// scene.ts
class Scene { setUpcoming(upcoming: readonly UpcomingStep[]): void }
// mount.ts
export interface Battlefield { /* … */ setUpcoming(upcoming: readonly UpcomingStep[]): void }
// Battlefield.tsx
export interface BattlefieldProps { /* … */ upcoming?: readonly UpcomingStep[] } // left out: empty
```

## Deliverables

1. **`upcoming` in playback.** `publish` adds the window: every step from `current.next` on with `ticks[i] − ticks[0] − elapsed ≤ LOOKAHEAD_TICKS`, in order. Each has `inMs` = those ticks × 1000 ÷ `TICKS_PER_SECOND` ÷ speed, and `events` = `current.steps[i]`, not a copy.
   - The window is empty while paused and when nothing is playing, and the first state has `upcoming: []`.
   - `run` also publishes when a step has entered the window since the last publish (keep where the window ended). With nothing due, `out` is empty, so the step is empty and no effect repeats. That's still one publish a frame at most.
   - `setSpeed` and `resume` publish new `inMs`, and `pause` an empty window.
2. **Wind-ups.** `Scene.setUpcoming` notes when each `unit.attacked` in the window is due: `now + inMs`, on the scene's clock.
   - `update` starts the attack at `due − hitMs()`, calling `play('attack', start)` once that time comes, but never before the hit of the unit's previous attack, shown or due. A start that has passed plays late and skips frames: near the start of a timeline, and after resuming.
   - An attack is keyed by its unit and its step's tick. A new window recomputes `due` for a wind-up that hasn't begun, and leaves one that has.
   - A unit with no view yet keeps its attack until the view exists. A unit whose sprite has no `attack` gets no wind-up, and its step shows T-120's fallback.
   - `draw` consumes the attacks of the steps it plays. One step can hold several steps' events (a skip, a slow frame), so it reads the tick from each `tick` event. T-120's on-step play then puts the hit frame on the step.
   - Battlefield.tsx declares the `upcoming` effect after the speed and draw effects, so it sees the attacks just consumed and the new `hitMs()`. Its dependencies are `[upcoming, viewer, cards, chaosBanner]`, like setStepDuration's, so a rebuilt scene gets the window too.
3. **Cuts.** An attack that wasn't consumed and has left the window is dropped. If its wind-up has begun, the unit gets `cancel('attack')` and goes back to idle. That happens on a pause, in the replay's step-by-step mode, on a seek and when a rewatch ends (both from T-128's timeline), and when a new playback replaces the old one. After resuming, the attack is back in the window and starts late. A strip past its hit frame isn't cut: it finishes, through a pause too.
4. **Projectile sprites.** When `hasSprite('projectile.<kind>')`, a projectile is a `SpriteView` in an 8 × 8 box with the centre anchor, looping `fly`. It turns to the angle of its move on screen, from `lastAt` (or `from`) to `at` in view px, as Pixi measures rotation: 0 to the right, π/2 down. A projectile that doesn't move keeps its heading, and the node keeps its `projectile:<id>` label.
   - Sprite or rect is chosen when the view is created, so the first projectile of a kind may show the rect while its strip loads.
   - Without a sprite, today's 4 × 4 rect in the owner's colour stays.
   - On `projectile.landed`, hit or miss, `impact` plays upright at the centre of the landed `at`, in a new `SpriteView` with the same box and anchor. Its base frame is fly's 8 × 8, so it draws at ×1 and a 16 × 16 impact grows around the point. It goes in the 'effects' layer: `update` updates it, and removes it when the impact ends (`durationMs('impact')`), before it shows anything else. Keep these sprite effects in a list of their own, since T-122 adds the `fx.*` sprites to it.
   - The kind comes from a map the scene fills from the model and empties on `projectile.landed`, since that event has none and the view is pruned before the events play. A projectile that launched and landed within one draw takes it from that step's `projectile.launched`.
   - With no `impact`, nothing shows, as today.
5. **The screens.** MatchScreen passes `upcoming` from `state.playback` (:118). ReplayPage passes `upcoming={stepping ? undefined : state.upcoming}`, like `stepMs`.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test playback battlefield` passes, with tests for:
  - [ ] the window and its `inMs` at speeds 1, 2 and 4, and the publish when a step enters it with nothing due
  - [ ] an empty window while paused, when idle, at a timeline's end, and after a skip with nothing queued
  - [ ] a wind-up's start at speeds 1 and 4, a late start, and the wait for the previous hit
  - [ ] an attack consumed on its step, a skip's steps included; a cut on a pause and in step-by-step mode; no restart when the window is published again
  - [ ] with no `upcoming`, the hit frame on the step, as T-120 has it
  - [ ] a projectile's heading for two viewers, and its impact on a hit and a miss, with sprites and without
- [ ] `grep -c -E "upcoming" apps/web/src/match/playback/playback.ts` prints at least 1
- [ ] The existing playback and scene tests pass unchanged, and `pnpm test:e2e` passes: with no manifest nothing looks different

## Out of scope

- Core and the protocol: no `unit.attackStarted` (ART.md › Attack timing's Option B).
- A wind-up for anything but `unit.attacked`: abilities and spells play on their step.
- `fx.*` sprites and spell casts (T-122), and the art module (T-119).

## Notes

- Default: a projectile sprite isn't tinted. Only the fallback rect keeps the owner's colour.
- Default: an empty window is one shared constant, like `NO_EVENTS`, so a paused or idle playback doesn't re-run the battlefield's effect.
- `due` is counted from when `setUpcoming` runs, a frame or less after the publish. The on-step play makes up the difference, a frame's skip at most.
- A Ranged unit's hit frame is the release: its `projectile.launched` comes on the attack's step, so the projectile appears as the bow or the staff lets go.
- The fastest attack comes every 67 ticks, so a unit has at most one attack in the window today. Key by unit and tick anyway.
- The first `LOOKAHEAD_TICKS` of a timeline have less look-ahead, so attacks there start late.
- The new publish's step is empty, and drawing an unchanged model with an empty step changes nothing. It adds at most one React render a frame, and only when a step enters the window.
