---
id: T-085
title: Match page, screen and session
milestone: M4
depends_on: [T-080, T-083, T-084]
branch: agent/T-085-match-screen
model: opus
effort: high
scope:
  - apps/web/src/match/index.tsx
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/src/match/session.ts
  - apps/web/src/match/session.test.ts
  - apps/web/test/fixtures/session.ts
context:
  - docs/APPS.md#The match
  - docs/APPS.md#Web layout and ownership
  - docs/APPS.md#Routes
  - docs/PROTOCOL.md#Game and round
---

# T-085 — Match page, screen and session

## Goal

This is where the pieces meet: the lobby's `MatchSetup`, the host and its transport, playback, the battlefield. After this task `/match` starts a game against the bots and plays it to the end, with the round, the phase and the points on screen. The player can't plan yet: the planning panel (T-086, T-087) and the overlays (T-088) plug into the slots this task makes. Until the panel lands, the player's seat plays empty plans: the screen's Ready button and the Plan timer end each Plan.

## Interfaces

What exists (T-075, T-078, T-080 to T-084):

```ts
// apps/web/src/host (T-080)
export function createGameHost(setup: MatchSetup, cards: readonly Card[]): GameHost; // start(), onError()
export function createMockTransport(host: GameHost, seat: Seat): Transport;          // send, onEvents, onSnapshot, onError, close
// @chaosgrid/protocol (T-078): extendsPlan(previous, next): next starts with previous's actions, in order (D37)
// apps/web/src/match/model (T-081): MatchModel (round, phase, points, simulateEnding, …), applyEvents; test/fixtures/logs/
// apps/web/src/match/playback (T-083)
export function createPlayback(options?: { clock?: Clock }): Playback; // push, idle, subscribe, getState, destroy
export function PlaybackControls(props: { playback: Playback }): JSX.Element;
// apps/web/src/match/battlefield (T-082): <Battlefield model step viewer cards stepMs />
// apps/web/src/cards (T-075): useCards(): CardsState, { status: 'ready'; cards; byId } | { status: 'error'; error: ApiError; retry(): void } | …
// apps/web/src/lobby (T-084): navigates here with { state: { setup: MatchSetup } }
// T-068 placeholders: match/planning/index.tsx exports PlanningPanel, match/overlays/index.tsx exports Overlays (no props)
```

What this task adds:

```ts
// apps/web/src/match/session.ts
export interface SessionState {
  seat: Seat;                          // the transport's seat: 0 in M4
  playback: PlaybackState;             // model, step, stepMs, playing, …
  /** The seat's snapshot for the current round, held back until playback has caught up. */
  snapshot: Snapshot | null;
  /** The latest plan.checked of this round, or null. Cleared when a round starts. */
  checked: PlanCheckedEvent | null;
  /** True from a submitPlan until its plan.checked arrives: until then `checked` may answer an older plan. */
  checking: boolean;
  /** True once player.ready went out this round. */
  ready: boolean;
  /** True when the player can plan: Plan phase, this round's snapshot, not ready, no error, game not over. */
  planning: boolean;
  error: Error | null;
}
export interface MatchSession {
  readonly playback: Playback;
  /** Every card `useCards()` loaded, by id, Chaos cards included. The battlefield, the planning panel and the overlays read it and never fetch. */
  readonly cards: ReadonlyMap<string, Card>;
  getState(): SessionState;
  subscribe(listener: () => void): () => void;
  submitPlan(plan: Plan): void;        // plan.submit for the session's seat
  ready(): void;                       // player.ready, once per round
  close(): void;
}
/** Plays one seat's stream from any `Transport` (M6's `WsTransport` too). `seat` is the transport's, 0 when left out. */
export function createSession(transport: Transport, cards: readonly Card[], options?: { seat?: Seat; clock?: Clock }): MatchSession;
/** M4's solo match: the host, its human seat's transport, the session, then `host.start()`. Throws unless exactly one seat is human. */
export function startSoloMatch(setup: MatchSetup, cards: readonly Card[], options?: { clock?: Clock }): MatchSession;
export const SessionContext: React.Context<MatchSession | null>;
export function useSession(): { session: MatchSession; state: SessionState }; // throws outside the provider

// apps/web/src/match/MatchScreen.tsx
export function MatchScreen(props: { session: MatchSession }): JSX.Element;
export const PLAN_SECONDS = 60;
// apps/web/src/match/index.tsx
export function MatchPage(): JSX.Element; // replaces T-068's placeholder

// apps/web/test/fixtures/session.ts, for the panel and overlay tests (T-086 to T-088)
/** A MatchSession with no host: `state` is what the test sets, and the commands are recorded. */
export function stubSession(state: Partial<SessionState>, cards: readonly Card[]): MatchSession & {
  sent: Command[];                                // every submitPlan and ready, as the Command it would send
  setState(patch: Partial<SessionState>): void;   // notifies the subscribers
};
```

## Deliverables

1. **The session** (`session.ts`, no React apart from the context and hook):
   - `createSession` subscribes to the transport and sends every `onEvents` batch to `playback.push`. It starts nothing, so any `Transport` works.
   - `startSoloMatch` is how M4 starts a game: `createGameHost(setup, cards)`, `createMockTransport` for the human seat, `createSession` on that transport with that seat, then `host.start()`.
   - **Holding the snapshot:** an `onSnapshot` waits until `playback.idle()` resolves, so the Plan panel never shows a round whose Simulate is still playing. Only the newest held snapshot is kept.
   - `checked`: the latest `plan.checked` for the seat, cleared on `round.started`. `checking` counts the submits not answered yet. `ready` resets on `round.started`. `submitPlan` and `ready` do nothing when `planning` is false. `submitPlan` also does nothing for a plan that doesn't extend the last one it sent this round (`extendsPlan`, D37): the host would ignore it, and `checking` would never clear.
   - `transport.onError` sets `error` and stops playback updates. A host throw reaches it there (T-080), so the session needs no `host.onError`.
   - `close()` closes the transport and destroys the playback; a solo match's host is dropped with them.
2. **`MatchPage`** (`/match`):
   - No `setup` in `location.state` (a reload, a typed URL): "No match running." with a link to `/play`.
   - It waits for `useCards()` and passes its `cards` to `startSoloMatch`. A cards error shows its message and Retry, which calls the state's `retry()`.
   - It creates the session once per setup, closes it on unmount, and renders `MatchScreen` inside `SessionContext`.
   - A `beforeunload` prompt while the game isn't over.
3. **`MatchScreen`:**
   - **Top bar:** round, phase, each seat's points (the session's seat marked "You"), and the point target from the snapshot (`snapshot.settings.pointTarget`; the setup may leave it out).
   - **Center:** `Battlefield` with `viewer` the session's seat, `cards` from `session.cards`, `model`, `step` and `stepMs` from the playback state.
   - **Round over:** a "Round over" banner over the battlefield from `simulate.ending` until `round.ended`, that is while the model's `simulateEnding` (T-081) is set and its `phase` is still `simulate`. The settle plays under it (D38).
   - **Below it:** `PlaybackControls` while a timeline plays. `<PlanningPanel />` while `planning`. `<Overlays />` always, on top.
   - **Ready bar** while `planning`: the Plan timer, `PLAN_SECONDS` counted from when `planning` turns true in a round (m:ss, red under 10 s), and Ready. Ready, or the timer at 0, calls `session.ready()`; the host plays the last plan the panel submitted (none: an empty plan).
   - On `error`: "The game stopped: <message>", with a link back to `/play`.
4. **Tests:**
   - `session.test.ts` (`startSoloMatch` with the real cards and starter decks from `@chaosgrid/cards/node`, as in T-080's tests, and a fake clock; skip playback with `playback.skip()`):
     - a 1-human, 3-bot setup: after start, `snapshot.round` is 1 and `planning` is true; a 4-bot setup throws
     - `ready()` plays the round; `planning` stays false until the round-2 snapshot is released after `idle()`
     - `submitPlan` sets `checking` until its `checked` arrives, and the next round clears `checked`; a plan that doesn't extend the last one sends nothing (D37)
     - a second `ready()` in a round sends nothing
     - `createSession` on a fake `Transport`: its `onError` sets `error`, then `planning` is false and `submitPlan` and `ready` send nothing
     - **consistency:** at each round's Plan, the model's squads and points match the snapshot's (the model is what the battlefield draws, the snapshot what the panel plans from)
   - `MatchScreen.test.tsx`:
     - `MatchPage` without state shows "No match running."; with a setup and stubbed `fetch` for the cards it starts the match and shows round 1 and Plan; a failing cards `fetch` shows Retry
     - `MatchScreen` on `stubSession`, with models folded from the fixture logs (`applyEvents`): the round, the phase, four seats' points with "You" on the session's seat, and the snapshot's point target; Ready records a `player.ready`; with `vi.useFakeTimers()`, the timer at 0 records one too; an `error` shows "The game stopped: <message>"; "Round over" shows once `simulate.ending` is folded and hides once `round.ended` is
   - in `session.test.ts`, `stubSession` records a `plan.submit` and a `player.ready`, and `setState` notifies its subscribers

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test -- match/session MatchScreen` passes
- [ ] With the API on 5085 and the web on 4085: sign up, `/play`, Start, then Ready and Skip until the game ends: no console errors, and the points go up

## Out of scope

- Planning (T-086, T-087): the grid, the hand, placement, targets.
- The reveal, the scoreboard, the round log and the game-over screen (T-088).
- Resuming a match after a reload: M4 matches live in the page.

## Notes

- Default: the timer uses `setInterval` and `Date.now()`, so tests drive it with `vi.useFakeTimers()`.
- Default: `planning` needs `snapshot.round === model.round` and `model.phase === 'plan'`, so a snapshot that arrives early never opens the panel for a round the battlefield isn't showing.
- `PlanningPanel` and `Overlays` take no props: they read `useSession()`. Keep that, so T-086 to T-088 never edit this screen. They test against `stubSession`, so keep its shape in step with `SessionState`.
- Only `startSoloMatch` in `session.ts` uses `host/`'s runtime (`createGameHost`, `createMockTransport`). The rest of `match/` imports host types only (T-068's lint rule). `createSession` takes any `Transport`, so M6's `WsTransport` plugs in without changing the screens.
- Default: the top bar, the Ready bar and the Round over banner live in `MatchScreen.tsx`. The scope lists files on purpose: in the scope check a `*` also matches `/`, so a `match/*` glob would reach the folders other cards own.
