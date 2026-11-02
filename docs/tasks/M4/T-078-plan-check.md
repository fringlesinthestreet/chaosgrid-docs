---
id: T-078
title: Plan check and the plan.checked event
milestone: M4
depends_on: [T-062, T-098, T-101]
branch: agent/T-078-plan-check
model: opus
effort: high
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/core/src/round/check.ts
  - packages/core/src/round/check.test.ts
  - packages/core/src/round/index.ts
  - packages/core/src/round/play.ts
  - packages/core/README.md
context:
  - docs/tasks/M4/README.md#The match
  - docs/PROTOCOL.md#Commands
  - docs/PROTOCOL.md#Planning
  - docs/PROTOCOL.md#Visibility
  - docs/PROTOCOL.md#Versioning
  - packages/core/README.md#Public API
---

# T-078 — Plan check and the plan.checked event

## Goal

The planning panel has to show, while the player plans, which actions core will refuse and what the seat looks like with its plan applied: cards gone from the hand, resources rested, squads on the grid, and the cards a utility spell draws (RULES.md: a utility spell resolves during Plan, and its result can be used in the same Plan). Today core only applies plans in `playRound`, after every seat is ready. Copying the rules into the web would drift (D29). After this task, core has `checkPlan(state, seat, plan)`: a dry run of one seat's plan with exactly the options `playRound` uses, returning a new seat-private event, `plan.checked`, with the refused actions and the seat's snapshot after the plan. A seat's plan only grows during Plan (D37), so protocol also gets `extendsPlan`, the test a host applies to each `plan.submit`.

## Interfaces

What exists (copied from the code on 2026-10-28, protocol v21; T-101 makes it v22 before this card starts):

```ts
// packages/core/src/round/play.ts:41, private
function applyRoundPlans(ctx: Ctx, plans: SeatPlans): void {
  const { state } = ctx;
  hidePlans(state);
  applyPlans(ctx, plans, {
    forbidden: (seat, action) => forbiddenByRules(state, seat, action),
    levelUpCost: (squad) => levelUpCost(state, squad),
    settle: settlePlanDraws,
  });
  revealPlans(state);
  syncScoringModifiers(state);
}
// packages/core/src/plan/apply.ts
export function applyPlan(ctx: Ctx, seat: Seat, plan: Plan, options: PlanOptions = {}): void; // :85
export function applyPlans(ctx: Ctx, plans: SeatPlans, options: PlanOptions = {}): void; // seat order
// view/: snapshotFor(state, seat). Between hidePlans and revealPlans, "each seat sees its own plan
// applied and the other seats as they were" (view/index.ts).

// packages/protocol/src/event.ts:157
export const PlanRejectedEvent = z.strictObject({
  type: z.literal('plan.rejected'), seat: Seat, index: z.int().min(0),
  action: PlanActionType, reason: RejectReason,
});
// visibility.ts: isVisibleTo's switch lists every event type; plan.rejected is seat-only.
```

What this task adds:

```ts
// packages/protocol/src/event.ts
/** One action core would refuse: as in plan.rejected, without type and seat. */
export const PlanRejection = z.strictObject({ index, action: PlanActionType, reason: RejectReason });
/** The answer to a seat's plan.submit during Plan: a preview, never applied. Private to that seat. */
export const PlanCheckedEvent = z.strictObject({
  type: z.literal('plan.checked'),
  seat: Seat,
  /** The actions core would refuse, in plan order. Empty when the whole plan applies. */
  rejected: z.array(PlanRejection),
  /** What the seat would see with its plan applied (others as they were). */
  snapshot: Snapshot,
});
// Event gains PlanCheckedEvent; isVisibleTo: event.seat === seat; PROTOCOL_VERSION 22 → 23

// packages/protocol/src/plan.ts
/**
 * Whether `next` starts with every action of `previous`, deep-equal and in the same order (D37).
 * True for the same plan, and for any plan after the empty one.
 */
export function extendsPlan(previous: Plan, next: Plan): boolean;

// packages/core/src/round/play.ts
/** The options playRound applies plans with. checkPlan uses the same ones. */
export function roundPlanOptions(state: GameState): PlanOptions;

// packages/core/src/round/check.ts, exported from the public entry
/**
 * A dry run of `seat`'s plan on a copy of `state`, in its Plan phase: what `playRound` would refuse
 * and the seat's snapshot after it. Pure (D8). Exact for the seat that applies first (seat 0);
 * for a later seat, the plans before it can change the result, and plan.rejected is final.
 */
export function checkPlan(state: GameState, seat: Seat, plan: Plan): PlanCheckedEvent;
```

## Deliverables

1. **Protocol.**
   - `PlanRejection` and `PlanCheckedEvent` in `event.ts`, in the Event union. `PlanRejectedEvent` stays as it is.
   - `isVisibleTo`: `plan.checked` is visible to its seat only.
   - `extendsPlan` in `plan.ts`, exported from the entry. It compares actions by value, not by reference, since a plan may cross a worker or a socket.
   - Bump `PROTOCOL_VERSION` to 23. Add a sample to `test/fixtures/samples.ts`, and the cases to `event.test.ts` and `visibility.test.ts`.
2. **PROTOCOL.md.**
   - › Commands: during Plan, a seat may send `plan.submit` any number of times. Each one must extend the seat's last `plan.submit` of this round (`extendsPlan`, D37), and the latest replaces the earlier ones. The host answers each with `plan.checked`, and ignores, without an answer, one that doesn't extend the last or comes after that seat's `player.ready`.
   - › Planning: `plan.checked`, what it carries, and that it's a preview: `plan.rejected` at the end of Plan stays the final word. A refused action stays in the plan, since the plan only grows, and the round skips it.
   - › Visibility: the new row.
   - › Versioning: "`PROTOCOL_VERSION` is 23." and a v23 row; bump the version in the title too (`docs.test.ts` checks both).
3. **Core.**
   - `roundPlanOptions(state)` in `play.ts`, and `applyRoundPlans` uses it, so the dry run and the real round can't drift.
   - `checkPlan` in `round/check.ts`: copy the state, `makeCtx`, `hidePlans`, `applyPlan` for that seat with `roundPlanOptions`, then build the event from the dry run's `plan.rejected` events for that seat and `snapshotFor(copy, seat)`. Throws unless the round is in its Plan phase, like `playRound`.
   - Export it from `round/index.ts`; add it to the core README's › Public API.
4. **Tests** (`check.test.ts`, on core's round fixtures, after `beginRound`):
   - an empty plan's snapshot equals the seat's snapshot from `beginRound`
   - `checkPlan` doesn't change its input (deep-equal before and after)
   - **exact for seat 0:** for a plan with a legal unit, an unaffordable unit and a bad cell, `rejected` equals the `plan.rejected` events seat 0 gets from `playRound` with every seat's plan, minus `type` and `seat`
   - **utility draws:** a plan that casts a utility spell that draws (or a Rest ability that does): the checked snapshot's hand holds the drawn cards, and they're the cards `playRound`'s `card.drawn` events give seat 0
   - a placed unit is in the checked snapshot's `squads`, and seat 1's `checkPlan` of the same round doesn't show seat 0's plan
   - a forbidden spell under Fog of War is rejected with `forbidden` (the `roundPlanOptions` wiring)
   - outside Plan, it throws
5. **Tests** (protocol, next to `plan.ts`): `extendsPlan` is true for the same plan, for any plan after the empty one, for a plan with actions added at the end, and for an equal action built with its keys in another order; it's false when an action is removed, changed or moved, or one is added before the end.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm test` passes in every package (sim-cli and bots parse events and snapshots)
- [ ] `pnpm sim --games 20 --seed 1` runs as before: `playRound` never emits `plan.checked`

## Out of scope

- Calling `checkPlan` and enforcing `extendsPlan`: the host does (T-080). Bots don't use either.
- Changing how `playRound` applies plans, beyond sharing its options.
- A "dry run for every seat at once". M6 decides how a networked host previews later seats.

## Notes

- Decision (lead, 2026-10-22): D29. Plan legality and the Plan preview come from core, through `checkPlan` and `plan.checked`. The web never re-implements a rule.
- Why a snapshot and not the dry run's events: the panel needs the seat after its plan, and `snapshotFor` already builds exactly that view (own plan applied, the others hidden). Folding events in the UI would be a second copy of the rules.
- Decision (human, 2026-10-28): D37. No Undo and no Clear during Plan: `plan.checked` shows the cards a utility spell draws, so taking the spell back would be a free look at the deck. `extendsPlan` lives in protocol because it's a rule of the talk between a seat and its host, which every host (the M4 worker, a later server) applies the same way.
- A stated limit: plans apply in seat order, so the preview is exact for seat 0 (the human in a solo match, D40) and approximate for later seats. Say so in the doc comment and in PROTOCOL.md.
- `plan.checked` carries a `Snapshot`, so its schema imports `snapshot.ts`. Check there's no import cycle (`snapshot.ts` doesn't import `event.ts` today).
- M3 is on main (T-062, T-066 and T-098 all merged), and T-101 (`simulate.ending`) makes the protocol v22, so this card starts from v22 and makes it 23. T-090 bumps it after this card, to 24.
- D34: during Plan, core shows other seats as they were when Plan began. `checkPlan` gets that for free from `hidePlans`, so the checked snapshot never leaks another seat's plan.
