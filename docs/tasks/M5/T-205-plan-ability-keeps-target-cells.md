---
id: T-205
title: A Plan ability keeps its target's cells
milestone: M5
depends_on: []
branch: agent/T-205-plan-ability-keeps-target-cells
model: sonnet
effort: medium
scope:
  - packages/bots/src/draft.ts
  - packages/bots/src/draft.test.ts
  - packages/bots/src/greedy-bot.test.ts
  - tools/sim-cli/src/command.test.ts
context:
  - packages/bots/README.md
---

# T-205 — A Plan ability keeps its target's cells

## Goal

`tools/sim-cli/test/plan-abilities.soak.test.ts` was red on main from wave 36 until T-189 changed the games: seed `abilities/1`, the greedy and turtle table, one plan rejected for `noRoom`. At 34a96b8, in round 7, the greedy bot in seat 1 used a Plan ability that revives a unit card from its discard pile at col 8, row 29 (action 12 of its plan), then cast a 2 × 2 Wanderer's Compass at col 7, row 28 (action 18), over the revived card's cell. The soak passes at 10f5485, but the bug is still there: `PlanDraft.useAbility` never reserves its target's cells, as `castSpell` and `useResource` do, so a later placement in the same plan can take them, and the next change to the games can bring the failure back on another seed. After this PR it can't, and tests pin it.

A second test on main can fail on time alone: sim-cli's "says so when it can't save the log" plays a whole default game before the save fails, and with no Durability (T-189) that game runs past the test's 60 s on a loaded machine (seed 1: 24 rounds, about 72 s, on T-189's branch). One round is enough to test the failed save.

## Interfaces

```ts
// packages/bots/src/draft.ts
castCard(card: HandCard, choices: CastChoices): PlanAction | null // :230, a footprint takes the first of choices.spots that fits the draft's grid
useResource(resource: PoolResource, aim: (spec: TargetSpec) => Target | null): PlanAction | null // :184, reserveTarget at :191
useAbility(holder: AbilityHolder, use: AbilityUse, aim: (spec: TargetSpec) => Target | null): PlanAction | null // :262-:276, reserves nothing
// castSpell, in actionFor: `if (target) reserveTarget(target, this.view);` at :340

// packages/bots/src/targets.ts:424 (tested in targets.test.ts › reserveTarget)
export function reserveTarget(target: Target, view: TargetView): void
// a `discardPileCard` target: marks the card's footprint on the seat's grid and takes it out of the pile
// a `squadToCell` target: marks the destination's cells; any other target: nothing

// packages/bots/test/referee.ts: referee(snapshot, plan) lists what core would refuse. It places a
// revive's footprint (:204) and a squadToCell move (:190) for every action with a target, useAbility included.

// tools/sim-cli/src/command.test.ts:189
it("says so when it can't save the log", () => {
  const { code, err } = sim(['--games', '1', '--log', 'missing/run.json'], { cwd: dir });
  …
}, 60_000);
```

## Deliverables

1. **The fix.** `useAbility` reserves its target as `useResource` and `castSpell` do: once it has paid, `reserveTarget(target, this.view)` when it has a target. Nothing else changes in the bots.
2. **Tests**, each failing without the fix:
   - `draft.test.ts`: after `useAbility` with a `discardPileCard` target, a `castCard` whose `spots` offers the revived card's cell first lands on the next spot; the same after a `squadToCell` target and its destination.
   - `greedy-bot.test.ts`, beside `describe('a revive')`: a squad whose Plan ability revives a unit card from the pile, and a free-standing permanent in the hand whose first spot overlaps the revive's: the plan has both actions, and `referee(snapshot, plan)` is `[]`.
3. **The log test plays one round:** add `'--rounds', '1'` to its arguments. Its expectations stay.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/bots test draft greedy` passes
- [ ] `pnpm --filter @chaosgrid/sim-cli test command` passes
- [ ] `pnpm --filter @chaosgrid/sim-cli exec vitest run test/plan-abilities.soak.test.ts` passes
- [ ] `pnpm test:soak` passes
- [ ] `git diff --stat main...HEAD` lists only files in the scope

## Out of scope

- Core's room check: it is right to refuse that plan.
- The bots' attaching (T-196) and the random bot's charge (T-212).
- The other sim-cli tests' budgets: leave them unless one fails, and then report it.
- Another soak seed or table that fails: report it in the PR, with the seed and the reason.

## Notes

- The lead replayed `abilities/1` at 34a96b8 and found the two actions above; with the one-line fix in a scratch checkout, the five soak files passed. At 10f5485 the soak passes without the fix, so only the tests in Deliverables 2 show the bug: write them first and watch them fail.
- T-192, T-193 and T-194 run beside you. T-193 edits `random-bot.ts`, `rules.test.ts` and `packages/bots/test/**` (the referee and the greedy fixture): import from them, change nothing there, and build what your tests need inline.
