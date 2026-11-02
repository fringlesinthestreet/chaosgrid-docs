---
id: T-128
title: Playback timeline
milestone: M5
depends_on: [T-113, T-124]
branch: agent/T-128-playback-timeline
model: sonnet
effort: high
scope:
  - apps/web/src/match/playback/**
  - apps/web/src/match/overlays/**
  - apps/web/src/i18n/en/playback.json
  - apps/web/src/i18n/en/overlays.json
context:
  - docs/PROTOCOL.md#Timeline
  - docs/APPS.md#The match
  - apps/web/README.md#Rules a change must keep
  - apps/web/README.md#Text
---

# T-128 — Playback timeline

## Goal

From the human's playtest (2026-10-29), the round's playback gets a timeline to move through:

- **A scrub bar** over the round's ticks, with markers where units die, prizes and Emblems are hit, and Chaos acts. A click, a drag or a key seeks.
- **Next event.** A button and a key jump to the next marker.
- **A remembered speed.** The speed the viewer last picked, kept in localStorage.
- **Jump links.** Each line of the round summary and of the round log jumps playback to its moment. Once the round has played, that plays it again from there (a rewatch), and then the live game comes back.

## Interfaces

What exists (copied from the code on 2026-10-29). T-113 changes PlaybackControls and the round banner first, so re-read them:

```ts
// apps/web/src/match/playback/playback.ts
export type Speed = 1 | 2 | 4;                                                         // :21
export interface PlaybackState { model; step; stepMs; playing; paused; speed; queued }  // :23-35
export interface Playback { push; setSpeed; pause; resume; skip; idle; subscribe; getState; destroy } // :37-50
const MAX_STEP_MS = 250; const EPSILON = 1e-6; const NO_EVENTS: readonly Event[] = []; // :53, :55, :57
interface Current { ticks: number[]; steps: Event[][]; post: Event[]; next: number; elapsed: number } // :60-71
//   steps: each step's events, its `tick` event first; post: what follows simulate.ended;
//   elapsed: ticks since the first step, at the playback's speed.
function split(batch: readonly Event[]): { pre: Event[]; current: Current | null }; // :74-98, via groupByTick
export function createPlayback(options: { clock?: Clock; model?: MatchModel; speed?: Speed } = {}): Playback; // :100
// publish(model, step) (:133-147) builds the state, calls the listeners, and resolves idle() when
//   nothing plays or waits. sync() (:150) adds the time since the last look to `elapsed`.
// run(seed) (:176-211) starts queued batches (:179-187), applies the due steps (:189-196), ends a
//   timeline by applying `post` (:197-199), and publishes only when something changed (:202-209).
// skip() (:241-247) applies the rest of the timeline and `post` as one step.

// apps/web/src/match/playback/PlaybackControls.tsx
export function usePlayback(playback: Playback): PlaybackState;   // :8
export function shownTick(model: MatchModel): number;               // :13, frozen at simulate.ending (D38)
function isTyping(target: EventTarget | null): boolean;             // :18-26: any <input>, textarea, select, contenteditable
export function PlaybackControls({ playback }: { playback: Playback }); // :28
// A window keydown (:31-48): Space pauses or resumes, 1 2 4 set the speed, S skips; not with
//   Ctrl, Meta or Alt, nor while typing. role="group" aria-label="Playback" (:51-55); Play/Pause,
//   1× 2× 4× with aria-pressed, Skip (disabled unless playing), the label (:71-73).
// T-113 adds secondsLeft(model: MatchModel): number | null, and the label "Round N · S s left".
// playback/index.tsx re-exports browserClock, createPlayback, Clock, Playback, PlaybackState, Speed,
//   PlaybackControls, shownTick and usePlayback (T-113 adds secondsLeft).

// apps/web/src/match/overlays/panels.tsx
// RoundBanner (:38-102): after T-113 it shows while state.revealing, and closing it calls
//   session.endReveal(). It lists model.chaos.
// RoundSummaryCard (:104-166): hidden while state.playback.playing (:113). One line per seat
//   (:140-146) and per broken Emblem (:149-154), "Leaders died" (:155-157), the three counts
//   (:158-160), and how Simulate ended (:161).
// LogDrawer (:178-235): one <li> per entry (:221-226), its time `(entry.tick / 100).toFixed(1)s` (:223).
// GameOver (:237-278).
// apps/web/src/match/overlays/log.ts
export interface RoundSummary { round; gained; gainedBy; scores; emblems; leadersDied; retired; revived; banished; ended } // :219-232
export function lastEndedRound(model: MatchModel): number | null;                     // :235
export function roundSummary(model: MatchModel, round: number): RoundSummary | null;  // :244-316, a fold over the round's log

// The web model (match/model): LogEntry { round; tick: number | null; event }, where tick is the
//   Simulate tick, null outside Simulate (types.ts:117-123). PermanentModel.kind: 'trap' |
//   'permanent' | 'emblem' | 'prize' (:84, :95). UnitModel.owner: Owner (:55). applyEvents(model,
//   events) copies the model once and folds a round's events in a few ms (apply.ts:476).
// Events (packages/protocol/src/event.ts): unit.died { unit, killer: Owner | null } (:403-411);
//   unit.spawned { unit, squad, owner, … } (:263-272); permanent.damaged { permanent, source, amount,
//   hp } (:635-645); permanent.destroyed { permanent, owner, killer, faceDown } (:665-675);
//   emblem.broken { permanent, cardId, breaker } (:761-767); simulate.ending { tick, reason } (:101-107).
//   Owner is a Seat or 'chaos'. TICKS_PER_SECOND (primitives.ts:21).

// Where the controls show: MatchScreen.tsx:156 while state.playback.playing; replay/ReplayPage.tsx:283
//   always. The replay keeps its own speed under 'chaosgrid.replay.speed' (:42-61), and its stepping
//   mode is a paused playback with nothing pushed (:78-82).
// match/session.ts:73-80: `planning` needs snapshot.round === model.round and model.phase 'plan',
//   with the playback's model.
// Tests: playback.test.tsx has FakeClock (:11-33), ms(ticks, speed) (:35), timeline(ticks, endingAt?)
//   (:38-50: each step scores a point for seat 0) and points(playback) (:54). overlays.test.tsx renders
//   <Overlays /> in stubSession with `playback: { ...stub.playback.getState(), model }` (:41-56). The
//   stub's playback is a real createPlayback, so vi.spyOn(stub.playback, 'seek') works.
// T-124: t(id, values) and the language files; the web README's Text section is in this card's context.
```

What this task adds:

```ts
// playback.ts
export type MarkerKind = 'kill' | 'prize' | 'emblem' | 'chaos';
export interface TimelineMarker { tick: number; kind: MarkerKind }
/** What the bar shows of a timeline. */
export interface TimelineView {
  /** The model's round when the timeline started. */
  round: number;
  /** Its first and last ticks: the bar's ends. */
  first: number;
  last: number;
  /** Its simulate.ending tick, or null. */
  ending: number | null;
  /** Where playback is: first + the elapsed ticks, and `last` once the timeline has ended. */
  at: number;
  /** In tick order. */
  markers: readonly TimelineMarker[];
}
export interface PlaybackState {
  // … as now, plus:
  /** The timeline playing, else the last one played, which a seek plays again. Null before the first. */
  timeline: TimelineView | null;
  /** While the last timeline plays again: the live model, which comes back when the rewatch ends. */
  rewatch: { live: MatchModel } | null;
}
export interface Playback {
  // … as now, plus:
  /**
   * Moves playback to `tick`, clamped to the timeline's ends, keeping the speed and the pause. With
   * nothing playing, plays the last timeline again from there. Does nothing before the first timeline.
   */
  seek(tick: number): void;
}

// markers.ts (pure)
/** The bar's markers: from the model the timeline started from, and its steps. */
export function timelineMarkers(start: MatchModel, steps: readonly (readonly Event[])[]): TimelineMarker[];
/** The first marker after `timeline.at`, or null. */
export function nextMarker(timeline: TimelineView): TimelineMarker | null;

// speed.ts
export const SPEED_KEY = 'chaosgrid.playback.speed';
/** The stored speed: null when there's none, it isn't 1, 2 or 4, or storage throws. */
export function readSpeed(): Speed | null;
/** Stores the speed. Does nothing when storage throws. */
export function writeSpeed(speed: Speed): void;

// TimelineBar.tsx: the bar, its markers and Next event. PlaybackControls renders it under its buttons.
export function TimelineBar({ playback }: { playback: Playback }): JSX.Element | null; // null without a timeline

// overlays/log.ts: RoundSummary gains
/** The Simulate tick of each line's first event, or null when it happened outside Simulate. */
at: {
  seats: Record<Seat, number | null>; // the seat's first points.scored
  emblems: (number | null)[];         // one per `emblems` entry
  leadersDied: number | null;
  retired: number | null;
  revived: number | null;
  banished: number | null;
};

// playback/index.tsx also exports the TimelineView, TimelineMarker and MarkerKind types.
```

## Deliverables

1. **Seeking.**
   - **In the timeline playing.** The model becomes `applyEvents` of the model the timeline started from and its steps up to `tick`, and `next` and `elapsed` follow, so playback goes on from there. `step` holds the events of a step at exactly `tick`, else it's empty: a seek plays no effects but those of the moment it lands on. Paused stays paused. A seek to the last tick ends the timeline as playing up to it would: `post` applies, and the next batch starts.
   - **The rewatch.** With nothing playing, a seek plays the last timeline again from `tick`. `playing` is true, and `rewatch.live` holds the model from before. That same object comes back, with an empty step, when the rewatch reaches its end, on Skip, and when a batch is pushed, which then plays as now. `post` isn't applied again, and `idle()` doesn't wait for a rewatch.
   - **What's kept.** Each timeline keeps the model it started from, computed when `run` starts it, and its markers. Only the last finished timeline is kept.
   - **The bar's position.** `run` also publishes when `at` enters a new whole second, so the bar moves through a stretch with no events.
2. **Markers** (`timelineMarkers`), in tick order, at most one per kind and tick:
   - `kill`: a `unit.died` that isn't a Chaos one.
   - `chaos`: a `unit.died` of a Chaos unit or with `killer: 'chaos'`, and a `unit.spawned` of a Chaos unit. A unit's owner comes from the start model, or from its `unit.spawned` in an earlier step.
   - `prize` and `emblem`: a `permanent.damaged` of a prize or an Emblem (by its kind in the start model), unless that permanent was hit in the 2 s before (`2 × TICKS_PER_SECOND` ticks). A prize's `permanent.destroyed` and an `emblem.broken` always make one.
3. **The bar** (`TimelineBar`), under the controls' buttons, as wide as its container:
   - **The track.** An `<input type="range">` labelled "Timeline", from `first` to `last` in steps of one tick, at `at`, with an `aria-valuetext` like "12.3 s of 41.0 s". Each input event while clicking or dragging seeks. Its keys: ← and → move 1 s, PageUp and PageDown 10 s, Home and End go to the ends.
   - **Dragging.** While the pointer is down on the bar, a playing timeline is paused, and it resumes on release.
   - **The markers** sit on the track at their ticks. Each kind has its own colour and shape, and a legend names the four. They let clicks through to the input.
   - **Next event** seeks to `nextMarker`, and is disabled when there's none.
   - **A rewatch** shows a note: "Watching round N again".
4. **Keys**, in PlaybackControls' handler: N for Next event, and `,` and `.` for 1 s back and forward. A range input doesn't count as typing, so all the controls' keys work while the bar has focus.
5. **The remembered speed.** PlaybackControls applies `readSpeed()`, when there's one, as it mounts. It calls `writeSpeed` when the viewer picks a speed with a button or a key.
6. **Jump links.**
   - **The log.** A line with a tick, in the round of `state.playback.timeline`, is a button that seeks to that tick. Other lines stay text. Its time is `tick ÷ TICKS_PER_SECOND`, not `÷ 100`.
   - **The summary.** When its round is the timeline's, a line with a moment in `RoundSummary.at` is a button that seeks there, and the line saying how Simulate ended seeks to `timeline.ending`.
   - **During a rewatch** the summary stays up, and the summary, the log and the round banner read `rewatch.live`, so they don't rewind with the battlefield.
7. **Text** (D50). The new text goes through `t()`, in `en/playback.json` and `en/overlays.json`.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test playback overlays` passes, with tests for:
  - [ ] seeking forward and back while playing (the model equals `applyEvents` of the start model and the steps up to the tick, and `points()` counts them), while paused, onto a step and between steps (`step`), past both ends, and to the end (`post` applied, the next batch started)
  - [ ] a rewatch: `playing` and `rewatch.live`; the live model back (`toBe`) at the end, on Skip and on a push, which then plays; `idle()` resolved during it
  - [ ] each marker rule, with hand-made steps
  - [ ] the bar: the markers' places, `aria-valuetext`, a change event and each of its keys seeking, Next event and its disabled state, N, `,` and `.`, no key while typing in a text field, and the pause while the pointer is down
  - [ ] the speed: applied on mount, stored by a button and by a key, and a `localStorage` that throws ignored
  - [ ] a log line and each kind of summary line seeking (`vi.spyOn(stub.playback, 'seek')`), a line of an older round and a Cleanup line staying text, and `RoundSummary.at` in log.test.ts
- [ ] `pnpm --filter @chaosgrid/web test replay` passes unchanged
- [ ] `grep -c -E "seek" apps/web/src/match/playback/playback.ts` prints at least 1
- [ ] `grep -rn -E "tick / 100" apps/web/src/match/overlays` prints nothing
- [ ] `pnpm test:e2e` passes unchanged

## Out of scope

- **The replay's own controls**: Previous and Next, the Round and Step pickers, and `ReplayPage.tsx`, which T-120 and T-121 change later. The replay already moves through a log by step and by round, swapping in a new playback each time. It renders PlaybackControls, so it gets the bar, the keys and the remembered speed for the round it plays, with no change of its own.
- **Planning during a rewatch.** It needs `planning` taken from the live model (`session.ts`) and a Ready bar that keeps its clock (`MatchScreen.tsx`, which has an owner in every wave from 15 to 24).
- Rewatching a round before the last one.
- Where the controls sit on the screen (T-136), and the look-ahead for wind-ups (T-121).
- Moving the existing playback and overlay text into `t()`.

## Notes

- **No `session.ts`.** Seeking and the rewatch live in the playback. A rewatch shows an older round's model, so `planning` is false and the planning tools step aside until it ends. The Ready bar and the Discard clock mount again afterwards, with their clocks started again. A solo game sets both to "No limit" (D41), and M6's host deadlines will be the binding ones.
- Default: a seek lands on the tick itself, with no lead-in. Drag back a little to see what led up to it.
- Default: one remembered speed for the match and the replay, under `chaosgrid.playback.speed`. The replay keeps writing its own key, so the two agree after the viewer's first pick.
- Default: a death involving Chaos is a `chaos` marker, not a `kill`, so the fight between players reads apart from the Chaos.
- The marker colours come from the palette's custom properties: `--cg-error` (kill), `--cg-warning` (prize), `--cg-text` (Emblem), `--cg-chaos`. Styles go in `playback/playback.css`, imported by the bar, as `app/app.css` is. `theme.css` belongs to T-115 in this wave.
- Keys taken elsewhere: the arrows, + and − are the camera's while the battlefield has focus, and R and Esc the planning panel's. The bar's own keys call `preventDefault`, so nothing else acts on them.
- A jump link's accessible name is its line. Playwright matches names by substring: the e2e never opens the log, and no summary line can contain "Ready" or "Skip".
- **For T-121** (wave 24), keep these stable: `Current`'s five fields and their meaning (add fields, rename none), `publish(model, step)` as the one place that builds the state (a seek and the end of a rewatch publish through it), `run(seed)` and its publish condition, `NO_EVENTS`, `EPSILON`, `MAX_STEP_MS`, the `PlaybackState` fields, and `playback/index.tsx`'s exports. T-121 builds `upcoming` from `current.next` and `elapsed`, which a seek keeps consistent.
- `PlaybackState` is built only in `publish`, and playback.test.tsx checks it field by field: add `timeline` and `rewatch` there.
