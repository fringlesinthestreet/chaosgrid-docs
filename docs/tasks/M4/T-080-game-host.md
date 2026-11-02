---
id: T-080
title: GameHost and MockTransport
milestone: M4
depends_on: [T-068, T-078, T-079]
branch: agent/T-080-game-host
model: opus
effort: high
scope:
  - apps/web/src/host/**
context:
  - docs/APPS.md#The match
  - docs/APPS.md#Web layout and ownership
  - docs/ARCHITECTURE.md#Runtime shape (no networking)
  - docs/PROTOCOL.md#Commands
  - docs/PROTOCOL.md#Visibility
  - packages/core/README.md#Public API
---

# T-080 — GameHost and MockTransport

## Goal

A match in the browser needs something that owns the game: it runs core, plans for the bots and answers the human's commands. After this task `src/host/` has the `GameHost`, the only core instance in the web (ARCHITECTURE.md › Runtime shape), and a `MockTransport` with the interface M6's `WsTransport` will have. The match screens (T-085 to T-088) talk only to the transport, so they never see core state.

## Interfaces

What exists (copied from the code on 2026-10-28, plus T-078 and T-079):

```ts
// @chaosgrid/core, the public entry (src/index.ts)
export function newGame(setup: GameSetup, cards: Iterable<Card>): NewGameResult;   // { state, events }
export function beginRound(input: GameState): BeginRoundResult;                    // { state, events, snapshots }, snapshots[seat]
export function playRound(input: GameState, plans: SeatPlans): PlayRoundResult;   // { state, events, winners, reason }
export function checkPlan(state: GameState, seat: Seat, plan: Plan): PlanCheckedEvent; // T-078
export interface GameSetup { seats: readonly SeatSetup[]; seed: number | string; config?: GameConfigInput } // config.pointTarget: 30 by default
export interface SeatSetup { seat: Seat; leader: CardId; main: readonly CardId[]; resources: readonly CardId[] }
export function seedRng(seed: number | string): RngState; export function nextFloat(rng: RngState): number;

// @chaosgrid/bots (T-079)
export type BotName; export const BOT_NAMES: readonly BotName[];
export function createBot(name: BotName, random: Random): Bot; // Bot { name; plan(snapshot): Plan }
export const botSeed: (seed: string, seat: number) => string;

// @chaosgrid/protocol
export type Command; // plan.submit { seat, plan } | player.ready { seat }
export function isVisibleTo(event: Event, seat: Seat): boolean;
export function extendsPlan(previous: Plan, next: Plan): boolean; // T-078: next starts with previous's actions, in order (D37)

// tools/sim-cli/src/game.ts:108-130, the loop this host follows: newGame, then beginRound,
// each bot plans from snapshots[seat], playRound, until winners is not empty.
```

What this task adds (`apps/web/src/host/`, exported from `index.ts`):

```ts
export type SeatPlayer =
  | { kind: 'human'; deck: Deck }
  | { kind: 'bot'; bot: BotName; deck: Deck };
export interface MatchSetup {
  seats: readonly SeatPlayer[]; // seat i is seats[i]; exactly 4 (D22)
  seed: string;
  pointTarget?: number;         // core's default (30) when left out
}

/** What the UI holds (M4/README.md › The match). */
export interface Transport {
  send(command: Command): void;
  onEvents(listener: (events: readonly Event[]) => void): () => void; // returns unsubscribe
  onSnapshot(listener: (snapshot: Snapshot) => void): () => void;
  /** The game stopped: the host threw (in M6, the connection dropped). Returns unsubscribe. */
  onError(listener: (error: Error) => void): () => void;
  close(): void;
}

export interface GameHost {
  /** Plays newGame and the first beginRound and delivers them. Call once, after every seat's listeners are on. */
  start(): void;
  /** A core or bot throw stops the host; the listener gets it, as does every transport's `onError`. Returns unsubscribe. */
  onError(listener: (error: Error) => void): () => void;
}
/** Throws when the setup isn't valid (seat count, a deck core refuses). */
export function createGameHost(setup: MatchSetup, cards: readonly Card[]): GameHost;
/** The transport for one human seat. Throws for a bot seat, or a seat already connected. */
export function createMockTransport(host: GameHost, seat: Seat): Transport;
```

## Deliverables

1. **Setup.** `createGameHost` builds core's `GameSetup` from `MatchSetup` (`config.pointTarget` only when given), with `setup.seed` as the game seed. Each bot seat gets `createBot(bot, () => nextFloat(rng))` with `rng = seedRng(botSeed(seed, seat))`, the same rule as sim-cli, so the same seed, decks and bots play the same game in both.
2. **The loop.**
   - `start()`: `newGame`, then `beginRound`. Each bot plans from its own `snapshots[seat]` right away, and keeps that plan for the round.
   - `plan.submit` during Plan, from a connected seat that isn't ready, when `extendsPlan(previous, plan)` holds for the seat's last kept plan this round (`[]` before the first): keep the plan (it replaces the earlier one), then answer with `checkPlan(state, seat, plan)`. A plan only grows during Plan (D37).
   - `player.ready`: mark the seat ready. When every human seat is ready, `playRound` with the bots' plans and the humans' last kept ones (a human that never submitted plays `[]`). If `winners` is empty, `beginRound` again.
   - Ignored, with no answer: a command for another seat than the transport's, a `plan.submit` or `player.ready` after that seat's `player.ready`, a `plan.submit` that doesn't extend the seat's last kept plan (D37), any command outside Plan, any command after `game.ended`.
   - No timer (the UI has one, M4/README.md › The match) and no round cap: a match ends at `game.ended`.
3. **Delivery.** Every event a seat gets passes `isVisibleTo(event, seat)`. Each seat's listeners get, in order, one `onEvents` call per batch:
   - `newGame`'s events
   - a round's begin events, then `onSnapshot(snapshots[seat])`
   - `[plan.checked]` after each kept `plan.submit`
   - `playRound`'s events, then the next round's begin batch and snapshot

   Delivery is asynchronous (a microtask) and never re-entrant: a `send` from inside a listener is handled after the current batch is delivered. `close()` drops the transport's listeners; the host keeps running for the other seats.
4. **Errors.** A throw from core or a bot stops the host (later commands are ignored) and goes as an `Error` to every `onError` listener, the host's and each open transport's. A transport gets it like a batch: asynchronously, after the batches before it. Nothing is swallowed.
5. **Tests** (`host.test.ts`, with the real cards and starter decks: `loadCards` and `loadStarterDecks` from `@chaosgrid/cards/node`, test-only):
   - a 4-bot match (`createGameHost` with no human, `start()`, then flush microtasks round by round) plays to `game.ended` within 100 rounds, and two hosts with the same setup produce the same events
   - one human and three bots: the human's batches hold only events `isVisibleTo` seat 0, and no other seat's `plan.checked` or hand
   - `plan.submit` gets one `plan.checked` for that plan; a second submit that extends the first replaces it (the round plays the second); one that drops or reorders an action gets no `plan.checked`, and the round plays the kept plan
   - a plan with an unaffordable unit: `plan.checked.rejected` lists it, and `playRound`'s `plan.rejected` for that index follows the round
   - ignored commands: another seat's, after ready, after `game.ended`
   - a listener that calls `send` inside `onEvents` sees its answer in a later batch
   - a core throw (`vi.mock` with a `playRound` that throws) reaches the host's `onError` and the transport's, and later commands are ignored
   - `createMockTransport` throws for a bot seat and for a second connect to one seat
   - the 4-bot host's events equal those of a loop the test builds the way sim-cli's does (game.ts:108-130: `newGame`, `beginRound`, bots seeded with `botSeed`, `playRound`)

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test -- host` passes
- [ ] `src/host/` is the only web folder that imports `@chaosgrid/core` (the ESLint zone from T-068 stays as it is)

## Out of scope

- Any screen (T-084 to T-088). The screens import only types from `host/`: `Transport`, and `MatchSetup` in the lobby (T-084). `startSoloMatch` in `match/session.ts` (T-085) is the only caller of `createGameHost` and `createMockTransport`. Only `src/host/` calls `createBot`; the lobby reads only `BOT_NAMES` and `BotName` from `@chaosgrid/bots`.
- `WsTransport`, reconnects, server deadlines: M6.
- More than one human seat in the UI. The host supports it; the lobby (T-084) makes one.

## Notes

- `MatchSetup` takes `pointTarget`, not core's `GameConfigInput`, so the lobby never names a core type.
- Default: bots plan when the round begins, from their own snapshot, as in sim-cli. They never see the human's plan.
- `apps/web` may not import `tools/sim-cli`, so the replay test rebuilds sim-cli's loop with core and the bots. Keep it short; it guards the shared seed rule, not sim-cli.
