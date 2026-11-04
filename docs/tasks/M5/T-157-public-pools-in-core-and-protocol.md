---
id: T-157
title: Public pools in core and protocol
milestone: M5
depends_on: [T-155]
branch: agent/T-157-public-pools-in-core-and-protocol
model: opus
effort: high
scope:
  - packages/protocol/src/**
  - packages/protocol/README.md
  - packages/core/src/**
  - docs/PROTOCOL.md
  - apps/web/src/match/model/apply.ts
  - apps/web/src/match/overlays/log.ts
  - apps/web/test/fixtures/**
context:
  - docs/RULES.md#Components and setup
  - docs/RULES.md#Resources and attaching
  - docs/PROTOCOL.md#Visibility
  - docs/PROTOCOL.md#Snapshot
  - docs/PROTOCOL.md#Versioning
---

# T-157 — Public pools in core and protocol

## Goal

D57 makes resource pools public, as lands in play are in Magic (the human, 2026-11-04). Every seat sees every seat's pool: its resources, which are rested, and which are attached and to which squad. During Plan, each seat sees the others as they were when Plan opened, before its draws: pools, hand sizes and deck sizes too, so a seat's draws show with its plan.

This task is the shared contract (planning rule 2), at protocol version 29: every pool in the snapshot, and an event everyone sees for each change to a pool. T-163 folds them into the web's match model, T-161 draws the pools behind the grids, and T-162 uses `permanent.rested`.

## Interfaces

D57, as the code repo's DECISIONS.md has it: "(Extends D34.) Resource pools are public, and each lies behind its seat's grid. Every seat sees every seat's pool: its resources, which are rested, and which are attached and to which squad. The pool is outside the grid … The sizes of every main deck, resource deck and discard pile stay public. During Plan each seat sees the other seats as they were when Plan opened, before its draws, pools and sizes included, so a seat's draws show with its plan. Every change to a pool is an event that everyone sees once it's public: `resource.played` when a resource enters a pool, a rest, an attach and a detach. …"

What exists (copied on 2026-11-04, plus T-155):

```ts
// packages/core/src/round/begin.ts › beginRound: … enterPhase(ctx, 'plan'); fillCostChanges(state);
//   for (const { seat } of state.players) drawPlan(effects, seat);   // emits card.drawn, resource.drawn
//   const snapshots = state.players.map(({ seat }) => snapshotFor(state, seat));
// packages/core/src/view/hide.ts
export function hidePlans(state: GameState): void;   // keeps what every seat sees now; a 2nd call in the round keeps the 1st
export function revealPlans(state: GameState): void;
export function hiddenPlans(state: GameState): HiddenPlans | null;  // only while phase === 'plan'
// Called today by round/play.ts › applyRoundPlans (before applyPlans) and round/check.ts › checkPlan.
// round/game.ts:53 and effects/drawing.ts:33 emit resource.drawn (setup's draws, and every other draw).
// effects/triggers.ts:166: `if (fired && permanent !== null && restsAfterUse(permanent)) permanent.rested = true;` (no event)
// round/cleanup.ts:278 unrests every permanent; zones/resources.ts › cleanupResources(state, seat)
//   returns attached resources and sends `spent` ones to the bottom of the resource deck.
// zones/resources.ts › attachResources(...) (the `attach` action), detachResources(state, squadId)
//   (a banished squad's resources go back to the pool), spendAttached(state, squadId).

// packages/protocol/src/snapshot.ts
export const PlayerSnapshot = z.strictObject({ seat, points, handCount, discardCount, deckCount,
  resourceCount, resourceDeckCount, emblems, void, discardPile });
// Snapshot.resources: the seat's own pool as PoolResource { card, cardId, gives, rested, attachedTo,
//   floating (T-155), spell, target? }

// packages/protocol/src/event.ts, from T-155: ResourceRestedEvent { type: 'resource.rested', seat,
//   card, cardId, reason: 'mana' | 'ability' }, visible to its seat only.
// packages/protocol/src/visibility.ts: `resource.drawn` and `card.drawn` to the seat that drew;
//   `ability.triggered` for a resource to its owner only, "since the pool is hidden".

// apps/web/src/match/model/apply.ts: the web model unrests every unit at `round.ended`, after
//   Cleanup; it ignores resource events today.
```

## Deliverables

1. **Every pool in the snapshot.** `PlayerSnapshot.pool: PoolCard[]`, with `PoolCard` `{ card, cardId, rested, attachedTo }` in pool order. A seat's own entry is live; while plans are hidden, every other seat's is as it was when Plan opened. `Snapshot.resources` stays the own pool with its planning fields, `floating` included; other seats' floating mana never shows.
2. **Hidden from when Plan opens.** `beginRound` calls `hidePlans` after Plan opens and before the seats draw. Then the other seats' hand sizes, deck sizes, pools and everything `hidePlans` keeps are as they were before this Plan's draws, until `plans.revealed`. `checkPlan` and `applyRoundPlans` keep calling it; the second call keeps the first copy.
3. **Events everyone sees** (each in `isVisibleTo` as everyone's):
   - `ResourcePlayedEvent`, `{ type: 'resource.played', seat, card, cardId, rested }`: a resource entered a seat's pool, once per resource. Outside Plan it comes right after that resource's `resource.drawn`, and setup's draws count. The Plan's draws are held back: `applyRoundPlans` emits them before the first plan applies, seat by seat in draw order. A resource that a plan's effect draws gets its `resource.played` as it's drawn, since the plans have locked by then.
   - `ResourcesAttachedEvent`, `{ type: 'resources.attached', seat, squad, resources }`: an `attach` action attached them.
   - `ResourcesDetachedEvent`, `{ type: 'resources.detached', seat, squad, resources }`: they left a squad mid-round and are back in the pool, unattached (a banish or a sacrifice).
   - `ResourcesSpentEvent`, `{ type: 'resources.spent', seat, resources }`: at Cleanup they left the pool for the bottom of the resource deck (a consumed ability).
   - `PermanentRestedEvent`, `{ type: 'permanent.rested', permanent }`: an activated effect rested a free-standing permanent (`triggers.ts:166`).
   - `resource.rested` (T-155) becomes everyone's.
   Cleanup's own resets stay implicit, as for units: every resource and permanent unrests and every attached resource returns at Cleanup, before `round.ended`. PROTOCOL.md says so, so a model resets them at `round.ended`.
4. **What stays private:** `resource.drawn` and `card.drawn` (the seat that drew, at once), and `ability.triggered` for a resource. Core can emit that one while Plan is open, for a Plan draw's trigger, so it stays its owner's; the docs give that reason instead of "the pool is hidden".
5. **The rest compiles:** the web model ignores the new events (T-163 folds them), the three JSON fixtures get `pool` and version 29, and `PROTOCOL_VERSION` becomes 29.
6. **Docs:** `docs/PROTOCOL.md` › `PlayerSnapshot` (`pool`), a `PoolCard` section, the new events in Planning and Board (or Card events), Visibility (the rows, and "other seats' hands and decks appear only as counts; pools are public (D57)"), the paragraph on hidden plans ("as they were when Plan opened, before its draws"), and Versioning row 29. `packages/protocol/README.md` where it lists events.
7. **Tests:**
   - protocol: the schemas parse; each new event and `resource.rested` is visible to every seat; `resource.drawn` still only to its seat.
   - core: during Plan, seat 1's snapshot shows seat 0's pool, `handCount`, `deckCount` and `resourceDeckCount` as before this Plan's draws, and seat 0's own as live. After `playRound`, the Plan's draws each have one `resource.played`, before the first plan's events, in seat order. Setup's resources are played at the game's start. An `attach` gives `resources.attached`, a banished charged squad gives `resources.detached`, a consumed ability gives `resources.spent` at Cleanup, and an artifact whose activated effect fired gives `permanent.rested`. After `plans.revealed`, every snapshot shows every pool live.
   - `pnpm test:soak`: the bots read the snapshot, and the other seats' counts now come from before the draws.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/protocol test`, `pnpm --filter @chaosgrid/core test`, `pnpm --filter @chaosgrid/bots test` and `pnpm --filter @chaosgrid/web test` pass.
- [ ] `pnpm test:soak` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The web model's pools and the round log's lines for these events: T-163. Drawing the pools and piles behind the grids: T-161.
- Rested permanents drawn darker: T-162.
- A target kind for resources, and spells that rest an opponent's resource: RULES allows them (D57), and no card has one yet. They come with the first such card.
- Bots that read other seats' pools.

## Notes

- Defaults: `PoolCard` has no `gives`: the card data has it, by `cardId`. A pool lists attached resources too, with `attachedTo` set, as `resourceCount` counts them.
- If an existing test pins another seat's `handCount` during Plan after the draw, it changes with deliverable 2: say which in the PR.
- `apps/web/src/match/overlays/log.ts` is in the scope only in case its switch needs the new events to compile.
