---
id: T-045
title: Battle timeline
milestone: M3
depends_on: [T-044]
branch: agent/T-045-battle-timeline
model: sonnet
effort: high
scope:
  - packages/protocol/src/**
  - packages/protocol/test/**
  - packages/protocol/README.md
  - docs/PROTOCOL.md
  - packages/core/src/**
  - packages/core/test/**
  - packages/core/README.md
  - tools/sim-cli/test/golden/**
  - tools/sim-cli/test/golden.test.ts
context:
  - docs/PLAN.md#M3
  - docs/DECISIONS.md#Decision log
  - docs/PROTOCOL.md#Events
  - docs/PROTOCOL.md#Game and round
  - packages/core/README.md#Events
---

# T-045 — Battle timeline

## Goal

D19: core plays out a whole Simulate as soon as plans lock, and a client plays the result back in real time. Today core already runs Simulate to the end in one call, but it sends a `tick` event for every tick, so a round at 100 ticks per second would carry 10,000 of them. Make `tick` events sparse, close every Simulate with a `simulate.ended` event, and give clients a protocol helper that turns a round's events into timeline steps.

## Interfaces

What exists (copied from the code):

```ts
// packages/core/src/combat/simulate.ts:64-69. Every tick opens with a `tick` event today.
function startTick(ctx: EffectsCtx, tick: Ticks): void {
  ctx.state.tick = tick;
  ctx.emit({ type: 'tick', tick });
  expireEffects(ctx);
}
// packages/core/src/combat/state.ts:15
export type EndReason = 'timeUp' | 'lastStanding' | 'chaosWon';
// packages/protocol/src/event.ts:80-88: TickEvent { type: 'tick'; tick }, documented as
// "emitted every 0.1 s"; PhaseChangedEvent { phase }; RoundEndedEvent { round, scores }.
// packages/core/src/round/play.ts: PlayRoundResult { state, events: GameEvent[], winners, … }
```

What this task adds:

```ts
// protocol event.ts
export interface SimulateEndedEvent { type: 'simulate.ended'; tick: number; reason: 'timeUp' | 'lastStanding' | 'chaosWon' }
// TickEvent: sent before the first other event of a tick, and only then. Ticks where nothing
// happens send nothing.
// protocol src/timeline.ts, exported from the package
export interface TimelineStep { tick: number; events: Event[] } // events in order, without the `tick` event
export function groupByTick(events: readonly Event[]): TimelineStep[];
// From the Simulate phase change to simulate.ended. Throws on a malformed timeline: ticks out of
// order, a tick event with nothing after it, or no simulate.ended.
export const PROTOCOL_VERSION = /* T-043's + 1 (T-044 doesn't bump it) */;
```

## Deliverables

1. Core sends a `tick` event lazily: the first event of a tick is preceded by `{ type: 'tick', tick }`, and a tick with no events sends none. Tick 0 follows the same rule. Every Simulate ends with exactly one `simulate.ended`, after the last event of its last tick and before the round's Cleanup events.
2. Protocol: `SimulateEndedEvent` in the `Event` union, `TickEvent`'s doc comment, `src/timeline.ts` with `groupByTick`, the exports, and a `PROTOCOL_VERSION` bump. Tests for `groupByTick`: a normal round, an empty tick, ticks out of order, a missing end.
3. A core test: over a played round, `groupByTick` accepts the events, every step's events are non-empty, and the last step's tick is `simulate.ended`'s tick.
4. Goldens: regenerate them. They get much shorter; say so in the PR with the line counts before and after.
5. docs/PROTOCOL.md › Events and › Game and round describe the timeline: how a client plays it back (wait `(tick - previous tick) × 1000 / TICKS_PER_SECOND` ms between steps, divided by the playback speed), the new event, and a line for its version in › Versioning. packages/core/README.md › Events says the same in two lines.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/protocol test -- timeline` passes
- [ ] The golden round files are smaller than before (`wc -l tools/sim-cli/test/golden/*.json` in the PR)

## Out of scope

- The tick rate: T-046 moves to 100 ticks per second, after this
- Playback itself: the `GameHost` and the UI come in M4. Don't add a playback clock to core or protocol.

## Notes

- `TICKS_PER_SECOND` isn't in the protocol yet, and the playback formula needs it: add `TICKS_PER_SECOND = 10` to protocol's primitives, export it, and have core's time.ts import it, so T-046 changes it in one place.
- Default: `groupByTick` takes a whole round's events and returns the steps from the first `tick` event to `simulate.ended`, which is the last step's last event. What comes before (Begin, Plan) and after (Cleanup, `round.ended`) isn't in the timeline.
