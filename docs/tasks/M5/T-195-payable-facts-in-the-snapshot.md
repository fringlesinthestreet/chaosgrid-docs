---
id: T-195
title: Payable facts in the snapshot
milestone: M5
depends_on: [T-193]
branch: agent/T-195-payable-facts-in-the-snapshot
model: sonnet
effort: high
scope:
  - packages/protocol/src/snapshot.ts
  - packages/protocol/src/snapshot.test.ts
  - packages/protocol/src/version.ts
  - packages/protocol/test/**
  - docs/PROTOCOL.md
  - packages/core/**
context:
  - docs/DECISIONS.md#Decision log
  - docs/CORE.md#Defaults for open rules questions
  - docs/PROTOCOL.md#Snapshot
  - docs/PROTOCOL.md#Versioning
  - docs/RULES.md#Resources and mana
---

# T-195 — Payable facts in the snapshot

## Goal

D72: the snapshot says what the floating mana pays now. Each hand card, the Leader in the command zone, each Plan ability, and each of the seat's squads' level-up and Charge carry `payable`: whether the seat's floating mana pays the cost as the plan stands, the way `plan.checked`'s snapshot shows it. With it the UI can show an action inactive, with its cost, before the click instead of after a refusal (the human's playtest, 2026-11-05), and affordability stays core's (D29). The fields are optional for now so the bots' and the web's literals parse; T-200 makes them required.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// packages/protocol/src/snapshot.ts
export const AbilityUse = z.strictObject({ ability, cost: Cost, rest, spell, target: TargetSpec.optional(),
  /** The seat can use it now: the card is on its grid, the ability isn't used yet this round, the resources
   *  can pay, and with `rest` the squad isn't rested. */
  usable: z.boolean() });                                            // :146-:162: D64's meaning, unchanged
export const HandCard = z.discriminatedUnion('type', [ … ]);         // :168: `cost` on every variant, no pay fact
export const LeaderCard = z.strictObject({ … })                       // :215: the Leader in the command zone, with `cost`
export const PoolResource = z.strictObject({ card, cardId, gives, rested, floating, attachedTo, spell, target? }) // :223
// A resource's Rest ability costs no mana (no resource card prints one): `rested` already says whether it works.
export const SquadSnapshot = z.strictObject({ …, level, durability, unlocked, attached, rested, uses, charged?: boolean }) // :252
// (`charged` optional since T-193; the squad's Charge is `stats.charge`)

// packages/core/src/zones/pay.ts
export function planPayment(payers: readonly Payer[], cost: CostInput): CardInstanceId[] | null // :57: which payers pay
function asPayers(state: GameState, ids: readonly CardInstanceId[]): Payer[]                     // :148
export function canPayByResting(state: GameState, seat: Seat, cost: CostInput): boolean        // :159: floating + restable (D64's `usable`)
export function pay(state, seat, cost)                                                            // :172: floating mana only
// packages/core/src/zones/resources.ts:105 floatingResources(state, seat): the seat's floating mana
// packages/core/src/plan/abilities.ts:51 abilityBlocked (refuses a rested artifact's ability and a rested squad's
//   `rest` ability), :75 abilityUsable → AbilityUse.usable
// packages/core/src/effects/costs.ts:66 abilityCostFor(state, seat, card, index) and :76 levelUpCostFor(state, squad, base):
//   what an ability and a level-up cost now, cost changes applied
// packages/core/src/view/cards.ts:161 usesOf, :218 handCard(state, id), :264 leaderCard(state, id)
// packages/core/src/view/board.ts:45 squadSnapshot(state, squad): every seat's squads, built for every viewer
```

`plan.checked` sends the snapshot after the plan so far (CORE.md › Paying), so a fact computed from the current state is "as the plan stands" with no extra work.

## Deliverables

1. **One query.** A side-effect-free `canPayFromFloating(state, seat, cost)` in `zones/pay.ts`: `planPayment` over the seat's floating mana. `pay` and the new query agree by construction; a test says so for a few costs, colored pips and generic ones.
2. **The facts**, each optional, each with a doc comment:
   - `payable` on every `HandCard` variant and on `LeaderCard`: the floating mana pays the card's cost as core would charge it (cost changes applied);
   - `payable` on `AbilityUse`, beside `usable`;
   - on `SquadSnapshot`, `levelUpCost` (what a level-up pays now, cost changes applied) and `levelUpPayable`, and `chargePayable` (the floating mana pays its Charge in generic mana).
   For another seat's squads, and for a squad whose action doesn't apply (max level or not unlocked; Charge 0 or charged already), the payable fact is false. `levelUpCost` is left out for another seat's squads.
3. **The version.** Bump `PROTOCOL_VERSION` (34, after T-193's 33) with docs/PROTOCOL.md's title, the `HandCard`, `LeaderCard`, `SquadSnapshot` and `AbilityUse` sections, and a Versioning row naming D72.
4. **A rested card's resting ability.** Pin what the human reported ("already rested permanents can cast an ability that rests them") with tests on the snapshot after a plan step: a squad the plan rested shows `usable: false` and `payable: false` on its `rest` abilities; a rested artifact shows `usable: false` on all of them; core refuses both. Core does this already (`abilityBlocked`); if a test fails, fix core and say what was wrong.
5. **Tests in core:**
   - a hand card's `payable` turns true after the `restForMana` that pays it, and false again after a cast spends the mana;
   - a cost change shows in `payable` and in `levelUpCost`;
   - a level-up and a charge `payable` from floating mana, false when not unlocked, at max level, at Charge 0 or charged already;
   - the Leader's `payable`;
   - another seat's squad has false, and no `levelUpCost`.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/core test view pay abilities` passes.
- [ ] `pnpm --filter @chaosgrid/protocol test` passes.
- [ ] `pnpm test` passes.
- [ ] `pnpm test:perf` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The web reading `payable`: T-202. The bots: they keep their own pay logic.
- Making the fields required: T-200.
- Batching plan submits so `payable` doesn't flicker: D72's revisit.

## Notes

- `usable` keeps D64's meaning: the floating mana and the resources the seat could still rest pay it together. Don't change it.
- The bots' Simulator rebuilds state from a snapshot (`round/rebuild.ts`): the new fields are outputs only and need no rebuild.
- T-196 (bots), T-197 (web) and T-198 (cards) run beside you: none touches core or the protocol.
