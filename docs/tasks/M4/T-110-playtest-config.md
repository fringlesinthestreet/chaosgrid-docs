---
id: T-110
title: Playtest clocks, target and round end
milestone: M4
depends_on: []
branch: agent/T-110-playtest-config
model: opus
effort: medium
scope:
  - packages/protocol/src/snapshot.ts
  - packages/protocol/src/version.ts
  - packages/protocol/src/*.test.ts
  - packages/protocol/test/fixtures/**
  - packages/protocol/README.md
  - docs/PROTOCOL.md
  - packages/core/src/state/config.ts
  - packages/core/src/view/snapshot.ts
  - packages/core/src/combat/**
  - packages/core/src/**/*.test.ts
  - packages/core/test/**
  - packages/core/README.md
  - packages/bots/test/**
  - tools/sim-cli/src/**
  - tools/sim-cli/test/**
  - tools/sim-cli/README.md
  - apps/web/src/host/host.ts
  - apps/web/src/host/host.test.ts
  - apps/web/src/lobby/**
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/src/match/model/*.test.ts
  - apps/web/src/replay/parseLog.test.ts
  - apps/web/test/fixtures/logs/**
  - apps/web/test/fixtures/planning/**
  - apps/web/e2e/m4.spec.ts
context:
  - docs/RULES.md#Round structure
  - docs/RULES.md#Balance knobs
---

# T-110 — Playtest clocks, target and round end

## Goal

The human's first playtest (2026-10-29) changed four numbers and one rule. After this PR:

- games go to 100 points, and tests play to 30;
- Simulate runs for up to 180 seconds;
- `GameSettings` carries the Plan clock, the Chaos pause and the Discard clock (D41), and the solo host turns the Plan and Discard clocks off (9999 s);
- a lone survivor's round goes on while another seat's prize or an Emblem still stands, so the survivor can score it (D44, superseding D25).

Nothing reads the clocks yet: T-113 shows them, and T-116 runs the Discard clock.

## Interfaces

What exists (copied from the code on 2026-10-29):

```ts
// packages/core/src/state/config.ts:9-58, GameConfigSchema (count = z.int().nonnegative(), positive = z.int().positive())
pointTarget: positive.default(30),      // → 100
/** Simulate's timer, in ticks: 100 seconds. */
roundTicks: positive.default(10_000),   // → 18_000, "180 seconds"
handLimit: count.default(8),

// packages/protocol/src/snapshot.ts:44-55
export const GameSettings = z.strictObject({ pointTarget: z.int().min(1), handLimit: Count, maxLevel: Level, roundTicks: z.int().min(1) });
// packages/protocol/src/version.ts:6
export const PROTOCOL_VERSION = 24; // → 25
// packages/core/src/view/snapshot.ts:35-38
export function settingsOf(state: GameState): GameSettings {
  const { pointTarget, handLimit, maxLevel, roundTicks } = state.config;
  return { pointTarget, handLimit, maxLevel, roundTicks };
}

// packages/core/src/combat/end.ts:24-40, endReason: after the timer and the On death wait,
//   seats = the seats with a living unit, chaos = a Chaos unit is alive:
  if (!chaos) return seats.size <= 1 ? 'lastStanding' : null;
  if (seats.size > 0) return null;
  // chaosWon unless a non-Chaos, non-prize permanent isTargetable
// isPrize (state/lookup.ts:73) is kind === 'prize'. An Emblem is a permanent of kind 'emblem'
//   (PermanentKind, state/state.ts:143), owner CHAOS (chaos/spawn.ts:87). isTargetable
//   (targeting/attackable.ts) means alive, free-standing and face up. Targeting already sends a
//   unit at prizes like any permanent, and at Emblems when nothing else is in range (targeting/choose.ts:146-152).
// combat/prize.test.ts:55 "a lone unit wins the round, whatever prizes stand" pins the old rule.

// apps/web/src/host/host.ts:104-113, the GameSetup it passes to newGame (:115):
  ...(setup.pointTarget === undefined ? {} : { config: { pointTarget: setup.pointTarget } }),
// apps/web/src/lobby/lobby.ts:36-37 (choiceProblems at :65-73 checks the range)
export const POINT_TARGET_MIN = 5; export const POINT_TARGET_MAX = 100; // → 200

// tools/sim-cli/src/game.ts:27-45 GameOptions { seed, cards, bots, decks, maxRounds, check?, onEvents? };
//   :104-107 the setup is { seed, seats } with no config. command.ts: USAGE :18-31, SimOptions :33-42,
//   DEFAULTS :44-52, parseSimArgs :65, runGame :155, simCommand :203.
// The soaks: done-when.soak.test.ts:15 simCommand(['--games','100','--seed','1','--check'], …);
//   plan-abilities, settle and m3-done-when build options from {...DEFAULTS, …} and call runGame
//   (m3-done-when also playMatchup, :112-117).
```

What this task adds:

```ts
// GameConfigSchema, after roundTicks:
/** Plan's clock in seconds (D41). Core never counts it: the client runs it, and the M6 server enforces it. */
planSeconds: positive.default(120),
/** The Chaos pause before Plan's clock starts, in seconds (D41). 0: no pause. */
revealSeconds: count.default(10),
/** The Discard step's clock in seconds (D41, D42). */
discardSeconds: positive.default(30),

// GameSettings gains planSeconds: z.int().min(1), revealSeconds: Count, discardSeconds: z.int().min(1);
//   settingsOf copies them from the config.

// tools/sim-cli: GameOptions.pointTarget?: number (core's default when left out), passed as
//   config: { pointTarget }; SimOptions.target: number | null and the flag `--target N`
//   (USAGE: "point target [core's default, 100]").

// apps/web/src/host/host.ts
/** Offline nobody waits on the player: Plan and the Discard step have no limit in practice (D41). */
const SOLO_CLOCKS = { planSeconds: 9999, discardSeconds: 9999 } satisfies GameConfigInput;
// config: { ...SOLO_CLOCKS, pointTarget } (pointTarget only when the setup has one)
```

## Deliverables

1. **The knobs.** The three clocks, `pointTarget` 100 and `roundTicks` 18,000 in `GameConfigSchema`, `GameSettings` and `settingsOf`. `PROTOCOL_VERSION` 25. docs/PROTOCOL.md › GameSettings lists the new fields, and its title says version 25. Update any README that lists the knobs.
2. **The round end (D44).** In `endReason`, when no Chaos unit is alive and exactly one seat has living units, return null while another seat's prize or any Emblem `isTargetable`. With no seat alive, `lastStanding` comes at once, as today. Update the doc comment. Rewrite the test at prize.test.ts:55 to the new rule (it's the rule changing, not a test loosened), and add tests:
   - a lone unit walks to an opponent's prize and destroys it, its owner scores `prizePoints`, and the round ends `lastStanding` after that;
   - a standing Emblem keeps a lone survivor's round going until it breaks;
   - a lone survivor that can't reach anything (a static unit) runs to `timeUp`;
   - nobody alive and no Chaos: `lastStanding` at once;
   - `chaosWon` doesn't change: a prize still doesn't keep Chaos's round going.
3. **The solo clocks.** The host passes `SOLO_CLOCKS` to `newGame`. A host test reads `game.started`'s settings: `planSeconds` 9999, `discardSeconds` 9999, `revealSeconds` 10, `pointTarget` 100 without a setup target.
4. **Tests play to 30.** Every sim-cli test that plays games to the end, the soaks and the smoke test, passes `--target 30` or `pointTarget: 30`. `m4.spec.ts` opens "More options" and fills "Point target" with 30, so its "Target 30" and final-score checks stand.
5. **Tests that read the defaults.** Move them to the new values:
   - core: config.test.ts's `DEFAULT_CONFIG` literal; round.test.ts:39-44's settings; end.test.ts:55-63's `timeUp` at `secondsToTicks(180)`; the perf test (Notes);
   - web: host.test.ts:421's 30 becomes 100; MatchScreen.test.tsx:126's "Target 30" becomes "Target 100"; model/apply.test.ts:26's settings literal;
   - the hand-written settings in bots' test/fixtures (snapshots.ts:18, turtle.ts:141) and in packages/protocol/test/fixtures/samples.ts:16-19;
   - the settings in apps/web/test/fixtures/logs/*.json (`game.started`) and planning/*.json (`settings`), with the values core gives.
   - Regenerate the sim-cli goldens (golden.test.ts says how). Every diff in them must come from the new settings or the new round end: say which in your handoff.
6. **The lobby.** `POINT_TARGET_MAX` is 200, and the lobby test that checks the range moves with it.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm test:soak` and `pnpm test:perf` pass
- [ ] `pnpm --filter @chaosgrid/core test -- prize end` passes
- [ ] `pnpm sim --games 2 --target 30` finishes and prints its table
- [ ] `grep -c -E "secondsToTicks\(100\)" packages/core/src/combat/end.test.ts` prints 0
- [ ] `grep -c -E "planSeconds: 9999" apps/web/src/host/host.ts` prints 1
- [ ] `pnpm test:e2e` passes

## Out of scope

- Showing the clocks, the Chaos pause and the round clock in seconds (T-113).
- The Discard step (T-112). `handLimit` doesn't change.
- Lobby fields for the clocks: the solo host sets them, and only the point target is the player's.
- Balancing the new numbers (M5).

## Notes

- Default: `revealSeconds` may be 0 (no pause); the Plan and Discard clocks are at least 1 second.
- A prize or an Emblem stands while it `isTargetable`: a destroyed prize stays down until Cleanup. An opponent's artifacts, enchantments and revealed traps don't keep the round going, since they score nothing.
- The On death wait still comes before the new check, and the timer still ends the round whatever stands.
- The perf test "nobody dies" (combat/perf.test.ts:88-102) fights to the timer, so at 180 s it runs 1.8 times the ticks. Keep its budget (D31). If it passes, move its numbers to 180 s. If it fails, give that test `config: { roundTicks: secondsToTicks(100) }` so it measures what it did, and put both times in your handoff: lead decides.
- sim-cli's `--target` defaults to core's 100 so that a balance report plays real games. The soaks are tests and play to 30.
- A soak threshold measured at 30 points (m3-done-when's no-winner ratio, D33's greedy check) can move with the new round end. If one fails, report the numbers; don't loosen it.
