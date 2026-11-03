---
id: T-150
title: Bots plan in a Web Worker
milestone: M5
depends_on: []
branch: agent/T-150-bots-plan-in-a-web-worker
model: opus
effort: high
scope:
  - apps/web/src/host/**
  - apps/web/src/match/session.ts
  - apps/web/src/match/session.test.ts
  - apps/web/e2e/bot-worker.spec.ts
  - apps/web/vite.config.ts
  - apps/web/README.md
  - packages/bots/README.md
  - docs/ARCHITECTURE.md
  - docs/APPS.md
context:
  - docs/ARCHITECTURE.md#Runtime shape
  - docs/APPS.md#The match
  - apps/web/README.md#How a match flows
  - packages/bots/README.md#The budget
---

# T-150 — Bots plan in a Web Worker

## Goal

Planning runs on the page's thread, inside `Host.begin()`. Three Hard bots freeze the page for about 1 s on average and up to 1.8 s at the start of a round (3 × 323 ms and 3 × 596 ms, `packages/bots/README.md` › The budget), and the page can't paint the new round's snapshot until they finish.

After this task the bots run in one Web Worker (D56). `GameHost` keeps the only game state and the round loop on the page. Plan opens at once, and the player can plan while the bots think. The round plays when every human seat is ready and every bot's plan is in. The same seed plays the same game.

## Interfaces

What exists (copied from the code on 2026-11-03):

```ts
// apps/web/src/host/host.ts
export function lookAheadFor(cards: readonly Card[]): LookAhead // :104, also imported by host.test.ts:22

// Host's constructor, :173-181: one RNG per bot seat
const rng = seedRng(botSeed(setup.seed, seat));
this.bots.set(seat, createBot(player.bot, () => nextFloat(rng), {
  lookAhead,
  style: styleForDeck(player.deckId ?? null),
}));

// Host.begin, :237-244
for (const [seat, bot] of this.bots) {
  const snapshot = begun.snapshots[seat];
  if (!snapshot) throw new Error(`beginRound gave no snapshot for seat ${seat}`);
  this.plans.set(seat, bot.plan(snapshot));
}
this.stage = 'plan';
this.playWhenReady();

// Host.beginDiscardStep, :281-285
const bot = this.bots.get(seat);
if (bot) {
  this.discards.set(seat, bot.chooseDiscards(snapshot));
  continue;
}

// apps/web/src/host/transport.ts:25
export function createGameHost(setup: MatchSetup, cards: readonly Card[]): GameHost

// apps/web/src/match/session.ts:261-265, startSoloMatch
const host = createGameHost(setup, cards);
const transport = createMockTransport(host, seat);
const session = createSession(transport, cards, { ...options, seat });
host.start();
return session;
```

What this task adds:

```ts
// apps/web/src/host/bot-seats.ts
export interface BotSeat {
  seat: Seat;
  bot: BotName;
  deckId: string | null;
}

/** The match's bots, wherever they run. Requests for one seat are answered in the order they were made. */
export interface BotSeats {
  plan(seat: Seat, snapshot: Snapshot): Promise<Plan>;
  chooseDiscards(seat: Seat, snapshot: Snapshot): Promise<readonly CardInstanceId[]>;
  /** Ends the bots. A request still open never settles. */
  close(): void;
}

/** Runs the bots on the calling thread: the worker's own side, and Vitest. */
export function createLocalBotSeats(seats: readonly BotSeat[], seed: string, cards: readonly Card[]): BotSeats;
/** Runs the bots in bot-worker.ts. */
export function createWorkerBotSeats(seats: readonly BotSeat[], seed: string, cards: readonly Card[]): BotSeats;

// apps/web/src/host/bot-worker.ts: the worker's entry, loaded with
new Worker(new URL('./bot-worker.ts', import.meta.url), { type: 'module' })

// apps/web/src/host/host.ts
export interface GameHost {
  start(): void;
  onError(listener: (error: Error) => void): () => void;
  /** Ends the host and its bots. Nothing more is delivered. */
  close(): void; // new
}

// apps/web/src/host/transport.ts
export function createGameHost(setup: MatchSetup, cards: readonly Card[], seats?: BotSeats): GameHost
```

## Deliverables

1. **`bot-seats.ts`.** `lookAheadFor` moves here from `host.ts`, with its comment corrected. `createLocalBotSeats` builds the bots exactly as the constructor does today, with `botSeed(seed, seat)`. `createWorkerBotSeats` sends the seats, seed and cards once, then one numbered request per call, and settles each promise from its numbered reply. A request that fails rejects with the worker's message, and the worker's `error` event rejects every open request.
2. **`bot-worker.ts`.** A thin `self.onmessage` over `createLocalBotSeats`. A bot's throw becomes a reply with the error's message, so the worker stays up long enough to report it.
3. **`Host`.**
   - It takes a `BotSeats` and no longer holds `Bot`s. `createGameHost` uses `createWorkerBotSeats` when `typeof Worker !== 'undefined'`, and `createLocalBotSeats` otherwise, unless it's handed `seats`.
   - `begin()` delivers its batch and snapshots, sets the stage to `plan`, and requests each bot's plan in seat order. A reply reaches the host as a new `Job` kind, so it joins the queue and is never re-entrant.
   - `playWhenReady()` also waits for every bot's plan. A `player.ready` that arrives first is kept. A bots-only match plays when the last plan arrives.
   - `beginDiscardStep()` requests the bots' discards the same way, in seat order, and the next round waits for those replies too.
   - A rejected request calls `stop()` with the error, as a bot's throw does today.
   - `close()` ends the seats, drops the queue and ignores any later reply. `ended` and `stopped` also close the seats.
4. **The session.** `MatchSession.close()` from `startSoloMatch` closes the host, so leaving a match ends its worker.
5. **Tests, in `host.test.ts` and a new `bot-seats.test.ts`,** with a `BotSeats` the test settles by hand where timing matters:
   - The begin batch and the snapshot are delivered before any plan settles.
   - A `player.ready` before the last plan doesn't play the round; the last plan does. `plan.submit` still gets its `plan.checked` while the bots think.
   - The next round waits for a bot's `chooseDiscards` reply.
   - A rejected `plan` or `chooseDiscards` stops the host and reaches `onError`.
   - After `close()`, a late reply changes nothing.
   - The same bots-only setup plays the same events with immediate seats and with seats that answer after a timer (D8).
   - With a fake `Worker` (`vi.stubGlobal`) that runs `bot-worker`'s handler: replies reach the right request, the `error` event rejects what's open, and `close()` terminates the worker.
6. **`apps/web/e2e/bot-worker.spec.ts`.** Start a match against three Hard bots, check that `page.workers()` holds one worker whose URL contains `bot-worker`, play one round (Ready, then the round's banner), leave the match, and check that the worker is gone.
7. **The docs.** `ARCHITECTURE.md` › Runtime shape and `APPS.md` › The match say the bots run in a worker and the state stays with the host (D56). `apps/web/README.md`'s `host/` row and flow match the code. `packages/bots/README.md` › The budget says the times now hold up the bots' plans rather than the page. Fix the comments in `host.ts` and `host/index.ts` that this makes wrong.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test src/host src/match/session` passes.
- [ ] `pnpm --filter @chaosgrid/web test:e2e bot-worker` passes.
- [ ] `pnpm --filter @chaosgrid/web build` passes, and `ls apps/web/dist/assets | grep -c bot-worker` prints at least 1.
- [ ] `grep -n "bot.plan\|chooseDiscards(snapshot)" apps/web/src/host/host.ts` prints nothing.

## Out of scope

- The preview budget and how well the planner plays. `DEFAULT_PREVIEW_BUDGET` stays 3 × 1,500.
- A queue or a pool of workers (D56).
- `playRound`, which stays on the page's thread.
- sim-cli, which keeps calling its bots directly.
- The protocol, and any "bots are thinking" text. If the wait shows when you play it, say so in the PR.

## Notes

- **Why one worker is enough.** Each bot has its own RNG and reads only its seat's snapshot, so the order of the seats doesn't change a plan. What must hold is each bot's own order: its `plan`, then its `chooseDiscards`, then its next `plan`. The worker takes its messages one at a time, so posting them in that order is enough.
- **Why `chooseDiscards` moves too.** It draws from the same RNG as `plan`, so a bot can't plan in the worker and discard on the page without changing the game.
- **The waiting sets.** `discarding` can also hold the bot seats still due, since `handleDiscard` only ever sees human seats. Update its comment. A second set does the same for plans.
- **Late replies.** A round can't move on with a plan outstanding, so replies need no round number.
- **The fallback** is for Vitest's jsdom, which has no `Worker`. Every browser we support has one, so don't add a setting for it.
- **Card data** crosses by structured clone once, at the start of the match.
- **Types.** `self.postMessage(reply)` type-checks under the DOM lib, so don't add the `webworker` lib.
- **`vite.config.ts`** is in scope only if the build needs it. The `new Worker(new URL(...))` form usually needs no config.
- **Imports.** `bot-seats.ts` and `bot-worker.ts` stay in `src/host/`, the one folder that may import core (DECISIONS.md › Import boundaries).
