---
id: T-182
title: No auto-pay in core
milestone: M5
depends_on: [T-181]
branch: agent/T-182-no-auto-pay-in-core
model: sonnet
effort: high
scope:
  - packages/core/src/**
  - packages/core/test/**
  - packages/core/README.md
  - packages/protocol/src/event.ts
  - packages/protocol/src/snapshot.ts
  - docs/PROTOCOL.md
  - tools/sim-cli/test/**
  - apps/web/src/match/planning/draft.ts
  - apps/web/src/match/planning/*.test.ts
  - apps/web/src/match/planning/*.test.tsx
  - apps/web/src/i18n/en/planning.json
  - apps/web/src/host/host.test.ts
  - apps/web/src/match/session.test.ts
  - apps/web/src/match/MatchScreen.test.tsx
context:
  - docs/RULES.md#Resources and attaching
  - docs/DECISIONS.md#Decision log
  - docs/PROTOCOL.md#Plans
  - packages/core/README.md#Tests
---

# T-182 — No auto-pay in core

## Goal

D64: costs are paid only with floating mana. Today core's `payFor` auto-pays whatever the floating mana doesn't cover, so a player who casts without resting for mana first sees resources rest by themselves (the human's playtest, 2026-11-05). After this PR, a cast, a level-up or a Plan ability that the floating mana can't pay is skipped as `unaffordable`, and nothing rests. The bots rest for mana themselves since T-181.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// packages/core/src/plan/context.ts:78
export function payFor(p: PlanCtx, seat: Seat, cost: CostInput): RejectReason | null {
  const payment = autoPayFor(p.state, seat, cost); // floating mana first, then auto-pay
  if (payment === null) return 'unaffordable';
  makePayment(p.state, payment);
  for (const id of payment.rested) emitRested(p, seat, id, 'mana');
  return null;
}
// packages/core/src/plan/abilities.ts:69, a Plan ability's check, which a snapshot's `usable` reads:
return canPay(state, seat, abilityCostFor(state, seat, cardOf(state, card), index)) ? null : 'unaffordable';

// packages/core/src/zones/pay.ts, internal to core (zones/ isn't in its public entry)
planPayment(payers: readonly Payer[], cost: CostInput): CardInstanceId[] | null; // the rules at its top
interface AutoPay { /* the floating mana spent, and the resources auto-pay rests */ }
planAutoPay(floating: readonly Payer[], available: readonly Payer[], cost: CostInput): AutoPay | null;
autoPayFor(state, seat, cost): AutoPay | null; // planAutoPay with the seat's floating and available resources
choosePayment(state, seat, cost); canPay(state, seat, cost); makePayment(state, payment); pay(state, seat, cost)
// the file's header (:17) and zones/state.ts:35 describe auto-pay

// apps/web/src/match/planning/draft.ts
REJECT_TEXT.unaffordable: "Can't afford it"
// apps/web/src/i18n/en/planning.json
"mana.hint": "Casting spends floating mana first, then rests what else it needs."
```

Auto-pay is also in the protocol's comments (event.ts:195, `ResourceRestReason`'s `mana`; snapshot.ts:230, `floating`) and in PROTOCOL.md: › Plans' "Paying (D58)", the `ResourceRestedEvent` row and the `unaffordable` row.

## Deliverables

1. **Core pays with floating mana only.** `payFor` spends the seat's floating mana as `planPayment` matches it to the pips, and rests nothing. When the floating mana can't pay the whole cost, the action is skipped as `unaffordable` and nothing changes, so the mana keeps floating. Code that only auto-pay used goes, with its comments.
2. **`usable` keeps its meaning (D64):** an ability is usable when the floating mana and the resources the seat could rest pay it together, so a bot can plan the ability and rest for it.
3. **Every plan that relied on auto-pay rests for mana:** core's tests and fixtures, sim-cli's golden script, and the web tests in the scope.
   - A test about paying names its `restForMana` actions. Other tests may use one shared helper that rests what a cost needs.
   - The golden game's event streams should come out the same, since the same resources rest. If they don't, regenerate them and say why in the PR.
4. **Tests in core:**
   - a cast with no floating mana is skipped as `unaffordable` and rests nothing;
   - a cast with too little floating mana is skipped, and its mana keeps floating;
   - a level-up and a Plan ability the same;
   - a cast after enough `restForMana` spends that mana and rests nothing more;
   - an ability the seat could rest for is `usable`.
5. **Docs and text say D64:**
   - PROTOCOL.md's Paying note and its `ResourceRestedEvent` and `unaffordable` rows;
   - the protocol's comments, the core README and the `zones/` comments;
   - the web's `unaffordable` text: "Not enough mana: rest resources first";
   - the floating mana hint: casting, leveling and abilities spend only floating mana.

   No version bump: no payload changes.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm test` passes.
- [ ] `pnpm test:soak` passes.
- [ ] On main and on the branch, `pnpm sim --games 20 --seed 1 --bots planner,greedy,turtle,random` reports the same, since the bots rest for mana themselves since T-181. Both reports go in the PR.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The bots, which rest for mana since T-181.
- Dimming the cards the floating mana can't pay: PLAN.md › M5 lists it among the planning aids to card later.
- A one-click cast that rests for the player: D64's "Revisit when" leaves that to a client.

## Notes

- `restForMana` and its `resource.rested` event don't change: resting for mana is now the only way a resource gives mana.
- Of the web tests, only `host.test.ts` and `session.test.ts` run core, through the host. The planning tests and `MatchScreen.test.tsx` are in the scope for the new texts, where they check them.
