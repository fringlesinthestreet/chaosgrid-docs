---
id: T-100
title: Planning panel, revive, copy, piles and rules
milestone: M4
depends_on: [T-087]
branch: agent/T-100-planning-zones
model: sonnet
effort: medium
scope:
  - apps/web/src/match/planning/**
  - apps/web/test/fixtures/planning/**
context:
  - docs/APPS.md#The match
  - docs/PROTOCOL.md#Plans
  - docs/PROTOCOL.md#Targets
  - docs/PROTOCOL.md#`PlayerSnapshot` and `SeatScore`
  - docs/PROTOCOL.md#Snapshot
---

# T-100 — Planning panel, revive, copy, piles and rules

## Goal

T-087 lets the player plan every action, with the five board target kinds. M3 added two more: a revive (Raise Dead) names a unit card of the seat's discard pile and where it goes, and a copy (Resonance) names an earlier spell of the same plan. M3 also made the discard pile and the void public, and added round rules such as Fog of War's `noSpells`. After this task the picker handles all seven target kinds, the panel shows every seat's discard pile and void, and a bar says which rules are on for the seat this round.

## Interfaces

What exists (T-086, T-087, and the protocol):

```ts
// apps/web/src/match/planning (T-086, T-087)
// draft.ts: Draft, pushAction, planView, footprint, describeAction, REJECT_TEXT
// targets.ts: seatsFor, squadsFor, targetCells, describeTarget (all seven kinds)
// TargetPicker({ spec, view, onPick, onCancel }): the five board kinds; for discardPileCard and spell,
//   the Cast or Use button is disabled, titled "Not available yet"
// usePlan() → { draft, view, push, selection, select, … }, push only adds (D37); useSession() → { session, state }
//   state.snapshot is the round's, from the start of Plan; state.checked the latest plan.checked
// apps/web/src/theme (T-068): the class cg-dimmed
// @chaosgrid/protocol:
//   Target { kind: 'discardPileCard', card, cell, rotated } | { kind: 'spell', action } | …
//   TargetSpec { kind: 'discardPileCard', side: 'own' } | { kind: 'spell', side: 'own' } | …
//   CastSpellAction, UseResourceAction, UseAbilityAction: target?, copyTarget? (read only with a spell target)
//   PlayerSnapshot.discardPile: { card, cardId, size: Size | null, cost }[], oldest first; .void: CardId[]
//   Snapshot.rules: Rule[] ('noSpells' | 'trampleHitsFriendlyUnits' | 'noHandSizeLimit'), the seat's own
```

What this task adds (`apps/web/src/match/planning/`):

```ts
// targets.ts gains (pure)
/** The plan's actions a copy at `index` may copy: earlier castSpell, useResource and useAbility actions. */
export function copyableActions(actions: readonly PlanAction[], index: number): number[];
/**
 * The target spec of the spell an action casts, from the round's snapshot (the hand, the pool, a squad's
 * or permanent's `uses`), or undefined when it has none or can't be found there.
 */
export function copiedSpec(action: CastSpellAction | UseResourceAction | UseAbilityAction, round: Snapshot): TargetSpec | undefined;

// rules.ts
export const RULE_TEXT: Record<Rule, string>; // "Fog of War: defensive and offensive spells are rejected", …

// ZonesPanel.tsx: every seat's discard pile and void
export function ZonesPanel(props: { view: Snapshot }): JSX.Element;
// RulesBar.tsx: the seat's rules this round, nothing when there are none
export function RulesBar(props: { rules: readonly Rule[] }): JSX.Element | null;

// TargetPicker gains discardPileCard and spell, and for a copy the copyTarget step:
//   onPick(target: Target, copyTarget?: Target): void
```

## Deliverables

1. **Revive (`discardPileCard`).** The picker lists the seat's own discard pile (`view.players[view.seat].discardPile`), newest first, with each card's name and cost ("Nothing to revive" when it's empty). An entry whose `size` is null (it isn't a unit card) is disabled, dimmed (`cg-dimmed`) and titled "Not a unit". That's all the picker judges, and the snapshot says it (D29). Picking one shows the seat's `PlanGrid` with the card's footprint as the preview (`footprint(cell, size, rotated)`), and R rotates, as for `castUnit` (T-086). A cell click picks `{ kind: 'discardPileCard', card, cell, rotated }`. The preview never judges room; core answers with `noRoom` or `illegalTarget` in `plan.checked`.
2. **Copy (`spell`).** The picker lists the plan's `copyableActions` for the action being added (its index is `draft.actions.length`), one line each with `describeAction`. An action struck through in `checked.rejected` stays listed, struck through, since core rejects a copy of it. Picking one shows two choices:
   - **Keep its target**, which picks `{ kind: 'spell', action }` with no `copyTarget`.
   - **Choose a new target**, enabled when `copiedSpec` gives a spec. It opens the picker again with that spec, for any of the five board kinds, and picks `{ kind: 'spell', action }` with that target as `copyTarget`.

   The action pushed carries both: `castSpell { card, target, copyTarget? }`, and the same for `useResource` and `useAbility`.
3. **Enable them.** The Cast and Use buttons T-087 disabled for these two kinds now open the picker. `describeTarget` for a `spell` target names the copied action ("copy of action 2, Scorch Line"), and `describeAction` adds the `copyTarget` ("Cast Resonance: copy of action 2, Scorch Line, on seat 3's row 4").
4. **`ZonesPanel`.** One collapsible section per seat, the planner's own first ("You", then "Seat 2", …): the discard pile, oldest at the bottom, each card with its name (from `session.cards`, else its cardId) and a click that shows its `CardDetail`; and the void, the same. Empty ones say "Empty". Another seat's section says "As of the start of Plan" (D34).
5. **`RulesBar`.** Above the hand, one chip per `view.rules` entry with its `RULE_TEXT`. Nothing renders when the list is empty. The panel disables no button for a rule: core rejects a defensive or offensive spell under `noSpells` with `forbidden` (D29), and the plan list shows it.
6. **Fixture.** Add `snapshot-zones.json` to `apps/web/test/fixtures/planning/` and describe it in its README: a seat-0 Plan `Snapshot` with
   - in the hand: `spell.raise_dead`, `spell.resonance`, and a spell with a `row` target
   - in the seat's discard pile: two unit cards (one 1×1, one 2×1) and a non-unit card; in its void, one card
   - another seat's discard pile with a card, and an empty void
   - `rules: ['noSpells']`

   Use real card ids. The tests check the file with the `Snapshot` schema.
7. **Tests:**
   - `targets.ts`: `copyableActions` keeps only earlier `castSpell`, `useResource` and `useAbility` actions; `copiedSpec` for a hand spell, a pool resource and a squad ability, and undefined for a card not in the round's snapshot
   - `RULE_TEXT` has a text for every `Rule` option
   - the panel on `stubSession` with `snapshot-zones.json`:
     - Raise Dead: the non-unit entry is disabled; picking the 2×1, R, then a cell sends `castSpell` with `{ kind: 'discardPileCard', card, cell, rotated: true }`
     - the row spell, then Resonance with Keep its target, sends a second `castSpell` with `{ kind: 'spell', action: 0 }` and no `copyTarget`
     - the same with Choose a new target and a row of seat 2 sends `copyTarget: { kind: 'row', seat: 2, row }`
     - Resonance in an empty plan lists nothing to copy
     - Escape at each step sends nothing
     - the zones panel lists both seats' piles and the void; the rules bar shows the Fog of War text
   - with a real session (as in T-086), on the `dark_revive` starter deck and a searched seed: the first seed from 1 whose round-1 hand holds `spell.raise_dead` and a unit card (don't commit the search script; name the seed in the test). Discard the unit card, then cast Raise Dead on it once the checked snapshot shows it in the pile. The panel draws core's answer: accepted, or struck through with its reason. No such seed under 1000: run the same steps on `stubSession` with hand-built `checked` snapshots, and say so in the handoff

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test -- planning` passes

## Out of scope

- A preview of what a revive or a copy will do, beyond the target.
- Telling the player a revive won't fit, or a copy is illegal, before `plan.checked` does (D29).
- The other seats' hands and decks (only counts are public).
- Drag and drop.

## Notes

- Default: a copy's `copiedSpec` reads the round's snapshot, since the copied card has left `planView`'s hand once it's cast. When the copied action is itself a copy, or its card isn't in the round's snapshot (a card a utility spell drew this Plan), only Keep its target is offered. Ask lead if a real deck needs more.
- A copy's target always points backwards in the plan, and the plan never shrinks (D37), so the copied action always exists. When core refused that action, it refuses the copy too, and the plan list strikes both through.
- D34: during Plan, another seat's discard pile and void are as they were when Plan began. A revive or a discard of theirs this Plan shows after `plans.revealed`.
- Read the pile from `planView`, not the round's snapshot: a card discarded earlier in this plan shows in it once that `plan.checked` arrives.
