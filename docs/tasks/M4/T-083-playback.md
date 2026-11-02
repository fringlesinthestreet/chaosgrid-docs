---
id: T-083
title: Timeline playback and its controls
milestone: M4
depends_on: [T-082]
branch: agent/T-083-playback
model: sonnet
effort: high
scope:
  - apps/web/src/match/playback/**
  - apps/web/src/replay/**
  - apps/web/e2e/replay.spec.ts
context:
  - docs/tasks/M4/README.md#The match
  - docs/PROTOCOL.md#Timeline
  - docs/PROTOCOL.md#Game and round
---

# T-083 — Timeline playback and its controls

## Goal

Core plays a whole Simulate as soon as the plans lock, so the UI gets a round's events in one batch and has to play them back in real time (PROTOCOL.md › Timeline). After this task `match/playback/` turns batches of events into a model that advances tick by tick at 1×, 2× or 4×, with Pause and Skip. Batches that arrive during playback wait their turn. The replay viewer uses it, and the match screen (T-085) will too.

## Interfaces

What exists (T-081, T-082, and the protocol):

```ts
// @chaosgrid/protocol
export const TICKS_PER_SECOND; // 100 after T-046
export function groupByTick(events: readonly Event[]): TimelineStep[]; // { tick, events }, from the first `tick` to `simulate.ended`
// simulate.ending (T-101): the tick the end condition held. The round settles after it, up to simulate.ended (D38).
// apps/web/src/match/model (T-081): MatchModel (with `tick` and `simulateEnding`), EMPTY_MODEL, applyEvents
// apps/web/src/match/battlefield (T-082): <Battlefield model step viewer cards stepMs />
// apps/web/src/replay (T-082): ReplayPage with Previous / Next / round picker, parseLog
```

What this task adds (`apps/web/src/match/playback/`, exported from `index.ts`):

```ts
export interface Clock { now(): number; frame(callback: () => void): () => void } // frame returns cancel
export const browserClock: Clock; // performance.now and requestAnimationFrame
export type Speed = 1 | 2 | 4;
export interface PlaybackState {
  model: MatchModel;
  step: readonly Event[];  // the events applied in the last frame, for the battlefield's effects
  stepMs: number;          // how long moves should tween at this speed
  playing: boolean;        // a timeline is playing (or paused mid-way)
  paused: boolean;
  speed: Speed;
  queued: number;          // batches waiting behind the current one
}
export interface Playback {
  /** A batch from the transport, or a round of a replay. Plays after the batches before it. */
  push(events: readonly Event[]): void;
  setSpeed(speed: Speed): void;
  pause(): void;
  resume(): void;
  /** Applies the rest of the current batch at once, then goes on with the queue. */
  skip(): void;
  /** Resolves when every pushed batch has been applied (at once, if nothing is playing). */
  idle(): Promise<void>;
  subscribe(listener: (state: PlaybackState) => void): () => void;
  getState(): PlaybackState;
  destroy(): void;
}
export function createPlayback(options?: { clock?: Clock; model?: MatchModel; speed?: Speed }): Playback;
export function usePlayback(playback: Playback): PlaybackState; // useSyncExternalStore
export function PlaybackControls(props: { playback: Playback }): JSX.Element; // ⏸/▶, 1× 2× 4×, Skip, "Round 3 · tick 412"
```

## Deliverables

1. **Splitting a batch.** The events before the first `tick` apply at once. The timeline (`groupByTick`) plays step by step, the settle after `simulate.ending` included. The events after `simulate.ended` (Cleanup, `round.ended`, `game.ended`) apply when the timeline ends. A batch with no `tick` (newGame's, a round's Begin, a `plan.checked`) applies at once.
2. **Timing.** Step `n` is due `(tick − first tick) × 1000 / TICKS_PER_SECOND / speed` ms after the timeline starts (PROTOCOL.md › Timeline). Each frame applies every due step with one `applyEvents` call, and `step` holds their events. `stepMs` is the time to the next step at this speed, capped at 250 ms. Changing the speed mid-way keeps the current tick and rescales what's left.
3. **The queue.** A batch pushed while one plays waits; `queued` counts them. Skip finishes the current batch only. `idle()` resolves when the queue is empty.
4. **Controls.** `PlaybackControls`: Pause/Play, the three speeds (the current one pressed), Skip (disabled when nothing is playing), and the round and tick. The tick shown is the round's clock: it stops at `model.simulateEnding` while the settle plays (D38, T-101). Only the display stops; the settle's events keep their own later ticks. Keyboard: Space toggles pause, `1`, `2`, `4` set the speed, `S` skips; not while focus is in a text field.
5. **Replay viewer.** `/replay` pushes the log one round at a time (newGame's events, then each round's events up to and including `round.ended`, plus `game.ended`) and adds `PlaybackControls` above T-082's step buttons. The step buttons pause playback and step as before. The round picker rebuilds the model up to the start of that round and plays from there. Keep `replay.spec.ts` passing, and add: load a log, press 4×, then Skip until round 2: the round label says round 2.
6. **Tests** (a fake `Clock` that the test advances):
   - a batch with ticks 0, 50 and 100 at 1×: the steps apply at 0, 500 and 1000 ms; at 2× at 0, 250 and 500
   - speed change at tick 50 of 0..100: the rest takes half as long
   - a batch of 0..100 with `simulate.ending` at tick 60: the steps play to 100, and the controls' tick stays at 60 from then on
   - pause stops it; resume continues from the same tick
   - skip: the model equals `applyEvents` of the whole batch, and the next queued batch starts
   - two batches pushed back to back play in order; `queued` counts down; `idle()` resolves after both
   - for each fixture log, playback pushed round by round and skipped to the end gives the same model as `applyEvents(EMPTY_MODEL, log)`
   - `destroy()` cancels the pending frame

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test -- playback replay` and `pnpm test:e2e -- replay` pass
- [ ] With the web on 4083: `/replay` with `starter-2-rounds.json` plays round 1 at 1× in about the Simulate's length in seconds (its last tick ÷ `TICKS_PER_SECOND`)

## Out of scope

- The match screen's wiring (T-085): holding the next round's snapshot until `idle()`.
- Seeking backwards within a timeline, a scrubber bar.

## Notes

- Default: playback starts unpaused at 1×. The replay viewer remembers the last speed in `localStorage` (wrapped in try/catch).
- Default: `step` is empty on a frame with no due step, so effects don't repeat.
- Never hard-code 100: read `TICKS_PER_SECOND`.
