---
id: T-196
title: No attach in the bots
milestone: M5
depends_on: [T-193, T-205]
branch: agent/T-196-no-attach-in-the-bots
model: sonnet
effort: medium
scope:
  - packages/bots/**
  - tools/sim-cli/test/**
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Resources and mana
  - docs/PROTOCOL.md#Plans
  - packages/bots/README.md#The greedy bot
  - packages/bots/README.md#The turtle bot
---

# T-196 — No attach in the bots

## Goal

D74: resources never attach to units, and Charge goes, so a unit spends mana during Plan only on its level-ups and its Plan abilities. Core still accepts `attach` until T-200 and `charge` until T-212. After this PR the greedy, turtle and planner bots plan neither, so T-212 and T-200 can remove them. What the bots attached stays in the pool for their other spends.

## Interfaces

What exists (copied on 2026-11-05; grep the names, the lines move):

```ts
// packages/bots/src/greedy-bot.ts
// :40 "It levels up what it can, picks targets by value, and attaches what is left to …"
// :85-:116 a first pass decides the spends, `attachesAfterSpending()` (:195) the attaches from what's left,
//   `keepAttaches` (pool.ts:144) keeps each attach only if the same spends still hold without those resources,
//   and the final plan is [...opening, ...attaches, ...spends] (:215)
// :422 attach(): for each squad with room (`squad.stats.charge - squad.attached`), resources from draft.attachPool()
// packages/bots/src/turtle-bot.ts: the same shape (:44-:64, :136, :151), :351 attach() "to Blockers first, then to any squad"
// packages/bots/src/draft.ts:50-:52 Held { attached, rested }; :104 the payers skip `attachedTo !== null`;
//   :114 attachPool(); :150 setAside(); the draft rests resources for mana before each cost it pays (T-181, D64)
// packages/bots/src/pool.ts:137-:160 keepAttaches; :162 keepRests ("checked like keepAttaches")
// packages/bots/src/random-bot.ts: attach() (:200, ODDS.attach) and, since T-193, a random charge;
//   random-bot.test.ts:95 expects it to plan every PlanActionType, `attach` and `charge` included while the protocol has them
// packages/bots/src/planner-bot.ts:59-:63 its candidates are greedy plans (planGreedy), previewed with core
// packages/bots/test/referee.ts: replays a plan against the snapshot, `attach` and `charge` included
// tools/sim-cli/test/plan-abilities.soak.test.ts: 20 seeded games; counts the bots' own rests and wakes from the events
```

## Deliverables

1. **No attach planning.** `attachesAfterSpending`, `attach()`, `keepAttaches`, `attachPool` and the `attached` part of `Held` go, with the first pass that existed for them if `keepRests` doesn't need it (say which you kept). Greedy and turtle plan `[...opening, ...spends]`, and the resources they used to attach stay unrested in the pool.
2. **No charging.** No greedy, turtle or planner plan holds `charge`. The random bot keeps its random `attach` and `charge` while the protocol has them, since its test lists every `PlanActionType`: T-212 removes its charge and T-200 its attach.
3. **The planner** needs nothing of its own: its candidates are greedy's plans.
4. **Docs.** `packages/bots/README.md` (What each bot plays, the greedy and turtle sections, the odds table and Files): no bot attaches or charges, except the random bot's two actions until the protocol drops them.
5. **Tests.**
   - no greedy, turtle or planner plan holds `attach` or `charge` (a property test over the fixture snapshots);
   - the referee accepts their plans;
   - the greedy and turtle tests that pinned attaching (grep `attach` and `Charge`) go, or turn into the property above;
   - `plan-abilities.soak.test.ts` stays green.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/bots test` passes.
- [ ] `pnpm test` passes.
- [ ] `pnpm test:soak` passes.
- [ ] On main and on the branch, `pnpm sim --games 20 --seed 1 --bots planner,greedy,turtle,random` runs; both reports go in the PR.
- [ ] `grep -rn "attach" packages/bots/src --include='*.ts' | grep -v random-bot` finds only attached permanents (`mode: 'attached'`).
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Core and the protocol: T-195 runs beside you, then T-212 removes Charge and T-200 removes `attach`.
- `tools/sim-cli/src/`: T-198 edits its deck generator beside you. Its `game.ts` reads `attachedTo`, which T-200 removes.
- Reading `payable` (T-195): the bots keep their own pay logic.
- Using the Plan abilities that replace Charge (T-212): greedy scores them like any Plan ability, by cost.

## Notes

- T-205 fixes `draft.ts` first, so this task waits for it.
- Permanents attached to squads (equipment and auras, `castPermanent` with `mode: 'attached'`) are a different thing and stay.
- The golden game is scripted, not played by bots: it doesn't change here.
