---
id: T-116
title: Choose discards in the match
milestone: M4
depends_on: [T-114, T-115]
branch: agent/T-116-match-discards
model: sonnet
effort: high
scope:
  - apps/web/src/host/**
  - apps/web/src/match/session.ts
  - apps/web/src/match/session.test.ts
  - apps/web/src/match/planning/**
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/test/fixtures/session.ts
  - apps/web/test/fixtures/planning/**
  - apps/web/e2e/m4.spec.ts
context:
  - docs/RULES.md#Round structure
  - docs/tasks/M4/README.md#The match
---

# T-116 — Choose discards in the match

## Goal

The player chooses which cards to discard when Cleanup leaves their hand over the limit (D42). After a round whose Cleanup gives the human a `discardCount`, the screen asks for that many cards in the tray, with the Discard clock running (`discardSeconds`; "No limit" in a solo game). The next round starts once every seat has chosen. Core and the bots are ready (T-112, T-114). Until this card the host skips the step, and the automatic rule picks for everyone.

## Interfaces

What exists (copied from the code on 2026-10-29, and from the T-112 to T-115 cards):

```ts
// apps/web/src/host/host.ts
// :135 start() broadcasts newGame's events, then begin().
// :175-193 begin(): beginRound(state) (:177), clears plans and ready, broadcasts, sends each
//   connected human {kind:'snapshot', snapshot: begun.snapshots[seat]}, asks each bot
//   `bot.plan(snapshot)` in seat order (:190), stage 'plan', then playWhenReady().
// :198-203 playWhenReady(): waits until every human seat is in `ready`, then stage 'playing' and a
//   {kind:'round'} job. :205-218 play(): playRound(state, plans), broadcast, then stage 'ended' when
//   there are winners, else begin().
// :220-243 handle(): drops a command unless the stage is 'plan', the connection is current,
//   command.seat === seat and the seat isn't ready; switches on command.type (T-112 made it ignore
//   discard.choose). deliverEvents (:274) sends one connection its events; Delivery (:45-48).
// core (T-112): checkDiscards(state, seat, cards): DiscardCheckedEvent;
//   beginRound(input, discards?: SeatDiscards); snapshotFor(state, seat). Bots (T-114):
//   Bot.chooseDiscards(snapshot): CardInstanceId[].
// protocol (T-112): DiscardChooseCommand { type: 'discard.choose', seat, cards };
//   DiscardCheckedEvent { type: 'discard.checked', seat, cards, reason: 'notDue' | 'count' | 'unavailable' | null };
//   PlayerSnapshot.discardCount.

// apps/web/src/match/session.ts: SessionState { …, ready, planning, revealing (T-113), error };
//   ready() (:165-168) sends player.ready; onSnapshot holds a snapshot until playback.idle().
// planning/Tray (T-115): the hand, resources and discard pile; its tiles' actions only while planning.
// MatchScreen.tsx: PHASE_NAMES (:21-26) for the top bar; NO_LIMIT_SECONDS (T-113).
// apps/web/e2e/m4.spec.ts: planOrGameOver (:30-35) waits for Ready or "Game over"; the round loop
//   (:150-154) clicks Ready, then skipToPlan, until the game is over.
```

What this task adds:

```ts
// host.ts: a 'discard' stage between play() and begin()
// session.ts, SessionState gains:
/** The seat must choose its discards now: Cleanup's Discard step, its snapshot released, no accepted choice, no ready sent. */
discarding: boolean;
/** The latest discard.checked of this step, or null. */
discardChecked: DiscardCheckedEvent | null;
// MatchSession gains:
/** discard.choose for the session's seat. Does nothing unless discarding. */
chooseDiscards(cards: readonly CardInstanceId[]): void;
// ready() also ends the seat's Discard step, and the automatic rule picks for it.
```

## Deliverables

1. **The host's step.** After a `playRound` with no winners, when some seat's `discardCount` is above 0, the host enters stage `'discard'`.
   - **Bots** choose at once with `chooseDiscards(snapshotFor(state, seat))`.
   - **Humans.** Each human seat with a count gets its snapshot and is waited for. `discard.choose` from that seat goes through `checkDiscards`, and only that seat gets the `discard.checked`. An accepted choice is final, and that seat is done. `player.ready` during the step means done, with the automatic rule.
   - **The next round.** When every seat with a count is done, `begin` passes the choices to `beginRound(state, discards)`. With no human to wait for, that happens at once.
   - **Unchanged.** Commands outside the step and from other seats are dropped as now, and a closed transport still doesn't count as done.
2. **The session.** `discarding`, `discardChecked` and `chooseDiscards`. `ready()` works during the step, and both reset when the next round starts.
3. **The prompt in the tray.** While `discarding`:
   - **Choosing.** The hand's tiles get "Select X to discard" checkboxes. A group labeled "Discard" says "Discard N cards" (N is the seat's `discardCount`), and its "Discard N" button sends the ticked cards. The button is enabled when exactly N are ticked.
   - **The clock.** It counts `settings.discardSeconds`, reads "No limit" above `NO_LIMIT_SECONDS`, and sends ready at 0.
   - **A refusal** names its reason in words: `count` "Choose exactly N cards", `unavailable` "One of those cards isn't in your hand any more", `notDue` "There's nothing to discard now".
4. **The top bar** reads "Discard" while the seat is discarding.
5. **Tests.**
   - host.test.ts, with a fixed seed where the human goes over the limit:
     - the human gets its snapshot, and the next round waits for it;
     - a refused choice gets its reason, and an accepted one starts the round with those cards in `cards.discarded`;
     - ready instead gives the automatic cards;
     - bots' `cards.discarded` match their `chooseDiscards`.
   - session.test.ts: the flags.
   - The tray: the prompt, ticking, the button's state, the clock, a refusal's words.
6. **The e2e.** When the "Discard" group shows in the round loop, the spec ticks the first N hand cards and clicks "Discard N". The game still reaches "Game over".

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test -- host session planning MatchScreen` passes
- [ ] `grep -c -E "discard\.choose" apps/web/src/host/host.ts` prints at least 1
- [ ] `pnpm test:e2e` passes

## Out of scope

- Server deadlines (M6): the client runs the Discard clock, as it runs Plan's (D41).
- Discarding at will, which is gone (D42).

## Notes

- The prompt shows when the step's snapshot is released, after the round's timeline has played (the session holds snapshots until playback is idle). The next round's Chaos pause (T-113) starts after the step.
- D29: the button's state uses only the count the snapshot states, and core judges the choice.
- No game over has a Discard step: core leaves every count at 0 when the game ends (T-112).
- Default: the hand stays in its tray order during the step, oldest first, with the checkboxes on the tiles. Nothing else in the tray acts during the step.
