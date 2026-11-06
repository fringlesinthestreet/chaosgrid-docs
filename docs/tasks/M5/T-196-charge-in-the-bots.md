---
id: T-196
title: Charge in the bots
milestone: M5
depends_on: [T-193]
branch: agent/T-196-charge-in-the-bots
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

# T-196 — Charge in the bots

## Goal

D68: a unit charges when its owner pays its Charge in generic mana during Plan; resources no longer attach. Core takes `{ action: 'charge', squad }` since T-193 and still accepts `attach` until T-200. After this PR the greedy, turtle and planner bots charge their squads with the mana their spends leave, and plan no `attach`, so T-200 can remove it.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// packages/protocol (T-193): { action: 'charge', squad: SquadId } pays the squad's `stats.charge` in generic floating
// mana, once a round; `unavailable` at Charge 0 or when charged already, `unaffordable` without the floating mana.
// SquadSnapshot.charged?: boolean (optional until T-200: read it as `squad.charged === true`).

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
//   random-bot.test.ts:95 expects it to plan every PlanActionType, `attach` included while the protocol has it
// packages/bots/src/planner-bot.ts:59-:63 its candidates are greedy plans (planGreedy), previewed with core
// packages/bots/test/referee.ts: replays a plan against the snapshot (T-193 taught it `charge`)
// tools/sim-cli/test/plan-abilities.soak.test.ts: 20 seeded games; counts the bots' own rests and wakes from the events
```

## Deliverables

1. **Charging, not attaching.** Greedy and turtle charge after their spends: each squad with Charge N > 0 that isn't charged gets `{ action: 'charge', squad }` when the resources the plan hasn't used can pay N generic mana. The draft pays it like any other cost: it rests resources for mana first, then the charge. Greedy charges by value (its Leader, then its highest level, then the most units); turtle charges its Blockers first, then the rest, as it attached before.
2. **No attach planning.** `attachesAfterSpending`, `attach()`, `keepAttaches`, `attachPool` and the `attached` part of `Held` go, with the first pass that existed for them if `keepRests` doesn't need it (say which you kept). The random bot keeps its random `attach` until the protocol drops it (its test lists every action type), and keeps its random charge.
3. **The planner** needs nothing of its own: its candidates are greedy's plans. Check that its previews see the charges (core's rebuild reads `charged`).
4. **Docs.** `packages/bots/README.md` (the greedy and turtle sections, What each bot plays, Files) says charge where it said attach.
5. **Tests.**
   - greedy charges a Charge-2 squad when two resources are left after its spends, and doesn't when one is;
   - turtle charges a Blocker before another squad;
   - no greedy, turtle or planner plan holds `attach` (a property test over the fixture snapshots);
   - the referee accepts their plans;
   - `plan-abilities.soak.test.ts` counts `squad.charged` events and expects the greedy and turtle table to charge at least once in its 20 games.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/bots test` passes.
- [ ] `pnpm test` passes.
- [ ] `pnpm test:soak` passes.
- [ ] On main and on the branch, `pnpm sim --games 20 --seed 1 --bots planner,greedy,turtle,random` runs; both reports go in the PR.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Core and the protocol: T-193 and T-195 (T-195 runs beside you).
- `tools/sim-cli/src/`: T-198 edits its deck generator beside you. Its `game.ts` reads `attachedTo`, which T-200 removes.
- Reading `payable` (T-195): the bots keep their own pay logic.

## Notes

- Since T-193 every card with Charge has an "If charged" ability, so a charge always switches something on. Lead default: a bot charges whenever it can pay, in the order above; if the soak shows charging starves its casts, say so in the PR instead of tuning.
- The golden game is scripted, not played by bots: it doesn't change here.
