---
id: T-129
title: Round previews for bots
milestone: M5
depends_on: [T-112]
branch: agent/T-129-round-previews
model: opus
effort: high
scope:
  - packages/protocol/src/preview.ts
  - packages/protocol/src/preview.test.ts
  - packages/protocol/src/index.ts
  - packages/protocol/src/docs.test.ts
  - packages/protocol/README.md
  - docs/PROTOCOL.md
  - packages/core/src/round/preview*.ts
  - packages/core/src/round/rebuild*.ts
  - packages/core/src/round/perf.test.ts
  - packages/core/src/round/play.ts
  - packages/core/src/round/index.ts
  - packages/core/test/fixtures/round/previews.ts
  - packages/core/README.md
context:
  - docs/RULES.md#Round structure
  - docs/RULES.md#Scoring and winning
  - docs/PROTOCOL.md#Conventions
  - docs/PROTOCOL.md#Snapshot
  - docs/PROTOCOL.md#Versioning
  - packages/core/README.md#Public API
  - packages/core/README.md#The state
---

# T-129 — Round previews for bots

## Goal

D49 (2026-10-29): bots may look ahead by previewing a round, from what their seat can see and within a fixed budget. After this PR core has `previewRound`. It builds a round from one seat's snapshot, applies that seat's plan, plays Simulate for at most `maxTicks` ticks and reports what happened as a protocol `RoundPreview`. Bots get it as a `Simulator` from whoever runs them, so `packages/bots` still imports only protocol. T-135 writes the planner bot and passes the simulator in from the web host and sim-cli.

Real games don't change. No Command, Event or Snapshot changes, so `PROTOCOL_VERSION` stays where T-112 left it, and the goldens stay byte for byte.

## Interfaces

What exists (copied from the code on 2026-10-29). T-110 and T-112 change round/, the config and the snapshot first: re-read round/play.ts, round/begin.ts and protocol/src/snapshot.ts when you start.

```ts
// packages/core/src/round/play.ts
export function roundPlanOptions(state: GameState): PlanOptions;                 // :41
function applyRoundPlans(ctx: Ctx, plans: SeatPlans): void;                      // :54, not exported:
//   hidePlans(state); applyPlans(ctx, plans, roundPlanOptions(state)); revealPlans(state); syncScoringModifiers(state);
export function playRound(input: GameState, plans: SeatPlans): PlayRoundResult;  // :76: a copy; throws unless
//   phase is plan; makeCtx; applyRoundPlans(ctx, structuredClone(plans)); enterPhase(ctx, 'simulate');
//   simulate(ctx); enterPhase(ctx, 'cleanup'); cleanup(effectsCtx(ctx)) …
// round/check.ts:23 checkPlan(state, seat, plan): PlanCheckedEvent maps `plan.rejected` to { index, action, reason }.
// round/context.ts, internal to round/: effectsCtx(ctx): EffectsCtx (:15), enterPhase(ctx, phase) (:25).
// round/cleanup.ts:304 cleanup(ctx). Step 1: syncScoringModifiers, scoreCleanup (scoreSurvival, then
//   applyRoundPoints), onRoundEnd, resolveDelayed.
// round/index.ts exports the public API; src/index.ts re-exports round/ and isn't edited (core README).

// packages/core/src/combat/simulate.ts: the steps of simulate(ctx) (:164)
export function beginSimulate(ctx: Ctx, spells?: readonly CastSpell[]): EndReason | null; // :103, tick 0
export function simulateTick(ctx: Ctx): EndReason | null;                                // :124, the next tick
export function endSimulate(ctx: Ctx, reason: EndReason): void; // :144: simulate.ending, settle (at most
//   MAX_SETTLE_TICKS = 1_000 ticks, combat/settle.ts:22), simulate.ended
// EndReason is 'timeUp' | 'lastStanding' | 'chaosWon' (combat/end.ts:24, endReason(state)).

// packages/core/src/state/ctx.ts
export interface Ctx { readonly state: GameState; emit(event: GameEvent): void } // :10; makeCtx (:21) keeps every event

// packages/core/src/scoring
// state.ts:33-49 thisRound: Record<Seat, RoundPoints { gains: Record<ScoreReason, number>; adjustment: number }>.
//   `adjustment` is what Toxic's pointsGained factor changed; Cleanup reports it as `chaos`.
// cleanup.ts:19 applyRoundPoints: a reason's points are gains[reason], plus adjustment for chaos.
// points.ts: killGains(state, { unit, killer }) (:71) and prizeGains(state, { permanent, breaker }) (:120) are
//   queries that return Gain[] ({ seat, reason, points }); scoreSurvival(state) (:182) records survival.

// packages/core/src/state: createState({ seed, config, cards }) create.ts:51 (the catalog keeps the card
//   objects; nextId 1); makeConfig(input) config.ts:71 (strict); newId :36, idNumber :43, compareIds :63 (ids.ts)
// packages/core/src/view: snapshotFor(state, seat) snapshot.ts:64; settingsOf(state) :35;
//   arenaLayoutFor(state, round?) arena.ts:18; levelUnlocked(squad, unlock) board.ts:38
// packages/core/src/effects: tokens: Record<SquadId, TokenExpiry { untilRound; untilTick }> (state.ts:299);
//   fillCostChanges(state) costs.ts:25; syncScoringModifiers(state) players.ts:150;
//   runAbility(ctx, run, ability) triggers.ts:111; makeRun(state, source, index, facts) sources.ts:143
//   (the `destroyer` target is facts.destroyer, targets.ts:66). Statics are read live from the board.
// packages/core/src/chaos/state.ts: RevealedChaos { card, extra, targets, squads, permanents };
//   ChaosState.emblems: Record<Seat, CardInstanceId[]>, the Emblems each seat has broken.

// packages/protocol/src/snapshot.ts:357-389, what a seat sees when Plan starts (beginRound's snapshots):
//   seat, round, phase, tick, settings (GameSettings :46), players (PlayerSnapshot :88: points, counts,
//   emblems: CardId[], void: CardId[], discardPile with instance ids), arena, hand, leader, resources,
//   squads (printed stats, level, durability, unlocked, attached: Count), units (cell, hp, maxHp, keywords),
//   spawned, permanents (the ones it can see), chaos (ChaosSnapshot :270: card, kind, targets, squads),
//   emblems, prizes (PrizeSnapshot :298: hp, maxHp), rules
// protocol/src/event.ts: PlanRejection (:182) { index, action, reason }; ScoreReason (:810), 8 reasons;
//   UnitDiedEvent (:403) { unit, killer }; PermanentDestroyedEvent (:665) { permanent, owner, killer, faceDown };
//   the end reasons are inline in SimulateEndingEvent (:101) and SimulateEndedEvent (:115).
// protocol/src/primitives.ts: Hp (a number ≥ 0), Count, Tick, perSeat(entry) (:152, exactly SEATS entries).
```

What this task adds:

```ts
// packages/protocol/src/preview.ts (new). Not a Command, Event or Snapshot, so no version bump.
/** A bot's look-ahead for one decision (D49): counts, never wall-clock time. */
export const PreviewBudget = z.strictObject({
  /** Previews per decision (one `plan` call). */
  previews: z.int().min(1),
  /** Each preview's tick cap: core's `maxTicks`. */
  ticksPerPreview: z.int().min(1),
});
/** One seat's side of a previewed round. */
export const SeatPreview = z.strictObject({
  seat: Seat,
  /** The round's points by reason when the preview stopped, unrounded. `chaos` includes Toxic's adjustment. */
  points: z.record(ScoreReason, z.number()),
  /** The kill, leaderKill and prize points other seats scored off this seat (killGains, prizeGains). */
  conceded: z.number().min(0),
  /** Its units that died, tokens included. */
  unitsLost: Count,
  /** Its units alive when the preview stopped. */
  unitsAlive: Count,
  /** Its prize's HP when the preview stopped: 0 once destroyed, or when it has none. */
  prizeHp: Hp,
});
/** What a round would do from one seat's snapshot and plan (core's previewRound). */
export const RoundPreview = z.strictObject({
  /** The seat whose snapshot it was built from. */
  seat: Seat,
  seats: perSeat(SeatPreview),
  /** Each Emblem of the snapshot, with its HP when the preview stopped. */
  emblems: z.array(z.strictObject({ permanent: PermanentId, hp: Hp })),
  /** The plan's actions core skipped, as checkPlan reports them. */
  rejected: z.array(PlanRejection),
  /** The last tick that ran. */
  endTick: Tick,
  /** Why Simulate ended; null when the tick cap came first. */
  ended: z.enum(['timeUp', 'lastStanding', 'chaosWon']).nullable(),
});
/** How a bot looks ahead (D49). Its runner binds core's previewRound with the budget's tick cap. */
export type Simulator = (snapshot: Snapshot, plan: Plan) => RoundPreview;

// packages/core/src/round/preview.ts (new; round/index.ts exports both)
export interface PreviewOptions {
  /** The last tick Simulate runs, an integer ≥ 0. A round that ends sooner still settles. */
  maxTicks: number;
}
export function previewRound(snapshot: Snapshot, plan: Plan, cards: Iterable<Card>, options: PreviewOptions): RoundPreview;

// packages/core/src/round/rebuild.ts (new; internal to round/, like context.ts)
export function stateFromSnapshot(snapshot: Snapshot, cards: Iterable<Card>): GameState;

// packages/core/src/round/play.ts: applyRoundPlans (:54) gains `export`. Nothing else there changes.
```

## Deliverables

1. **Protocol.**
   - `preview.ts` holds the three schemas and `Simulator`, and index.ts exports them.
   - `preview.test.ts`: a preview parses. One with a reason missing from `points`, or with 3 seats, doesn't.
   - docs.test.ts checks every field of `RoundPreview`, `SeatPreview` and `PreviewBudget`, and the type `Simulator`.
   - PROTOCOL.md gets a `## Round previews` section between Snapshot and Versioning (T-135's context reads that heading) and a Contents line. "Points are integers" gets an exception: previews carry fractions, because bots compare plans by them and no player sees them.
   - README › Files gets `preview.ts`.
   - `PROTOCOL_VERSION` doesn't change.
2. **`stateFromSnapshot`.** It returns a game in Plan that `snapshotFor(state, snapshot.seat)` turns back into `snapshot`, except for the counts of what the seat can't see. In order:
   - It throws when the snapshot isn't from the start of Plan (`phase` plan, `tick` 0), when a card id isn't in `cards` (name it), and when a squad's `attached` isn't 0 (Cleanup detaches every resource).
   - It calls `createState` with the seed `'preview'`, `cards`, and a config of every `GameSettings` field, plus `prizeHp` from the prizes' `maxHp` when there are any. Round, phase and tick come from the snapshot.
   - It adds the players in seat order, with `points` from `players[seat].points`. The seat's own Leader is its `leader` card, or its Leader squad's card. Another seat's Leader is the sentinel `'c0'`, which nothing reads: only plan/squads.ts:136 does, for the seat's own `castLeader`.
   - Card instances, squads, units and permanents keep the snapshot's ids. Units keep their cells, layer and HP. The hand, the pool (with zones/' `ResourceStatus`), the Leader in command and every discard pile come back as they are. Where the snapshot has only a card id (kept Emblems, the void, a standing Emblem whose card isn't in `chaos`), make a fresh instance.
   - It sets each squad's `roundsOnGrid` and `damageDealt` so `levelUnlocked` gives the snapshot's `unlocked`. A Chaos squad's `spawnedFor` comes from its Chaos card's `targets`, paired with its `squads` in order (chaos/spawn.ts). Spawned tokens go in `effects.tokens` with no expiry.
   - It fills `chaos.revealed` from `chaos`, and `chaos.emblems` from each seat's `emblems`. Then it runs each kept Emblem's `onDestroyed` abilities with `duration: 'game'` again for that seat (`runAbility`, with `makeRun` and `destroyer: seat`). Today those are Crown Shard's and Ancient Cache's buffs. Then it clears `scoring.thisRound`.
   - It sets `nextId` to one more than the highest id number (`idNumber`), so new ids never clash.
   - It ends with `fillCostChanges` and `syncScoringModifiers`, and throws if `arenaLayoutFor(state)` isn't `snapshot.arena`.
3. **`previewRound`.** Pure (it changes neither the snapshot nor the plan) and deterministic. In order:
   - It calls `stateFromSnapshot`, then makes a `Ctx` whose `emit` keeps no list. It counts each `unit.died` by its unit's owner and each `plan.rejected`, and keeps the end reason. When a seat's unit dies, it adds that death's `killGains` to the seat's `conceded`; when a seat's prize is destroyed, its `prizeGains`. It reads the state as each event comes.
   - It calls `applyRoundPlans(ctx, { [seat]: structuredClone(plan) })`, then `enterPhase(ctx, 'simulate')`, as `playRound` does. Other seats have no plan.
   - It calls `beginSimulate`, then `simulateTick` while no end reason holds and the tick is below `maxTicks`. When the round ended, `endSimulate` settles it.
   - It calls `syncScoringModifiers` and `scoreSurvival`, as Cleanup's step 1 does. It reports points from `scoring.thisRound` (a reason's gains, plus the adjustment for `chaos`), and units, prizes and Emblems from the state.
4. **Tests.** They go in `round/rebuild.test.ts` and `round/preview.test.ts`, with helpers in test/fixtures/round/previews.ts.
   - Round trip: take every Plan snapshot of scripted games (seeds 1–3, `gameSetup` and `playGame`). `snapshotFor(stateFromSnapshot(s, SAMPLE_CARDS), s.seat)` equals `s`, except for every seat's `deckCount` and `resourceDeckCount`, and the other seats' `handCount` and `resourceCount`.
   - The throws: a snapshot from Cleanup, an unknown card id, a changed arena.
   - Kept Emblems: a seat that keeps Crown Shard has `pointsPerOpponentUnitKilled` 1 in the rebuilt state, and `scoring.thisRound` is empty.
   - Against a real round: take round 1 of seeds 1–3, with seat 0's scripted plan. Preview it with `maxTicks: settings.roundTicks`, and compare with `playRound(begun.state, { 0: plan })`:
     - each seat's total `points` is its `Player.points` change (`toBeCloseTo`; assert that no total clamps at 0 in these rounds);
     - `unitsLost` counts the seat's `unit.died` events;
     - `prizeHp` is 0 for exactly the prizes the round destroyed;
     - `endTick` and `ended` are `simulate.ended`'s.

     Do the same for one later round where nothing is hidden from the seat: no other seat has a face-down trap, nobody draws during Simulate, and no buff is left from an earlier round. Assert those three in the test.
   - The cap: `maxTicks: 0` stops at tick 0. A cap below the round's end stops there, with `ended` null.
   - Purity: two calls give equal previews, and the snapshot and the plan don't change.
   - `RoundPreview.parse` accepts a real preview.
5. **Perf** (`round/perf.test.ts`; `test:perf` runs it). Copy `ARMY` and `battle()` from combat/perf.test.ts. Set the battle's phase to plan, and preview it from seat 0 with an empty plan and the state's catalog:
   - Uncapped, the preview ends at the same tick, for the same reason, as `run(battle())`, in under 2 s.
   - Capped at half that end tick, it stops there with `ended` null, in under 1 s.
   - Take the busiest scripted snapshot (most units alive, seeds 1–3). Time previews of 1,000 and 3,000 ticks, and the fixed cost (`maxTicks: 0`, averaged over 20 calls). Assert the 3,000-tick preview takes under 1 s, and print all three, as ms and as ms per 1,000 ticks.
6. **Docs.**
   - Core README: `previewRound` in › Public API, round/'s row in › Module map, and a `## Previews` section (T-135's context reads it). The section says what's rebuilt, what isn't (see Notes), and the costs you measured.
   - round/index.ts's list of files gets preview.ts and rebuild.ts.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm test:soak` passes
- [ ] `pnpm --filter @chaosgrid/core test preview rebuild` passes
- [ ] `pnpm --filter @chaosgrid/core test:perf` passes, and its output shows the preview costs
- [ ] `pnpm --filter @chaosgrid/protocol test` passes
- [ ] `pnpm --filter @chaosgrid/sim-cli test golden` passes
- [ ] `git diff --exit-code main -- packages/protocol/src/version.ts` prints nothing
- [ ] `grep -c '^## Round previews' docs/PROTOCOL.md` prints 1

## Out of scope

- The planner bot, its default budget, and passing `previewRound` to bots from the web host and sim-cli (T-135).
- Previewing other seats' plans, or guessing them (D49: other seats add nothing).
- A Web Worker, or anything async. T-135 says whether planning blocks the page.
- Changing the snapshot (see Notes).

## Notes

- Default: other seats play nothing (D49). Their face-down traps are missing too, since the seat can't see them.
- Default: `maxTicks` caps Simulate. A round that ends sooner settles as a real round does, for at most `MAX_SETTLE_TICKS` more ticks. Settle is cheap, since nothing moves or attacks. So `endTick` passes `maxTicks` only in that case. With `maxTicks` at `roundTicks`, every round ends.
- Default: a capped preview scores survival as if the round had ended at its last tick.
- Default: `conceded` counts kills (`kill` and `leaderKill`) and prizes as printed, before Toxic's factor. It doesn't count banishes.
- What a preview doesn't know. The README lists these:
  - other seats' plans and face-down traps;
  - the decks, so draws draw nothing;
  - other seats' hands;
  - timed buffs from earlier rounds, such as Siege Colossus's +2 Attack (Overgrowth's and Supply Drop's draws don't matter in Simulate);
  - knobs outside `GameSettings`, which take core's defaults. The host and sim-cli use only defaults today.

  A card with a lasting effect added later needs the builder to restore it. Say so in the README.
- `previewRound` takes the seat's snapshot from `beginRound`. A `plan.checked` snapshot already has the plan applied, so the plan would apply twice.
- Default: the end reasons are copied inline, as event.ts has them. A shared schema would change event.ts.
- Default: `previewRound` doesn't parse its input. sim-cli's `--check` parses previews (T-135).
- If a preview can't work without a field the snapshot lacks, stop and send `lead` a `question` that says what and why. A payload change means `PROTOCOL_VERSION` + 1, and owning the fixtures that change with it. The default is no change, and a documented gap.
- The goldens stay as they are because a real round runs the same code: `applyRoundPlans` only gains `export`. Previews reuse round/'s steps so the two can't drift, as `checkPlan` reuses `roundPlanOptions`.
