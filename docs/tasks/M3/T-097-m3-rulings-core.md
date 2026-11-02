---
id: T-097
title: M3 rulings in core
milestone: M3
depends_on: [T-065]
branch: agent/T-097-m3-rulings-core
model: sonnet
effort: high
scope:
  - packages/core/src/combat/**
  - packages/core/src/plan/**
  - packages/core/src/arena/**
  - packages/core/src/view/**
  - packages/core/src/state/config.ts
  - packages/core/src/state/config.test.ts
  - packages/core/src/effects/handlers/revive.ts
  - packages/core/src/effects/handlers/revive.test.ts
  - packages/core/src/effects/triggers.ts
  - packages/core/src/effects/triggers.test.ts
  - packages/core/test/fixtures/combat/**
  - docs/PROTOCOL.md
  - tools/sim-cli/test/golden/**
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Components and setup
  - docs/RULES.md#Round structure
  - docs/RULES.md#Simulation rules
  - docs/RULES.md#Zone mechanics
  - docs/PROTOCOL.md#Arena layout
  - docs/PROTOCOL.md#Board
  - docs/PROTOCOL.md#Visibility
---

# T-097 — M3 rulings in core

## Goal

The merged M3 tasks left open questions, and the human answered them on 2026-10-26. RULES.md and D34 now say what the game does. Core does four of these things differently today. Make core follow the rules, and fix two PROTOCOL.md lines that don't match the code.

## Interfaces

What exists (copied from the code on 2026-10-26; check it again after T-065):

```ts
// combat/end.ts endReason(state): 'timeUp' first (state.tick >= config.roundTicks), then
//   'lastStanding' (no Chaos alive, at most one seat with a living unit) and 'chaosWon'
// combat/simulate.ts:75  endTick(ctx, board) { checkTrapAreas(ctx.state, board); return endReason(ctx.state); }
// combat/simulate.ts:135 endSimulate(ctx, reason): while (triggersPending(state)) fireTriggers(sim); then simulate.ended
// combat/deaths.ts:66    fireTriggers(ctx): each queued death's fireDeath (On death, an Emblem's breaker
//                        abilities, On kill), then the queued traps, then settleDeaths
// effects/triggers.ts:373 fireDeath(ctx, death): fire(ctx, 'onDeath', { unit: victim, killer, killerUnit }) for a
//                        unit, or an Emblem's onDestroyed; then onKill for the killer and each assist
// combat/deaths.ts:79    triggersPending(state) = state.combat.deaths.length > 0 || state.combat.traps.length > 0

// plan/targets.ts:75 targetProblem(state, planner, spec, target): RejectReason | null
//   discardPileCard: discardPileUnit(…) === null → 'illegalTarget'; !canPlace(…) → 'noRoom'. No filter check.
//   callers: plan/spells.ts:80 and :105 (targetSpecOf(card)), plan/abilities.ts:100 (abilityTargetSpec(ability))
// effects/handlers/revive.ts:47 (not exported)
function cardPasses(card: UnitCard, filter: Filter | undefined, vars: AmountVars): boolean;
//   revivalOf (:96) checks it again when the revive resolves, and does nothing when it fails

// arena/layout.ts:156 arenaLayout(seats, cols, rows, sizes) throws only when chaosEdgeDepth > chaosGridSize
//   const side = Math.max(chaosGridSize, cols);  // a grid wider than the Chaos Grid widens the box
// state/config.ts:15,18  gridCols: positive.default(30), chaosGridSize: positive.default(50)

// view/hide.ts:21 hidePlans(state) keeps { round, counts: SeatCounts per seat, squads, permanents }
//   (T-064 adds units and spawned). view/snapshot.ts:64 swaps another seat's counts for the kept ones.
// view/seats.ts:52 playerSnapshot(state, seat) = { ...seatCounts, points, emblems, void }:
//   points, emblems and void are always live, so a Plan banish shows at once
```

RULES.md, as the human ruled:

- › Round structure › End conditions: `lastStanding` and `chaosWon` "wait while On death triggers are still queued (Simulation rules, step 4): the round goes on until they have fired, so an On death revive can keep a side in the fight. The timer doesn't wait."
- › Zone mechanics › Revive: "Choosing a card the revive doesn't allow (the wrong color, range or HP for its filter) is an illegal target: the action is rejected and nothing is paid."
- › Components and setup: "a grid is never wider than the Chaos Grid".
- D34: during Plan, core's view shows other seats' discard piles, voids, grids and hand sizes as they were when Plan began, and the changes show once the plans are revealed.

## Deliverables

1. **The early ends wait for On death.**
   - `endReason` returns `lastStanding` or `chaosWon` only when no queued death will fire an On death ability. While one will, the round goes on: the next tick fires it (step 1), and the end conditions are checked again at that tick's end.
   - Default: a queued death holds the round when `fireDeath` would run an On death ability for it. Answer that with a helper in `effects/triggers.ts` that finds abilities the way `fire(ctx, 'onDeath', …)` does, so the two can't drift apart. A death with no On death (only On kill or an Emblem's breaker abilities) doesn't hold the round, so most games end on the same tick as today.
   - `timeUp` never waits. `endSimulate` still fires whatever is queued after the end, as it does now.
   - Tests: an On death revive (`unit.gravedigger`, or a made-up card) brings back a seat's last unit, and the round goes on; the same death without an On death ends the round on the tick it does today; `timeUp` ends the round with an On death still queued.
2. **A Plan revive checks its filter.**
   - Export `cardPasses` from `effects/handlers/revive.ts`, and update the comment at the top of that file.
   - A `discardPileCard` target whose card fails the revive's filter is `illegalTarget`: the action is rejected and nothing is paid. Check it before `noRoom`.
   - `targetProblem` doesn't know the ability today. Route the revive's `filter` and its amount variables to it from the callers (`plan/spells.ts`, `plan/abilities.ts`), for example as an optional argument. Pick the smallest change and say in the PR which one.
   - Tests: a made-up Plan revive with a `range` or `color` filter rejects a card outside it with `illegalTarget` and spends nothing; a card inside it still revives. No card has a Plan revive with a filter yet.
3. **A grid is never wider than the Chaos Grid.**
   - `makeConfig` rejects `gridCols > chaosGridSize` with a message naming both.
   - `arenaLayout` throws for `cols > chaosGridSize`, and `side` becomes `chaosGridSize`.
   - Tests for both. The defaults (30 and 50) don't change, so no layout moves.
   - PROTOCOL.md › Arena layout: one sentence saying a grid is never wider than the Chaos Grid.
4. **Plan hides the voids and points too (D34).**
   - `hidePlans` keeps what every seat could see of each player, not only their counts: default, the whole `PlayerSnapshot` (counts, discard pile, `points`, `emblems`, `void`). `snapshotFor` swaps another seat's entry for the kept one, as it does with the counts now.
   - Tests: a utility revive or banish during Plan changes another seat's void, discard pile or points; until `revealPlans`, the other seats see them as they were, and afterwards they see them live. The caster sees its own change at once.
   - PROTOCOL.md › Visibility: the sentence on hidden plans (T-064 adds it) names the void and points too.
5. **PROTOCOL.md › Board:** `unit.saved` comes after the unit's `unit.damaged` with `hp` 0, which is what `health.ts` emits (the row says nothing about the order today).
6. **Goldens.** If Deliverable 1 changes a golden game, regenerate it and say in the PR which games changed and why. Nothing else should change them.

## Acceptance

- [ ] `crew check` is green.
- [ ] `crew check soak` is green.
- [ ] `pnpm --filter @chaosgrid/core exec vitest run end revive layout config snapshot` passes.
- [ ] `pnpm --filter @chaosgrid/core exec vitest run imports` passes: no new import cycle (D35).
- [ ] `git diff main...HEAD -- packages/protocol` prints nothing, and `PROTOCOL_VERSION` doesn't change: no payload changes.

## Out of scope

- Plan-time events. They're public in the log, but every host applies all the plans at once (`playRound`) after every seat locked its own, so no seat sees another's events before planning ends. The snapshot is what D34 hides during Plan.
- On kill and the queued traps: they don't hold the round (RULES.md says On death).
- Any other ruling in the 2026-10-26 CHANGELOG entry. The rest are what core already does.
- Protocol payloads, and `packages/core/src/zones/**` (T-066 holds it).

## Notes

- From the merged M3 tasks' open questions. Decisions (human, 2026-10-26): "Revive can save it"; reject a revive outside its filter with `illegalTarget`; cap the grid width; "Changes to the discard/exile piles and player's grid and hand size are hidden until round's planning ends" (D34).
- The lead's defaults: only an On death holds the round, and the whole `PlayerSnapshot` is kept while plans are hidden.
- Nothing in the arena or effects tests builds a grid wider than its Chaos Grid today (`render.test.ts` uses 4 and 4). If a test outside your scope breaks the new rule, ask `lead`.
- T-062 waits for this task (it regenerates the goldens and checks the done-when), and so does T-098 (the READMEs).
