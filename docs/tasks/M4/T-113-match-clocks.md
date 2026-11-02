---
id: T-113
title: The match clocks and the Chaos pause
milestone: M4
depends_on: [T-110]
branch: agent/T-113-match-clocks
model: sonnet
effort: medium
scope:
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/src/match/index.tsx
  - apps/web/src/match/session.ts
  - apps/web/src/match/session.test.ts
  - apps/web/src/match/overlays/**
  - apps/web/src/match/playback/**
  - apps/web/test/fixtures/session.ts
  - apps/web/e2e/m4.spec.ts
  - apps/web/src/replay/replay.test.tsx
  - apps/web/e2e/replay.spec.ts
  - apps/web/src/match/planning/Zones.test.tsx
  - apps/web/src/match/planning/PlanningActions.test.tsx
  - apps/web/src/match/planning/PlanningPanel.test.tsx
context:
  - docs/tasks/M4/README.md#The match
---

# T-113 — The match clocks and the Chaos pause

## Goal

The match screen takes its clocks from `GameSettings` (D41, T-110), as the human's playtest asked (2026-10-29):

- **Chaos pause.** Plan waits while the round banner shows this round's Chaos for `revealSeconds` (10 s), or until the player closes it. Nobody has to plan while reading.
- **Plan clock.** It runs `planSeconds`. A solo game sets 9999, which reads "No limit".
- **Round clock.** During Simulate it shows the seconds left, not the tick.

## Interfaces

What exists (copied from the code on 2026-10-29):

```tsx
// apps/web/src/match/MatchScreen.tsx
/** How long the player has to plan, from when the Plan panel shows. Then the screen sends ready. */
export const PLAN_SECONDS = 60;                     // :15-16
const HURRY_SECONDS = 10;                           // :19, the timer turns cg-error below it
const PHASE_NAMES: Record<Phase, string> = { reveal: 'Reveal', plan: 'Plan', simulate: 'Simulate', cleanup: 'Cleanup' }; // :21-26
// :39-64 TopBar: round, phase, points, `[data-match-target]` "Target N".
// :66-71 sendReady(sent, session) sends ready at most once.
// :77-112 ReadyBar: role="group" aria-label="Ready"; useState(PLAN_SECONDS); a 250 ms interval
//   counts down to a deadline set on mount, and sends ready at 0; <span role="timer"
//   aria-label="Plan timer">{formatClock(left)}</span>; <Button primary>Ready</Button>.
// :157-158 {state.planning && <ReadyBar key={model.round} … />} {state.planning && <PlanningPanel />}

// apps/web/src/match/session.ts
// :18-32 SessionState { seat, playback, snapshot, checked, checking, ready, planning, error }
// :73-80 planning = no error && !closed && snapshot !== null && snapshot.round === model.round
//   && model.phase === 'plan' && model.winners === null && !readySent
// :116-125 onSnapshot holds a snapshot until playback.idle(), then sets it: the round's snapshot
//   arrives once the previous round's timeline has played.

// apps/web/src/match/overlays/panels.tsx
const BANNER_MS = 4000;                             // :20
// :38-101 RoundBanner: a centred Panel at top 12% listing each Chaos card (kind, Extra, the seats
//   it spawns in front of, a rule card's text). It opens when model.round > 0 and isn't hidden for
//   that round (:44), hides itself after BANNER_MS (:53) or on a click, and the "Chaos" button at
//   top right (:59-65) opens it again.

// apps/web/src/match/playback/PlaybackControls.tsx
export function shownTick(model: MatchModel): number; // :13-15, frozen at simulate.ending (D38)
// :71-73 <span aria-live="off" data-playback-label="">Round {round} · tick {shownTick(model)}</span>
// The replay viewer uses the same controls.

// model.settings: GameSettings | null (match/model/types.ts:127), set on game.started (apply.ts:79-81).
// TICKS_PER_SECOND = 100 (packages/protocol/src/primitives.ts:21).
// apps/web/e2e/m4.spec.ts: planOrGameOver (:30-35) waits up to 60 s for Ready or "Game over";
//   skipToPlan (:38-50); step 6 checks the "Round 2" banner (:127-133).
```

What this task adds:

```ts
// session.ts
// SessionState gains:
/** The Chaos pause: from when a round's snapshot is released until `revealSeconds` pass or endReveal(). Plan waits for it (D41). */
revealing: boolean;
// MatchSession gains:
/** Ends this round's Chaos pause now (the round banner's Close). */
endReveal(): void;
// planning also needs !revealing.

// MatchScreen.tsx: PLAN_SECONDS goes, and match/index.tsx stops re-exporting it; ReadyBar counts settings.planSeconds.
/** A clock with more than this left reads "No limit" (D41): the solo host's 9999 s. */
export const NO_LIMIT_SECONDS = 3600;

// PlaybackControls.tsx
/** Simulate's seconds left on the round clock, from shownTick; null before game.started. */
export function secondsLeft(model: MatchModel): number | null;
// the label: "Round N · S s left"
```

## Deliverables

1. **The Chaos pause.** When the session releases a round's snapshot, `revealing` is true for `snapshot.settings.revealSeconds`, then false. `endReveal()` ends it at once, and a pause of 0 never starts. `planning` waits for it, so the Ready bar, the Plan clock and the planning panel all start when the pause ends.
2. **The banner is the pause.** `RoundBanner` shows while `state.revealing`, and closing it, by its Close or a click, calls `session.endReveal()`. `BANNER_MS` goes. After the pause the "Chaos" button still opens the banner, and closing it then changes nothing else. The top bar's phase reads "Reveal" during the pause.
3. **The Plan clock.** `ReadyBar` counts `settings.planSeconds` from when it mounts, as now. With more than `NO_LIMIT_SECONDS` left, the timer reads "No limit" and the clock is still counting; under 10 s it turns red, as now.
4. **The round clock.** The playback label reads "Round N · S s left", where S is `secondsLeft(model)`: `roundTicks − shownTick`, in whole seconds rounded up, never below 0. It freezes at `simulate.ending` as the tick did, so it reads 0 through the settle after the timer runs out. The replay shows the same.
5. **Tests.**
   - session.test.ts, with fake timers: the pause lasts `revealSeconds`; `endReveal` ends it; `planning` is false during it; a 0 pause never starts.
   - overlays: the banner shows while revealing, and its Close calls `endReveal`.
   - MatchScreen: "No limit" with 9999, a counting clock with 120, and the label's "s left".
   - `stubSession` gains `revealing` (false by default) and records `endReveal`.
6. **The e2e.** It closes the round banner when it shows, so a round doesn't wait the full pause, and passes.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test -- session MatchScreen overlays playback` passes
- [ ] `grep -rn PLAN_SECONDS apps/web/src` and `grep -rn BANNER_MS apps/web/src/match/overlays` print nothing (the battlefield's own `BANNER_MS` stays)
- [ ] `grep -c -E "s left" apps/web/src/match/playback/PlaybackControls.tsx` prints at least 1
- [ ] `pnpm test:e2e` passes

## Out of scope

- The Discard clock (`discardSeconds`): T-116 runs it with the Discard step.
- The host's deadlines (M6) and lobby fields for the clocks.
- Where the Ready bar sits; T-115 lays out the screen.

## Notes

- The replay viewer shows the same playback label, and two tests read "tick" from it: `src/replay/replay.test.tsx` (:95, :100, :116) and `e2e/replay.spec.ts` (:46, its speed check). Update both to the seconds label; they're in scope for that alone.
- The three planning tests that wait for `session.planning` after `startSoloMatch` (Zones, PlanningActions, PlanningPanel) are in scope for one line each, `session.subscribe(() => session.endReveal());`, because the Chaos pause holds planning back.
- The pause starts when the snapshot is released, after the previous round's timeline has played, so it never overlaps playback.
- Default: the pause timer lives in the session, next to the snapshot it starts from. Clear it on close and on error.
- Default: "No limit" keeps the timer's role and label, so a screen reader still finds the Plan timer.
- The settle can run past `roundTicks` (D38). `shownTick` freezes at `simulate.ending`, so the round clock reads the seconds left when the end condition held, and 0 when the timer ran out.
