---
id: T-108
title: The round summary in live play
milestone: M4
depends_on: [T-088, T-089]
branch: agent/T-108-round-summary
model: sonnet
effort: medium
scope:
  - apps/web/src/match/overlays/**
  - apps/web/src/theme/theme.css
  - apps/web/e2e/m4.spec.ts
context:
  - docs/APPS.md#The match
---

# T-108 — The round summary in live play

## Goal

The round summary (T-088) never shows in a live game (T-089's handoff). Playback applies what follows a round's `simulate.ended` in one go, `round.ended` of round N and then `round.started` of round N + 1, so by the first render `model.round` is already N + 1, and `RoundSummaryCard` asks `roundSummary` for a round that hasn't ended. Its unit test passed because the model it folds stops at `round.ended`. This task shows the summary of the latest round that ended, keeps it off the planning controls now that it shows during Plan, moves the fade's keyframes into the theme, and puts T-089's summary check back into the e2e.

## Interfaces

What exists (copied from the code on 2026-10-29):

```tsx
// apps/web/src/match/overlays/panels.tsx:103–109 (T-088)
export function RoundSummaryCard() {
  const { state } = useSession();
  const names = useNames();
  const { model } = state.playback;
  const [closed, setClosed] = useState<number | null>(null);
  const summary = useMemo(() => roundSummary(model, model.round), [model]);
  if (summary === null || closed === summary.round) return null;
// :129–133 its Panel: role="region", aria-label="Round summary",
//   style={{ ...interactive, position: 'absolute', bottom: 8, left: 8, maxWidth: 320 }}
// :29–34 layerStyle, the layer all the overlays are in: position fixed, inset 0, pointer-events none,
//   zIndex 20. :59–65 the Chaos button at top 8, right 8; :66–80 the banner at top '12%', centered;
//   :191–197 Log at top 8, right 84; :198–203 the log drawer at top 48, right 8, bottom 8.

// apps/web/src/match/overlays/log.ts:234–235
/** The round's log folded into one card; null until its `round.ended`. */
export function roundSummary(model: MatchModel, round: number): RoundSummary | null;

// apps/web/src/match/model/apply.ts:54–55: log() files each entry under model.round, so round N's
//   round.ended is in round N's entries; :85–92 round.started sets model.round.

// apps/web/src/match/playback/playback.ts:23–35 (T-083)
export interface PlaybackState {
  model: MatchModel;
  /** A timeline is playing (or paused mid-way). */
  playing: boolean;
  // …step, stepMs, paused, speed, queued
}
// :176–211 run(): a batch's events after simulate.ended (round.ended N, round.started N + 1, …) are
//   applied in the same publish that sets playing to false. The next round's batch sets it to true.

// apps/web/src/match/overlays/index.tsx:9–15: the layer holds RoundBanner, RoundSummaryCard,
//   LogDrawer and GameOver, in that order, so the Game over modal is on top. Line 10:
<style>{'@keyframes cg-fade-in { from { opacity: 0 } to { opacity: 1 } }'}</style>
// panels.tsx:78, the banner: animation: 'cg-fade-in 300ms'. apps/web/src/theme/theme.css is the base
//   CSS, which theme/index.ts imports.

// apps/web/src/match/overlays/overlays.test.tsx:24–56: modelAt(match, from); atRound2 (round 2's Plan,
//   the live case); atRound1End (stops at round 1's round.ended); full (the whole log: two rounds, both
//   ended); renderOverlays(model) puts the model in stubSession's playback state and returns the stub.

// apps/web/src/match/MatchScreen.tsx:130–159: below the app's header (app/Layout.tsx) and the match's
//   top bar, in the page's flow: the battlefield box (min(70vh, 640px) high), the playback controls
//   while playing, the Ready bar (role="group", aria-label="Ready": the timer, then the button "Ready",
//   on the left) and <section aria-label="Planning panel">.

// apps/web/e2e/m4.spec.ts:127–133, step 6 of 'a new player plays a game': Ready, 4×, skipToPlan, then
//   the "Round 2" banner. :135–141 step 7 clicks Ready each round. :156–171 the bug comment and
//   test.fixme('the round summary of round 1 shows after the round').
```

What this task adds, in `log.ts`:

```ts
/** The round of the latest `round.ended` in the log; null before the first. */
export function lastEndedRound(model: MatchModel): number | null;
```

## Deliverables

1. **The summary of the latest round that ended.** `RoundSummaryCard` shows `roundSummary(model, lastEndedRound(model))`, and nothing while that's null. After round N's timeline it shows round N's summary through round N + 1's Plan, until Close or until round N + 1's timeline starts playing (`state.playback.playing`), as T-088's deliverable 2 says. Close hides that round's summary only: when round N + 1 ends, its own summary shows.
2. **Off the planning controls.** Now that the card shows during Plan, it must not cover the Ready bar or the planning panel (T-088's default). Today it sits at the bottom left of the viewport, which at the e2e's 1280×720 is likely over the Ready bar: step 7's Ready clicks would then fail. Default: the top left, below the Chaos and Log buttons (`top: 48, left: 8`), over the battlefield.
3. **The fade in the theme.** Move `@keyframes cg-fade-in` from the inline `<style>` in `overlays/index.tsx` into `theme.css`. The banner's `animation` stays as it is.
4. **Tests.**
   - `log.test.ts`, on `starter-2-rounds.json`: `lastEndedRound` is null before round 1's `round.ended`, 1 from then through round 2's Plan, and 2 after round 2's `round.ended`.
   - `overlays.test.tsx`: on `atRound2`, the summary shows "Round 1 summary"; with `playing: true` it doesn't show; after Close it's gone, and `full` (set with `stub.setState`) shows "Round 2 summary". Keep the `atRound1End` test.
5. **The e2e.** In step 6 of "a new player plays a game", after the "Round 2" banner: the "Round summary" region shows "Round 1 summary", and its `boundingBox()` overlaps neither the Ready bar's (`getByRole('group', { name: 'Ready' })`) nor the planning panel's (`getByRole('region', { name: 'Planning panel' })`). Delete the `test.fixme` test and the bug comment above it.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test -- overlays` passes
- [ ] `grep -c -E "fixme" apps/web/e2e/m4.spec.ts` prints 0, and `grep -c -E "@keyframes" apps/web/src/match/overlays/index.tsx` prints 0
- [ ] `grep -c -E "@keyframes cg-fade-in" apps/web/src/theme/theme.css` prints 1
- [ ] `pnpm test:e2e` passes: smoke, auth, replay and m4
- [ ] `pnpm test:e2e -- m4` passes three runs in a row (no flakes)

## Out of scope

- What the summary says (`roundSummary`'s fields). `unit.died` is in the log only for a Leader's unit (`apply.ts:195`, T-081), so "Leaders died" counts only Leaders already.
- MatchScreen's "Round over" status: it shows during the settle, inside the timeline, and works.
- The replay viewer, which doesn't render the overlays.

## Notes

- Default: at game over the last round's summary stays under the Game over modal, and shows after View board.
- Default: the summary doesn't pause playback or the Plan timer (T-088's default stands).
- `top: 48` is the log drawer's top. The card may cover the left end of the match's top bar: the summary repeats its scores, and Close is there.
- The layer is `position: fixed`, so a player who scrolls down to the planning panel can find the card over it; Close is the answer there too. The e2e checks the page as step 6 leaves it, unscrolled.
