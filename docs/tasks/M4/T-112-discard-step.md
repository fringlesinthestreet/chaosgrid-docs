---
id: T-112
title: The Discard step replaces discarding at will
milestone: M4
depends_on: [T-110]
branch: agent/T-112-discard-step
model: opus
effort: high
scope:
  - packages/protocol/src/**
  - packages/protocol/test/**
  - packages/protocol/README.md
  - docs/PROTOCOL.md
  - packages/core/src/round/**
  - packages/core/src/zones/**
  - packages/core/src/plan/**
  - packages/core/src/state/**
  - packages/core/src/view/**
  - packages/core/src/effects/rules.ts
  - packages/core/src/effects/*.test.ts
  - packages/core/src/effects/handlers/discard.test.ts
  - packages/core/src/effects/index.ts
  - packages/core/src/index.ts
  - packages/core/test/**
  - packages/core/README.md
  - packages/bots/**
  - packages/cards/README.md
  - tools/sim-cli/test/**
  - apps/web/src/match/planning/**
  - apps/web/src/match/model/**
  - apps/web/src/host/host.ts
  - apps/web/src/host/host.test.ts
  - apps/web/test/fixtures/planning/**
  - apps/web/test/fixtures/logs/**
context:
  - docs/RULES.md#Round structure
  - docs/RULES.md#Zone mechanics
  - docs/PROTOCOL.md#Commands
  - docs/PROTOCOL.md#Versioning
---

# T-112 — The Discard step replaces discarding at will

## Goal

Nobody discards at will any more (D42, the human's playtest on 2026-10-29). The `discard` plan action goes. Instead, when Cleanup leaves a seat holding more than `handLimit` cards and the game goes on, that seat has a `discardCount`. It chooses that many cards with `discard.choose`, and the next `beginRound` discards them. A seat that doesn't choose loses its most recently drawn cards, as Cleanup does today.

This card builds the step in protocol and core, and makes every consumer work without the plan action. The phase stays `cleanup` throughout: a seat's `discardCount` is how a client knows the step is on. The bots' choices are T-114's, and the host's step and the UI's prompt are T-116's. Until then every seat gets the automatic rule at the next `beginRound`, so games play as before.

## Interfaces

What exists (copied from the code on 2026-10-29):

```ts
// packages/core/src/round/begin.ts:74-99
export function beginRound(input: GameState): BeginRoundResult {
  const state = structuredClone(input);
  if (state.roundLoop.winners.length > 0) throw new Error('the game is over');
  if (state.phase === 'cleanup') state.round += 1;
  else if (state.phase !== 'reveal' || state.round !== 1) throw new Error(`round ${state.round} has begun already: play it first (playRound)`);
  state.phase = 'reveal'; state.tick = 0;
  const ctx = makeCtx(state); const effects = effectsCtx(ctx);
  ctx.emit({ type: 'round.started', round: state.round, arena: arenaLayoutFor(state) });
  // returnToStartCells, enterPhase reveal, revealChaos, enterPhase plan, drawPlan per seat …
  return { state, events: ctx.events, snapshots: state.players.map(({ seat }) => snapshotFor(state, seat)) };
}

// packages/core/src/round/cleanup.ts:304-333, cleanup(ctx): Seat[]
  // :307 a rule that lifts the hand limit this round still counts at its Cleanup, after it has ended:
  const noLimit = state.players.map(({ seat }) => ruleActive(state, 'noHandSizeLimit', seat));
  // … steps 1 to 5 …
  state.players.forEach(({ seat }, i) => {                       // :325-330, step 6
    const discarded = discardToHandLimit(state, seat, { noLimit: noLimit[i] ?? false });
    if (discarded.length === 0) return;
    ctx.emit({ type: 'cards.discarded', seat, cards: discarded.map((id) => getCardInstance(state, id).cardId) });
  });
  countRoundsOnGrid(state);
  return checkWinners(ctx);                                       // round.ended, then game.ended

// packages/core/src/zones/hand.ts
export function handOf(state, seat): CardInstanceId[];            // :12, oldest first
export function discard(state, seat, ids): Outcome;               // :25, the plan action: all or nothing, 'unavailable'
export function poolLiftsHandLimit(state, seat): boolean;         // :38, Old Library
export function discardToHandLimit(state, seat, { noLimit }): CardInstanceId[]; // :59, newest first

// packages/core/src/state/state.ts:74-83
export interface Player { seat: Seat; leader: CardInstanceId; points: number }

// The plan action, everywhere it lives:
// protocol: plan.ts:130-135 DiscardAction, :148 (PlanAction union), :163 (PlanActionType); index.ts:55;
//   plan.test.ts:87-89; test/fixtures/samples.ts:146-147
// core: plan/apply.ts:3,12,45-52,64 (the `discard` Step and STEPS); effects/rules.ts:100
//   (spellClassOfAction); tests plan/apply.test.ts:58,63,82,171,173,214-243, plan/resources.test.ts:262,
//   effects/hooks.test.ts:113, zones/hand.test.ts:19
// bots: draft.ts:225-228 discardDown, the only producer, called at random-bot.ts:80,
//   greedy-bot.ts:127 (with `cheapest`) and turtle-bot.ts:125 (with `this.discards`, :284);
//   README.md:34,36,59,74,98,111; tests draft.test.ts:185, greedy-bot.test.ts:499-505,
//   random-bot.test.ts:182, turtle-bot.test.ts:336, rules.test.ts:81, test/referee.ts:303-305
//   (`case 'discard'`) and :315-317 (keeps more than handLimit), referee.test.ts:10, fixtures/greedy.ts:195
// sim-cli: test/scripted.ts:185 (the golden script)
// web planning: PlanContext.tsx:48 ({ kind: 'discard' }), HandEntry.tsx:25,86-98 (the Discard button
//   and the "Select X to discard" checkboxes), index.tsx:192-193,275-285 (the "Discard N" confirm
//   pushes the action), draft.ts:157-158 (its label); tests PlanningActions.test.tsx:378-387,432-434,
//   targets.test.ts:119,246,271, Zones.test.tsx:324-326
// docs: PROTOCOL.md:177,313; packages/cards/README.md:1126 (the name clash with the DSL effect)

// protocol: CardsDiscardedEvent (event.ts:802) { type: 'cards.discarded', seat, cards: CardId[] };
//   PlanCheckedEvent (:196) is the model for a private answer; visibility.ts:11,22-23 keeps
//   plan.checked to its seat. Command (command.ts:21) is plan.submit | player.ready.
// web: apps/web/src/host/host.ts:226-241 switches on command.type; model/apply.ts:469 checks every
//   event type with `const unhandled: never = event`.
```

What this task adds:

```ts
// packages/protocol
/** The cards a seat discards in Cleanup's Discard step, from its hand (D42). */
export const DiscardChooseCommand = z.strictObject({ type: z.literal('discard.choose'), seat: Seat, cards: z.array(CardInstanceId) });
/** Why core refuses a seat's Discard-step choice. */
export const DiscardRefusal = z.enum(['notDue', 'count', 'unavailable']);
/** The host's answer to `discard.choose` (core's checkDiscards). Private to that seat. */
export const DiscardCheckedEvent = z.strictObject({
  type: z.literal('discard.checked'), seat: Seat, cards: z.array(CardInstanceId),
  /** null: accepted, and the next round starts by discarding these. */
  reason: DiscardRefusal.nullable(),
});
// PlayerSnapshot gains, public like handCount:
/** Cards this seat must discard in the Discard step at the end of Cleanup; 0 otherwise (D42). */
discardCount: Count,
// PROTOCOL_VERSION 25 → 26

// packages/core (round/index.ts exports them)
/** A Discard-step choice checked against the game (D42): `reason` null when it's accepted. */
export function checkDiscards(state: GameState, seat: Seat, cards: readonly CardInstanceId[]): DiscardCheckedEvent;
export type SeatDiscards = Readonly<Partial<Record<Seat, readonly CardInstanceId[]>>>;
export function beginRound(input: GameState, discards?: SeatDiscards): BeginRoundResult;
// Player gains discardCount: number (0 at setup).
```

## Deliverables

1. **Protocol.** `discard.choose` joins `Command`, `discard.checked` joins `Event` and is private to its seat in visibility.ts, and `discardCount` joins `PlayerSnapshot`. `DiscardAction` leaves `PlanAction`, `PlanActionType` and the exports. `PROTOCOL_VERSION` is 26. docs/PROTOCOL.md covers it all in Commands, Plans, Events, Snapshot › PlayerSnapshot and the title.
2. **Cleanup counts.** Step 6 no longer moves cards or emits `cards.discarded`. After the win check, and only when the game goes on, each seat's `discardCount` is how many cards its hand holds over `handLimit`. It's 0 when Old Library or the round's `noHandSizeLimit` rule lifts the limit (the `noLimit` snapshot at :307). At the game's end every count stays 0.
3. **checkDiscards.** It answers `notDue` when the seat's count is 0 or the game isn't in Cleanup, then `count` when the cards aren't exactly `discardCount`, then `unavailable` when a card isn't in the seat's hand or comes twice. Otherwise `reason` is null. It's pure and changes nothing.
4. **beginRound resolves the step first.** Each seat with a count discards its accepted choice in the order given (zones `discard()`), or else its most recently drawn cards (today's rule). Each seat that discards gets a `cards.discarded`, in seat order, before `round.started`. Then the counts go back to 0 and the round begins as today. It throws when a choice is one `checkDiscards` refuses, including a choice for a seat with nothing to discard: the host only passes accepted ones.
5. **No plan action.** Core's `discard` Step and `spellClassOfAction`'s case go. `discardToHandLimit` gives way to what Cleanup and `beginRound` need: a count, and a newest-first discard of N. The view puts `discardCount` in `PlayerSnapshot`.
6. **Consumers.**
   - Bots: the planners stop calling `discardDown`, which goes, along with any pick helper only it used; T-114 writes the bots' choices. The referee drops its `discard` case and its check that a plan keeps no more than `handLimit` cards.
   - sim-cli: the golden script loses its discard. Regenerate the goldens, and in your handoff name the cause of each diff: the version, `discardCount`, or `cards.discarded` moving.
   - Web: the planning panel loses the Discard button, its checkboxes, the `discard` selection and its label, and their tests. model/apply.ts takes `discard.checked` and folds nothing from it. host.ts ignores `discard.choose`, since T-116 runs the step. The planning fixtures get `discardCount: 0` for each player, and the log fixtures follow the protocol where they carry what changed.
   - READMEs: bots (the lines above), cards (:1126), core (the round's steps), protocol.
7. **Tests.**
   - Cleanup's counts: a hand of 10 gives 2; Old Library or the rule gives 0; a game that ends gives 0.
   - Each `checkDiscards` reason, and the accepted case.
   - `beginRound`: with a choice; without one (newest first, the old rule's cards); with a refused choice (throws); with two seats; and the event order (`cards.discarded`, then `round.started`).
   - A whole-game test where a hand goes over the limit and the next round starts with it at the limit.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm test:soak` passes
- [ ] `pnpm --filter @chaosgrid/core test -- discard cleanup begin` passes
- [ ] `grep -rn --include='*.ts' --include='*.tsx' "action: 'discard'" packages apps/web/src tools` prints nothing
- [ ] `grep -c -E "discard\.choose" docs/PROTOCOL.md` prints at least 1
- [ ] `pnpm test:e2e` passes

## Out of scope

- The bots' choices, and sim-cli passing them (T-114).
- The host's Discard step, and the screen's prompt and clock (T-116).
- The DSL effect `discard` (Discard (N), effects/handlers/discard.ts): it stays.

## Notes

- The step lives inside `cleanup`, with no new `Phase` value. That leaves `PHASE_NAMES` and every switch over phases alone. A client knows the step is on from its seat's `discardCount`.
- Choices don't touch the state until `beginRound`, so nothing leaks to other seats during the step (D34's spirit). `cards.discarded` makes the cards public when the round begins.
- `cards.discarded` holds card ids (`CardId`), as today. The chosen cards go in the order given, the automatic ones newest first, as `discardToHandLimit` does today.
- Default: `beginRound` without `discards`, or without a seat's entry, applies the automatic rule to every seat that has a count. The host and sim-cli keep working unchanged until T-114 and T-116.
- Bots used to trim their hands during Plan. From this card until T-114, they keep every card and the automatic rule trims them. Soak numbers can move a little; report them if a threshold fails.
