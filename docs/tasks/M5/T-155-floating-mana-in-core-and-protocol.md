---
id: T-155
title: Floating mana in core and protocol
milestone: M5
depends_on: []
branch: agent/T-155-floating-mana-in-core-and-protocol
model: opus
effort: high
scope:
  - packages/protocol/src/**
  - packages/protocol/README.md
  - packages/core/src/**
  - docs/PROTOCOL.md
  - packages/bots/src/rules.test.ts
  - tools/sim-cli/test/scripted.ts
  - apps/web/src/match/model/apply.ts
  - apps/web/src/match/planning/index.tsx
  - apps/web/src/match/planning/draft.ts
  - apps/web/src/match/overlays/log.ts
  - apps/web/test/fixtures/**
  - packages/protocol/test/fixtures/**
context:
  - docs/RULES.md#Resources and attaching
  - docs/RULES.md#Round structure
  - docs/PROTOCOL.md#Plans
  - docs/PROTOCOL.md#Visibility
  - docs/PROTOCOL.md#Versioning
---

# T-155 — Floating mana in core and protocol

## Goal

Today core picks the resources that pay every cost, and a player can't choose which resources pay for which card. The human asked for Magic's mana pool (2026-11-04), and D58 sets the rule: a player rests resources for mana, the mana floats, and casting, leveling and Plan abilities spend it. When the floating mana can't pay a whole cost, core rests more resources for mana by today's preferences (auto-pay), so every plan written before still pays as it did.

This task is the shared contract (planning rule 2): the protocol's new action, field and event, at version 28, and core's rules. T-158 builds the planning UI on it, and T-157 then makes the pools public.

## Interfaces

D58, as the code repo's DECISIONS.md has it: "Costs are paid with floating mana. The plan action `restForMana` rests one unrested, unattached resource and adds one mana that pays what the resource gives. Casting, leveling and Plan abilities spend floating mana. When it can't pay the whole cost, core rests more resources for mana by `planPayment`'s preferences and spends that mana too (auto-pay), so a plan without `restForMana` pays as it did before. Floating mana lasts until the plans lock; what's left then is lost. A resource rested for its Rest ability gives no mana. This replaces PROTOCOL.md's 'Paying is automatic'."

What exists (copied on 2026-11-04):

```ts
// packages/core/src/zones/pay.ts: every cost goes through pay() and canPay()
export interface Payer { id: CardInstanceId; gives: ResourceCard['gives']; hasRest: boolean }
export function planPayment(payers: readonly Payer[], cost: CostInput): CardInstanceId[] | null;
export function choosePayment(state: GameState, seat: Seat, cost: CostInput): CardInstanceId[] | null;
export function canPay(state: GameState, seat: Seat, cost: CostInput): boolean;
/** Pays `cost` from the seat's available resources and rests the ones that paid. */
export function pay(state: GameState, seat: Seat, cost: CostInput): Outcome<{ paid: CardInstanceId[] }>;
// Callers: plan/squads.ts:128 and :155 (castUnit, castLeader), plan/permanents.ts:56,
// plan/spells.ts:140, plan/level.ts:51, plan/abilities.ts:69 (canPay: `usable`) and :113.

// packages/core/src/zones/state.ts
export interface ResourceStatus {
  rested: boolean;                 // it paid a cost or used its ability, or arrived rested
  attachedTo: SquadId | null;
  spent: boolean;                  // an ability spent it: at Cleanup it goes to the bottom of the deck
}
// ZonesState.resources: Record<CardInstanceId, ResourceStatus>; no entry = unrested, unattached

// packages/core/src/zones/resources.ts
export function restResource(state: GameState, id: CardInstanceId): void;
export function useResource(state: GameState, seat: Seat, id: CardInstanceId): Outcome; // the plan action
export function availableResources(state: GameState, seat: Seat): CardInstanceId[];      // unrested, unattached

// packages/core/src/round/play.ts: applyRoundPlans(ctx, plans) hides, applies every plan, reveals.
// packages/core/src/round/check.ts: checkPlan(state, seat, plan), the dry run behind plan.checked.

// packages/protocol/src/plan.ts
export const UseResourceAction = z.strictObject({ action: z.literal('useResource'), resource: CardInstanceId, target: …, copyTarget: … });
export const PlanActionType = z.enum(['castUnit', 'castLeader', 'moveLeader', 'levelUp', 'attach',
  'castPermanent', 'castSpell', 'useResource', 'useAbility']);

// packages/protocol/src/snapshot.ts: PoolResource { card, cardId, gives, rested, attachedTo, spell, target? }
// AbilityUse.usable: unused this round, payable, and the squad can rest if the ability rests it.

// packages/protocol/src/event.ts: ResourceDrawnEvent { type: 'resource.drawn', seat, card, cardId, rested }
// RejectReason 'unaffordable': "The unrested resources can't pay the cost."
// packages/protocol/src/visibility.ts: isVisibleTo(event, seat), no default case.
// packages/protocol/src/version.ts: PROTOCOL_VERSION = 27
```

Every exhaustive switch over plan actions: core's `effects/rules.ts`, the web's `match/planning/index.tsx` and `match/planning/draft.ts`, the bots' `rules.test.ts` and sim-cli's `test/scripted.ts`. Over events: the web's `match/model/apply.ts` and the protocol's `visibility.ts`. Three JSON fixtures pin the version: `apps/web/test/fixtures/planning/snapshot*.json`.

## Deliverables

1. **The action.** `RestForManaAction`, `{ action: 'restForMana', resource }`, in the `PlanAction` union and `PlanActionType`. It rests one resource of the seat's pool for mana. `unavailable` when the resource isn't in the pool, or is rested or attached; `wrongPhase` outside Plan, as for every action. A resource with a Rest ability may be rested for mana instead; then its ability can't be used this round.
2. **Floating mana in core.** A resource rested for mana floats until its mana is spent; one resource makes one mana, which pays one pip the resource could pay (`gives`). Default: a `floating: boolean` on `ResourceStatus`. `pay` and `canPay` pay from the floating mana first. When it can't pay the whole cost, `pay` rests as few unrested, unattached resources as it needs, by `planPayment`'s preferences among them, and spends their mana too (auto-pay). The resources that paid stop floating and stay rested. `canPay` answers for floating plus available resources together, so `AbilityUse.usable` and the cast checks count both.
3. **The end of the plan.** Floating mana is lost when the plans lock: once `applyRoundPlans` has applied every plan, no resource floats; the resources stay rested until Cleanup. `checkPlan`'s snapshot still shows what floats, since that plan hasn't locked.
4. **The protocol.** `PoolResource.floating: boolean`: rested for mana and its mana not spent yet. `ResourceRestedEvent`, `{ type: 'resource.rested', seat, card, cardId, reason }` with `reason` a new `ResourceRestReason`, `'mana' | 'ability'`. Core emits it for `restForMana` and for each resource auto-pay rests (`'mana'`), and for `useResource` (`'ability'`). Its visibility is its seat only, since pools are still hidden: T-157 makes it public. `RejectReason.unaffordable` reads "The floating mana and the unrested resources together can't pay the cost." `PROTOCOL_VERSION` becomes 28.
5. **Everyone else compiles.** Each exhaustive switch above gets the new action or event, with no new behavior. The web's plan list names the action ("Rest {name} for mana" through the planning file's existing text pattern, or the card's name alone if that's how the list names actions). The three JSON fixtures get the version and `floating: false`.
6. **Docs:** `docs/PROTOCOL.md` › Plans: "Paying is automatic" becomes "Paying (D58)", which says what deliverables 2 and 3 say. The action table gets a `RestForManaAction` row; `PoolResource` gets `floating`; Planning events get `ResourceRestedEvent`; Visibility gets its row; Versioning gets row 28. `packages/protocol/README.md` if it lists the actions or events.
7. **Tests:**
   - protocol: the action, the field and the event parse; `isVisibleTo` shows `resource.rested` to its seat only; the docs test passes.
   - core: `restForMana` rests and floats, and emits `resource.rested` (`'mana'`); a rested, an attached or an unknown resource is `unavailable`; a cast pays from floating mana first and leaves the rest floating; a cast with too little floating mana auto-rests the preferred resources, each with an event; a plan with no `restForMana` rests exactly what it rested before (the existing payment tests pass unchanged); `usable` counts floating mana; `useResource` emits `'ability'`; after `playRound` no resource floats and the rested stay rested; `checkPlan`'s snapshot shows `floating`.
   - The soaks: bots never rest for mana, so their games are unchanged (`pnpm test:soak`).

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/protocol test`, `pnpm --filter @chaosgrid/core test`, `pnpm --filter @chaosgrid/bots test` and `pnpm --filter @chaosgrid/web test` pass.
- [ ] `pnpm test:soak` passes.
- [ ] `pnpm test:e2e` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The planning UI's rest-for-mana controls and the floating mana display: T-158.
- Public pools, `resource.played`, attach events: T-157.
- Bots that rest for mana by choice: they keep auto-pay.
- An undo for a rest (D37 has none).

## Notes

- Defaults: auto-pay spends every floating mana that fits before it rests anything. Among plans of equal size it keeps `planPayment`'s order (single-color before multi-color, Prism last, resources without a Rest ability first, lowest id). A floating mana that no pip can use stays floating.
- A resource that arrives rested (Underwater Volcano) doesn't float.
- Put the auto-pay choice in one function next to `planPayment`, so the bots' copy in `packages/bots/src/pool.ts` can follow it later; the bots don't change here.
- `apps/web/src/match/overlays/log.ts` is in the scope only in case its switch needs the event to compile.
