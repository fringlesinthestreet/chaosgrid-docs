---
id: T-181
title: Bots rest for mana before they pay
milestone: M5
depends_on: []
branch: agent/T-181-bots-rest-for-mana-before-they-pay
model: sonnet
effort: medium
scope:
  - packages/bots/src/**
  - packages/bots/test/**
  - packages/bots/README.md
context:
  - docs/DECISIONS.md#Decision log
  - docs/PROTOCOL.md#Plans
  - packages/bots/README.md#The greedy bot
  - packages/bots/README.md#Adding a bot
---

# T-181 — Bots rest for mana before they pay

## Goal

D64 ends auto-pay: from T-182 on, core pays costs only with floating mana, and nothing but `restForMana` rests a resource for mana. Today the bots leave the paying to core, so every bot plan would stop paying. Before core changes, each bot rests for mana in its own plans, with the resources core would have picked, so its games stay the same.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// packages/protocol/src/plan.ts
{ action: 'restForMana', resource: CardInstanceId } // rests one unrested, unattached resource: one floating mana
// the actions that pay: castUnit, castLeader, castPermanent, castSpell, levelUp, useAbility

// packages/bots/src/pool.ts
export function payment(pool: readonly Payer[], cost: Cost): CardInstanceId[] | null; // core's planPayment, rule for rule

// packages/bots/src/draft.ts, class PlanDraft
pay(cost: Cost): boolean; // :120: payment() on the draft's copy of the pool, then setAside(paid)
// its callers: place (:177), the ability uses (:238), castCard (:294, :309), and each bot's levelUp
// (greedy-bot.ts:351, random-bot.ts:120, turtle-bot.ts:300)
finish(plan: Plan): Plan; // :266: renumbers each `spell` target to its spell's index in `plan`

// packages/bots/test/referee.ts:300
case 'restForMana':
  return say('bots never rest for mana: they leave the paying to auto-pay (D58)');
// packages/bots/src/random-bot.test.ts:92: 'uses every plan action but restForMana across the samples'
```

How core pays until T-182 (D58): a paying action spends the floating mana first, as much of it as fits, and auto-pays the rest. So a plan whose floating mana pays each cost exactly pays the same before and after T-182.

## Deliverables

1. **Every bot rests for what it pays.** Right before each paying action, the plan has one `restForMana` for each resource `payment` picked for it, lowest id first, and nothing between them and the action. `PlanDraft.pay` returns those actions, or `null` when the pool can't pay, so no bot builds them itself.
2. **The plan's order otherwise stays:** the Leader's move, then resource uses and attaches, then the spending. `finish` gets the whole plan, `restForMana` actions included, so every `spell` target still names its spell.
3. **The random bot** rests for mana only before a paying action, like the others.
4. **The referee checks D64 instead of D58.** The resources a plan rests for mana since its last paying action must pay the next one's cost: enough of them, with the colors its pips need. The referee works that out on its own, apart from `pool.ts`. A paying action without them breaks the plan, and so does a `restForMana` of a resource the pool doesn't have unrested and unattached, or one that no action spends.
5. **Tests:**
   - each bot's plan that casts, levels up and uses an ability rests exactly what pays each one, right before it;
   - the random bot's sample test expects `restForMana` among the actions it uses.
6. **The bots README:** the plan's order, `pool.ts`'s header and its Files row say the bot names the resources that pay (D64).

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/bots test` passes.
- [ ] `pnpm test:soak` passes.
- [ ] On main and on the branch, `pnpm sim --games 20 --seed 1 --bots planner,greedy,turtle,random` reports the same points, wins and rounds, since the bots rest what auto-pay rested. Both reports go in the PR.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Core's payment: T-182. Until it merges, core still auto-pays what the floating mana doesn't cover.
- Picking other resources than core's preferences pick.

## Notes

- A bot that pays two costs rests each one's resources right before it, never all of them first. Core spends floating mana greedily, so mana rested early for a later cost could pay an earlier one and strand a color.
- The planner's guesses (D63) come from `planGreedy` for each other seat, so they rest that seat's own resources by their ids, as D63 lets a guess pay.
