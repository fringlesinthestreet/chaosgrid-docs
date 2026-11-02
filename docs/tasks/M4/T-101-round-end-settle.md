---
id: T-101
title: Round end settles what's in flight
milestone: M4
depends_on: [T-097]
branch: agent/T-101-round-end-settle
model: opus
effort: high
scope:
  - packages/core/src/combat/**
  - packages/core/src/round/play.test.ts
  - packages/core/src/index.ts
  - packages/core/test/fixtures/combat/**
  - packages/core/README.md
  - packages/protocol/**
  - docs/PROTOCOL.md
  - tools/sim-cli/test/golden/**
  - tools/sim-cli/test/settle.soak.test.ts
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Round structure
  - docs/RULES.md#Simulation rules
  - docs/PROTOCOL.md#Game and round
  - docs/PROTOCOL.md#Projectiles
  - docs/PROTOCOL.md#Visibility
  - docs/PROTOCOL.md#Versioning
  - packages/core/README.md#Events
---

# T-101 — Round end settles what's in flight

## Goal

When Simulate meets an end condition today, the queued triggers fire and every projectile still in flight is dropped. From now on the round settles first (D38): nothing new starts, but what's under way finishes. Projectiles land and can kill, and On death, On kill, Emblem and trap triggers fire, along with whatever they set off. A new `simulate.ending` event marks the tick the fight stopped, so a client can stop its clock without knowing the rule.

## Interfaces

What exists (copied from the code on 2026-10-28):

```ts
// combat/simulate.ts
// simulateTick(ctx): startTick(sim, state.tick + 1); fireTriggers(sim); fireTimed(sim); resolveCopies(sim);
//   settleDeaths(sim); applyBlows(sim, attackAndMove(sim, board)); return endTick(sim, board)
// endTick(ctx, board): checkTrapAreas(ctx.state, board); return endReason(ctx.state)
// startTick(ctx, tick): sets state.tick, empties effects.restDelayed and effects.revived, then
//   expireEffects(ctx) and expireFears(ctx)
export function endSimulate(ctx: Ctx, reason: EndReason): void;
//   while (triggersPending(state)) { fireTriggers(sim); resolveCopies(sim); }  (all in the last tick)
//   clearProjectiles(state); state.combat.ended = reason;
//   emitInTick(ctx, { type: 'simulate.ended', tick: state.tick, reason })
export function simulate(ctx: Ctx): SimulateResult; // { reason, tick: the last tick that ran }

// combat/end.ts
export function endReason(state: GameState): EndReason | null;
//   'timeUp' at state.tick >= config.roundTicks; 'lastStanding' and 'chaosWon' wait while a queued
//   death will fire an On death (firesOnDeath, T-097)

// combat/attacks.ts
function advanceProjectiles(ctx: EffectsCtx, board: Board): Blow[]; // private: projectile.moved and
//   projectile.landed events, and the blows of the projectiles that hit
export function attackAndMove(ctx: EffectsCtx, board: Board): Blow[]; // attacks, moves and flees, then advanceProjectiles
export function applyBlows(ctx: EffectsCtx, blows: readonly Blow[]): void; // damage, each attacker's On attack, settleDeaths

// combat/deaths.ts
export function fireTriggers(ctx: EffectsCtx): void; // each queued death (On death, an Emblem's breaker
//   abilities, On kill), then the queued traps, then settleDeaths
export function triggersPending(state: GameState): boolean; // combat.deaths or combat.traps not empty

// combat/spells.ts   resolveCopies(ctx): the copies effects made (state.effects.copies), one at a time
// combat/traps.ts    checkTrapAreas(state, board): an enemy that entered an armed trap's area sets it off next tick
// effects/triggers.ts fireTimed(ctx): the `every` and `at` abilities due this tick
// projectiles/state.ts clearProjectiles(state); what's in flight: state.projectiles.inFlight, by ProjectileId

// packages/protocol/src/event.ts
export const SimulateEndedEvent = z.strictObject({
  type: z.literal('simulate.ended'),
  tick: Tick,
  reason: z.enum(['timeUp', 'lastStanding', 'chaosWon']),
});
// timeline.ts groupByTick(events) throws without simulate.ended, or when it isn't its step's last event
// visibility.ts isVisibleTo: simulate.ended goes to every seat.  version.ts: PROTOCOL_VERSION = 21
// primitives.ts Tick = z.int().min(0): no upper bound, so ticks past roundTicks are valid
```

What this task adds:

```ts
// packages/protocol
export const SimulateEndingEvent = z.strictObject({
  type: z.literal('simulate.ending'),
  tick: Tick, // the tick at whose end the end condition held
  reason: z.enum(['timeUp', 'lastStanding', 'chaosWon']), // the same enum as simulate.ended's
});
// Event gains SimulateEndingEvent; isVisibleTo: every seat; PROTOCOL_VERSION 21 → 22

// packages/core (public entry)
export const MAX_SETTLE_TICKS = 1_000; // 10 s at most, then what's left is dropped
```

## Deliverables

1. **The settle.** `endSimulate` (or a new `combat/settle.ts` it calls) works like this once an end condition holds, whatever the reason:
   - It emits `simulate.ending { tick, reason }` at once, in the tick the condition held, after that tick's other events.
   - Then it runs settle ticks while a trigger is queued (`triggersPending`) or a projectile is in flight, for at most `MAX_SETTLE_TICKS` ticks. A settle tick runs these steps in order:
     1. `startTick(tick + 1)`, so effects and fears still expire on time.
     2. `fireTriggers`, then `resolveCopies`, then `settleDeaths`.
     3. The projectiles advance and land (`advanceProjectiles`: export it or split it out of `attackAndMove`), and `applyBlows` applies their hits: damage, the source's On attack, deaths.
     4. `checkTrapAreas`, so a unit revived or spawned into an armed trap's area sets the trap off.
   - Never during the settle: attacks, moves, flees, `fireTimed`, or `endReason`.
   - At the cap, what's left is dropped. Projectiles still in flight go as today (`clearProjectiles`). The queued triggers go too, without firing (`state.combat.deaths` and `state.combat.traps` emptied).
   - Then `state.combat.ended = reason` and `simulate.ended { tick, reason }` are emitted as now, where `tick` is the last tick that ran. The reason is always the one in `simulate.ending`, even if the settle changed the board.
   - A settle with nothing to do runs no tick: `simulate.ending` and `simulate.ended` then share a tick.
   - The On death wait (T-097) is unchanged and comes first: `endReason` still holds `lastStanding` and `chaosWon` back while a queued death will fire an On death. The settle starts only once a reason is returned.
   - Update the header comment of `combat/simulate.ts`: its last paragraph says the projectiles in flight are dropped.
   - Tests (made-up cards and built states are fine):
     - A projectile in flight at `timeUp` lands, deals its damage and can kill. The kill scores, and `simulate.ended`'s tick is the tick it landed.
     - A projectile in flight at `lastStanding` still lands.
     - During the settle no unit attacks, moves or flees, and no `every` or `at` ability fires.
     - A death during the settle fires its On death and On kill, and an On death that gives points scores them.
     - A unit revived or spawned into an armed trap's area during the settle sets the trap off.
     - A projectile that can't land within `MAX_SETTLE_TICKS` is dropped at the cap.
     - A round that ends at tick 0 (the spells killed everything) settles too.
     - The T-097 cases still pass.
2. **The protocol.**
   - Add `SimulateEndingEvent` and put it in `Event`.
   - `isVisibleTo` sends it to every seat.
   - `groupByTick` also throws when a Simulate has no `simulate.ending`, has more than one, or has one after `simulate.ended`.
   - Bump `PROTOCOL_VERSION` to 22.
   - Add a sample to `test/fixtures/samples.ts`, and cases to `event.test.ts`, `visibility.test.ts` and `timeline.test.ts`.
3. **Docs.**
   - PROTOCOL.md:
     - The title says version 22.
     - › Game and round gets a `simulate.ending` row, and the `simulate.ended` row says its tick is the settle's last.
     - › Timeline describes the settle.
     - › Projectiles says a projectile still in flight when the round ends lands during the settle.
     - › Versioning gets a row for 22.
   - `packages/core/README.md` › Events describes the settle. If you add `combat/settle.ts`, give it a line in the Module map.
4. **Goldens.** Regenerate the goldens and say in the PR which games changed and why. Rounds with a projectile in flight at the end should change; nothing else should.
5. **Soak.** Add `tools/sim-cli/test/settle.soak.test.ts`, which plays at least 20 whole games with `runGame`, the way `m3-done-when.soak.test.ts` does. It checks that:
   - Every Simulate has exactly one `simulate.ending`, before its `simulate.ended`.
   - No settle reaches `MAX_SETTLE_TICKS`.
   - Between the two events there's no `unit.attacked` and no `unit.moved`.

   It logs the longest settle in ticks. Report that number in the PR body.

## Acceptance

- [ ] `crew check` is green.
- [ ] `crew check soak` is green, `settle.soak.test.ts` included.
- [ ] `pnpm --filter @chaosgrid/core exec vitest run settle simulate end` passes.
- [ ] `pnpm --filter @chaosgrid/core exec vitest run imports` passes: no new import cycle (D35).
- [ ] `pnpm sim --games 20 --seed 1` runs.
- [ ] The PR body names the golden games that changed and the longest settle the soak saw.

## Out of scope

- The web's round clock and the "Round over" banner. T-083 and T-085 read `simulate.ending`.
- The end conditions themselves, the On death wait included (RULES.md › End conditions).
- An effect that launches a projectile. None exists yet; once one does, the settle carries its projectiles like any others.
- Cleanup and scoring. The survival point counts what's alive after the settle, which is what Cleanup reads today (`scoring/points.ts` `survivalGains`).
- Bots: they don't read either event.

## Notes

- From the human, 2026-10-28: "Idea of a round ending is finalizing all inflight stuff (events/projectiles/abilities/etc), while preventing new events/projectiles/abilities/etc from starting from the current permanents. They could trigger new events (on death/on kill) and should fire even if they spawn new projectiles/abilities." Their examples: an On death that gives a point is allowed, and so is one that explodes and fires projectiles at random.
- The lead's defaults (D38): the On death wait stays before the settle; a landing projectile's On attack fires, because it's set off by something already in flight; effects expire on time; the cap is 1,000 ticks and drops what's left. If the human changes one, the lead updates this card.
- The clock keeps running during the settle so that projectiles fly at their speed and effects expire on their tick. A client freezes its round clock at `simulate.ending` instead.
- Projectiles fly at least 5 cells per second (`PROJECTILE_SPEED.min` in `packages/cards`), and Artillery reaches 6 cells, so a projectile lands within about 2 s of the stop. The cap is there for trigger chains that never end.
- `round/play.test.ts` checks that `simulate.ended` comes right before Cleanup. Keep that true.
- T-078 waits for this task, because both change `packages/protocol`. It moves the protocol to v23, and T-090 to v24 after it.
