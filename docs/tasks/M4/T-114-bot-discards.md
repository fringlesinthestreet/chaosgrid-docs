---
id: T-114
title: Bots choose their discards
milestone: M4
depends_on: [T-112]
branch: agent/T-114-bot-discards
model: sonnet
effort: medium
scope:
  - packages/bots/**
  - tools/sim-cli/src/**
  - tools/sim-cli/test/**
  - tools/sim-cli/README.md
context:
  - docs/RULES.md#Round structure
  - packages/bots/README.md
---

# T-114 — Bots choose their discards

## Goal

Since T-112 a seat over the hand limit chooses its discards in Cleanup's Discard step (D42). Bots don't choose yet, so the automatic rule (most recently drawn first) trims them. After this PR every bot chooses with the strategy it used to trim its hand during Plan, and sim-cli passes the choices to core, so soaks and balance reports play the rule as players do. The web host asks the bots in T-116.

## Interfaces

What exists (copied from the code on 2026-10-29, and from T-112's card):

```ts
// packages/bots/src/bot.ts:8-19
export interface Bot { readonly name: string; plan(snapshot: Snapshot): Plan }
export type Random = () => number;
// registry.ts: FACTORIES (:8-12) random, greedy, turtle; createBot(name, random) (:24); botSeed (:29).
// Before T-112 each planner ended with draft.discardDown(pick) (draft.ts:225-228): a `discard` action
//   of the cards kept beyond handLimit, picked by random-bot.ts:80 (at random), greedy-bot.ts:127
//   (`cheapest`) and turtle-bot.ts:125 (`this.discards`, :284). T-112 deleted them. Read them back with
//   `git log --oneline -1 --grep '^T-112'` and `git show <that sha>^:packages/bots/src/<file>`.
// test/referee.ts:84 referee(snapshot, plan): string[]; T-112 dropped its hand-limit check.
// test/fixtures/snapshots.ts:739 has a fixture with settings.handLimit 2.

// T-112, in packages/core (public): checkDiscards(state, seat, cards): DiscardCheckedEvent;
//   SeatDiscards = Readonly<Partial<Record<Seat, readonly CardInstanceId[]>>>;
//   beginRound(input, discards?: SeatDiscards); snapshotFor(state, seat).
// packages/protocol: PlayerSnapshot.discardCount (cards the seat must discard now; 0 otherwise),
//   Snapshot.seat, Snapshot.hand: HandCard[], DiscardChooseCommand, DiscardRefusal.

// tools/sim-cli/src/game.ts:116-127
while (result.winners.length === 0 && result.rounds < maxRounds) {
  // begun = beginRound(state) (:118); plans[seat] = players[seat].plan(snapshot) (:123);
  // played = playRound(begun.state, plans) (:127) …
}
// GameOptions.check?: boolean (:42), the --check flag.
```

What this task adds:

```ts
// packages/bots/src/bot.ts
export interface Bot {
  readonly name: string;
  plan(snapshot: Snapshot): Plan;
  /** Cleanup's Discard step (D42): exactly the seat's discardCount cards, from snapshot.hand. */
  chooseDiscards(snapshot: Snapshot): CardInstanceId[];
}
// packages/bots/test/referee.ts
/** What's wrong with a bot's Discard-step choice: not exactly discardCount cards, one twice, one not in the hand. */
export function refereeDiscards(snapshot: Snapshot, cards: readonly CardInstanceId[]): string[];
```

## Deliverables

1. **The choices.** `chooseDiscards` on RandomBot, GreedyBot and TurtleBot, each with the pick its planner used for `discardDown` before T-112: random at random from the seeded `Random`, greedy with `cheapest`, turtle with its `discards` order. A seat with a `discardCount` of 0 gets an empty list.
2. **sim-cli passes them.** After a `playRound` that leaves seats with a `discardCount`, each such seat's bot chooses from `snapshotFor(state, seat)`, and the next `beginRound` gets the choices. With `--check`, each choice goes through `checkDiscards`, and a refusal fails the game the way `--check` fails a bad plan. Test players in tools/sim-cli/test (scripted.ts) implement `chooseDiscards` too.
3. **The referee.** `refereeDiscards`, and the bots' tests run it on every choice they make.
4. **Tests.**
   - Each bot, on a snapshot with `discardCount` 2: a legal choice, picked the way item 1 says.
   - The same seed gives the same choice.
   - A sim-cli game where a hand goes over the limit: its `cards.discarded` holds the bot's choice, not the automatic one.
5. **READMEs.** bots: the Discard step, per bot. sim-cli: what `--check` checks now.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm test:soak` passes
- [ ] `pnpm --filter @chaosgrid/bots test` passes
- [ ] `pnpm sim --games 5 --target 30 --check` exits 0

## Out of scope

- The web host's Discard step and the human's prompt (T-116).
- Smarter discards, such as keeping what the next round can afford: M5 tunes bots if the reports ask for it.

## Notes

- `snapshot.players` is per seat (`perSeat`), so the bot's own count is `snapshot.players[snapshot.seat].discardCount`.
- Default: a choice comes in the order the pick returns, and `cards.discarded` keeps that order (T-112).
- A soak number measured before T-112 (D33's greedy check, the no-winner ratio) can move now that bots choose again. If one fails, report the numbers; don't loosen it.
