---
id: T-193
title: Charge as a Plan ability in core
milestone: M5
depends_on: [T-189, T-190]
branch: agent/T-193-charge-as-a-plan-ability-in-core
model: opus
effort: high
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/core/**
  - packages/cards/src/dsl.ts
  - packages/cards/src/dsl.test.ts
  - packages/cards/src/schema.ts
  - packages/cards/src/schema.test.ts
  - packages/cards/data/**
  - packages/cards/README.md
  - packages/bots/src/random-bot.ts
  - packages/bots/src/random-bot.test.ts
  - packages/bots/src/rules.test.ts
  - packages/bots/test/**
  - tools/sim-cli/test/**
  - apps/web/src/match/model/apply.ts
  - apps/web/src/match/model/apply.test.ts
  - apps/web/src/match/model/types.ts
  - apps/web/src/match/overlays/log.ts
  - apps/web/src/match/overlays/log.test.ts
  - apps/web/src/match/planning/index.tsx
  - apps/web/src/match/planning/draft.ts
  - apps/web/src/match/planning/draft.test.ts
  - apps/web/src/match/planning/targets.test.ts
  - apps/web/src/i18n/en/overlays.json
context:
  - docs/RULES.md#Resources and mana
  - docs/RULES.md#Round structure
  - docs/DECISIONS.md#Decision log
  - docs/CORE.md#Defaults for open rules questions
  - docs/PROTOCOL.md#Plans
  - docs/PROTOCOL.md#Versioning
---

# T-193 — Charge as a Plan ability in core

## Goal

D68: a unit that prints Charge N charges when its owner pays N generic mana during Plan, once a round, and stays charged until Cleanup. After this PR core takes a `charge` plan action, emits `squad.charged` and reports `charged` in the squad's snapshot, and a charge draws Jaksho's extra resource at once. `attach` keeps working beside it, because the bots and the web still send it until the next wave; T-200 removes it. Overclock loses its attached-resource clause.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// packages/protocol/src/plan.ts
export const AttachAction = z.strictObject({ action: z.literal('attach'), squad: SquadId, resources: idList(CardInstanceId) }); // :44
export const PlanAction = z.discriminatedUnion('action', [CastUnitAction, …, AttachAction, …, RestForManaAction]); // :140
export const PlanActionType = z.enum(['castUnit', …, 'attach', …, 'restForMana']); // :155
// packages/protocol/src/event.ts:160-:167 ResourcesAttachedEvent { type: 'resources.attached', seat, squad, resources }
// packages/protocol/src/visibility.ts:21 switch (event.type) without a default: :53 'resources.attached', :54 'resources.detached'
// packages/protocol/src/snapshot.ts:252-:270 SquadSnapshot: …, level, durability, unlocked,
//   /** Resources attached this round. */ attached: Count, rested, uses
// The squad's Charge is `stats.charge` (card.ts:93), in every SquadSnapshot and unit HandCard.

// packages/core/src/plan/apply.ts
const attach: Step<AttachAction> = (p, seat, action) => { … }  // :40: illegalTarget, forbidden, then zones/ attachResources
const STEPS: { [A in PlanAction['action']]: Step<Extract<PlanAction, { action: A }>> } = { … } // :67
// packages/core/src/plan/level.ts:42-:52 the pattern for a paid step: ownSquad → 'illegalTarget', isForbidden → 'forbidden',
//   then `const unpaid = payFor(p, seat, cost); if (unpaid !== null) return unpaid;` (plan/context.ts:78, D64: floating mana only)
// packages/core/src/plan/context.ts:19 after a step, effects/ settlePlanDraws (effects/draws.ts:59) draws what a raised
//   `resourceDraw` adds: "an `attach` that charges Jaksho draws its extra resource at once" (CORE.md › Draws during Plan)
// packages/core/src/effects/sources.ts:216-:224
/** "If charged" (RULES.md › Attaching): the squad's attached resources reach its Charge. Chaos squads … never charged. */
export function isCharged(state: GameState, squad: Squad): boolean {
  const card = squadCard(state, squad);
  if (card.type === 'chaos') return false;
  return squad.attached.length >= card.stats.charge;
}
// packages/core/src/effects/rules.ts:81 switch (action.action), :98 case 'attach' (no rule forbids it)
// packages/core/src/zones/resources.ts:200 cleanupResources: at Cleanup every squad ends with nothing attached
// packages/core/src/view/board.ts:62 `attached: squad.attached.length`; round/rebuild.ts rebuilds squads from a snapshot

// packages/cards/data/spells/overclock.json (version 1, cost "3RT"): a `buff` (attackSpeed × 2, round) on chosenOwnUnit,
//   then { "effect": "spendAttachedResources", "target": "chosenOwnUnit", "delay": "cleanup" }
// packages/cards/src/dsl.ts:373 effect('spendAttachedResources', …): Overclock is its only card;
//   packages/core/src/effects/handlers/spendAttachedResources.ts; packages/core/test/fixtures/view/games.ts uses it
// Charge without an "If charged" ability: 18 cards print Charge above 0 and no ability with `"condition": "charged"`,
// so charging them would pay mana for nothing. The only "If charged" cards are Harpoon Diver and 12 Leaders.

// Exhaustive switches outside core that a new action or event breaks (ESLint switch-exhaustiveness-check):
// apps/web/src/match/model/apply.ts:88 (default :543 `const unhandled: never = event`); :492 'resources.attached' logs it
// apps/web/src/match/model/types.ts:186 the logged event types; apps/web/src/match/overlays/log.ts:128 and :313
//   (texts in en/overlays.json, "log.resourcesAttached": "{seat} attached {count, …} to {squad}")
// apps/web/src/match/planning/draft.ts:125 describeAction (English, :134 'attach'); planning/index.tsx:88 actionCard
// apps/web/src/match/planning/targets.test.ts:216 a Record over every PlanActionType
// packages/bots/src/random-bot.test.ts:95 expects the random bot to plan every PlanActionType;
//   random-bot.ts:200 attach() (ODDS.attach :35); packages/bots/test/referee.ts:224, src/rules.test.ts:64 and
//   test/fixtures/greedy.ts:181 switch (action.action); tools/sim-cli/test/scripted.ts:174 the same
```

## Deliverables

1. **The protocol.** A `ChargeAction` `{ action: 'charge', squad: SquadId }` in `PlanAction` and `PlanActionType`. A `SquadChargedEvent` `{ type: 'squad.charged', seat, squad }`, public as `resources.attached` is, in the event union, the index's exports and `visibility.ts`. `SquadSnapshot.charged: z.boolean().optional()`: true once the squad is charged this round, false for a card with Charge 0. It stays optional so the bots' and the web's snapshot literals parse; a later task makes it required. Bump `PROTOCOL_VERSION` (33, after T-189's 32), with docs/PROTOCOL.md's title, its Plans and Planning tables, its `SquadSnapshot` section and a Versioning row. Add a `squad.charged` sample to `test/fixtures/samples.ts`.
2. **The `charge` step.** In `plan/apply.ts`, like `levelUp`: `illegalTarget` when the squad isn't the seat's on its grid (a Leader in the command zone included), `forbidden`, `unavailable` when its card's Charge is 0 or it's charged already, then `payFor` the Charge as that many generic mana (D64: floating mana only), else `unaffordable`. It sets the new `Squad.charged`, emits `squad.charged`, and settles the plan draws as an attach does, so a charged Jaksho's extra resource can be rested later in the same plan. Charging doesn't rest the squad. `effects/rules.ts` gets its case (no rule forbids a charge).
3. **Charged.** `isCharged` is true when `squad.charged`, or, until `attach` goes, when the attached resources reach the Charge as today. Cleanup clears `charged` where it clears `attached`. The snapshot's `charged` is `isCharged` for a card with Charge above 0; `round/rebuild.ts` reads it back (`charged ?? false`), so the bots' previews see the charge.
4. **Overclock.** Cost `4RT`, its text "One unit you control attacks twice as often this round", only the buff ability, version 2 (RULES.md's sample row says so already). `spendAttachedResources` leaves the DSL, core's registry and the cards README, with its handler and its test fixture.
5. **Charge only where it switches something on.** The 18 cards in the Notes get Charge 0, with `version` + 1. The card schema refuses a unit or Leader whose Charge and abilities disagree: "Charge above 0 needs an If charged ability, and an If charged ability needs Charge (D68)". RULES.md's sample rows say Charge 0 already.
6. **The switches outside core.** Each gets the new case and nothing more:
   - the web model logs `squad.charged` and stores nothing (the next wave's web card adds `SquadModel.charged`);
   - the round log reads "{seat} charged {squad}" (`overlays.log.squadCharged`);
   - `describeAction` reads "Charge {squad}", and `actionCard` returns the squad's card;
   - `targets.test.ts` gets a `charge` row;
   - the bots' referee checks a charge (the seat's squad, Charge above 0, not charged, floating mana pays it), `rules.test.ts` and the greedy fixture get their cases;
   - the random bot sometimes charges a squad with Charge (an `ODDS.charge`, beside `attach`), so its test still sees every action type;
   - `scripted.ts` passes a charge through.
7. **Tests in core:**
   - a charge pays N generic floating mana and sets `charged`;
   - Charge 0 and a second charge are `unavailable`; another seat's squad is `illegalTarget`; too little floating mana is `unaffordable` and pays nothing;
   - a charged squad's "If charged" ability works in Simulate, and the charge is gone after Cleanup;
   - charging Jaksho draws one resource at once, and a later `restForMana` in the same plan can rest it;
   - `attach` still charges, as before;
   - the snapshot's `charged` before and after a charge, false at Charge 0;
   - the protocol's plan and event tests for the new shapes.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/core test plan resources view` passes.
- [ ] `pnpm --filter @chaosgrid/protocol test` passes.
- [ ] `pnpm cards:validate` passes.
- [ ] `pnpm test` passes.
- [ ] `pnpm test:soak` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The bots charging on purpose (greedy, turtle, planner, the draft): T-196.
- The web's Charge button, its glow and `SquadModel.charged`: T-197.
- `payable`: T-195.
- Removing `attach`, `attachedTo`, `SquadSnapshot.attached` and the `resources.*` events: T-200.

## Notes

- Lead default: a rested squad can be charged; resting doesn't stop its "If charged" statics (Jaksho's draw), and the UI decides whether to offer it.
- Lead default: no cost change applies to a charge (`levelUpCostFor` is for level-ups only).
- Lead default: the 18 cards whose Charge switches nothing on lose it rather than gain an ability; the balance pass can give them "If charged" abilities later. They are Abyssal Warden, Current Mage, Deepwater Leviathan, Ember Titan, Flame Lancer, Furnace Brute, Inferno Cannon, Maelstrom Kraken, Magma Catapult, Magma Lancer, Phoenix Whelp, Pyre Knight, Siege Ballista, Siren of the Shoals, Solar Behemoth, Storm Drake, Tide Mortar and Vessa, Twinflame. Find them with `grep -rlE '"charge": [1-9]' packages/cards/data | xargs grep -L '"condition": "charged"'`.
- The golden game's script still attaches, which core still accepts: its streams shouldn't change. If they do, regenerate them as `golden.test.ts` says and say why in the PR.
- Leave the web's attach UI alone: T-197 replaces it next wave.
