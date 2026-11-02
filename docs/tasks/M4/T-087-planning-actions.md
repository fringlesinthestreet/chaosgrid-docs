---
id: T-087
title: Planning panel, spells, abilities and targets
milestone: M4
depends_on: [T-086]
branch: agent/T-087-planning-actions
model: sonnet
effort: high
scope:
  - apps/web/src/match/planning/**
  - apps/web/test/fixtures/planning/**
context:
  - docs/tasks/M4/README.md#The match
  - docs/PROTOCOL.md#Plans
  - docs/PROTOCOL.md#Targets
  - docs/PROTOCOL.md#`HandCard`
  - docs/PROTOCOL.md#`PoolResource`
  - docs/PROTOCOL.md#`SquadSnapshot`
  - docs/PROTOCOL.md#`PermanentSnapshot`
---

# T-087 — Planning panel, spells, abilities and targets

## Goal

T-086 places units and the Leader. This task adds the other seven plan actions, so the player can do anything a bot can: cast spells and permanents, rest resources for their abilities, use Plan abilities, level squads up, attach resources and discard. A spell or ability that takes a target opens a picker for the five board target kinds (`seat`, `row`, `area`, `squad`, `squadToCell`), over any seat's grid. After this task every `PlanAction` can be planned from the UI. The two M3 kinds, a revive's `discardPileCard` and a copy's `spell`, need the discard pile and the plan itself, and come in T-100.

## Interfaces

What exists (T-086, and the protocol):

```ts
// apps/web/src/match/planning (T-086)
// draft.ts: Draft, pushAction, planView, footprint, gridContents, REJECT_TEXT, describeAction
// PlanContext.tsx: usePlan() → { draft, view, push, selection, select, inspected, inspect }; push only adds (D37)
//   Selection kinds: castUnit, castLeader, moveLeader
// PlanGrid({ view, seat, preview?, onCell?, onSquad? }); SquadPanel({ squad }), with Move for the Leader
// apps/web/test/fixtures/planning/snapshot.json and README.md (T-086)
// @chaosgrid/protocol: Target, TargetSpec, TargetKind, Side, PlanActionType, AbilityUse, PoolResource,
//   PermanentSnapshot, PermanentId, HandCard, GameSettings, SpellClass, SpawnedSquadSnapshot,
//   CastSpellAction, UseResourceAction, UseAbilityAction
// TargetKind has seven kinds (PROTOCOL.md › Targets): seat, row, area, squad (spec: side, noLeader?),
//   squadToCell, discardPileCard and spell. Snapshot.spawned holds Chaos squads and tokens: no footprint.
```

What this task adds (`apps/web/src/match/planning/`):

```ts
// targets.ts (pure)
/** The seats a spec may name, the planner's own first: `own` → [seat], `opponent` → the others, `any` → all. */
export function seatsFor(spec: TargetSpec, view: Snapshot): Seat[];
/**
 * The squads a `squad` or `squadToCell` spec may name, by their owner's side. A `squad` spec with side
 * `opponent` or `any` also names Chaos squads and other seats' tokens (`view.spawned`); `noLeader` drops Leaders.
 */
export function squadsFor(spec: TargetSpec, view: Snapshot): SquadId[];
/** The cells a `row` or `area` target covers from the hovered cell, for PlanGrid's preview; cells off the grid included. */
export function targetCells(spec: TargetSpec, hovered: Cell): Cell[];
/** "seat 2's row 3", "your Flame Lancer", … for the plan list, for all seven kinds. */
export function describeTarget(target: Target, view: Snapshot, lookup: (card: CardInstanceId) => string | undefined): string;

// TargetPicker.tsx: shown in place of the grid while a target is pending
export function TargetPicker(props: {
  spec: TargetSpec; view: Snapshot;
  onPick(target: Target): void; onCancel(): void;
}): JSX.Element;

// PermanentPanel.tsx: a free-standing permanent of the seat's, under the grid
export function PermanentPanel(props: { permanent: PermanentSnapshot }): JSX.Element;

// PlanGrid gains
//   onPermanent?(permanent: PermanentSnapshot): void;
// PlanContext.tsx: PlanControls' `inspected` and `inspect` take a permanent too (T-086's took a SquadId)
export type Inspected = { squad: SquadId } | { permanent: PermanentId };
//   inspected: Inspected | null;
//   inspect(what: Inspected | null): void;
// Selection gains
//   | { kind: 'castPermanent'; card: CardInstanceId; mode: 'freeStanding'; size: Size; rotated: boolean }
//   | { kind: 'castPermanent'; card: CardInstanceId; mode: 'attached' }      // waits for a squad click
//   | { kind: 'target'; spec: TargetSpec; action: CastSpellAction | UseResourceAction | UseAbilityAction } // without its target yet
//   | { kind: 'attach'; squad: SquadId; resources: CardInstanceId[] }
//   | { kind: 'discard'; cards: CardInstanceId[] }
```

## Deliverables

1. **The hand.** Each entry shows its `cost` and gets buttons by `type`:
   - `spell`: Cast. Its class shows: a `utility` spell "resolves now", the others "at the start of Simulate". No `target`: it pushes `castSpell { card }`. With one, the picker opens, then it pushes `castSpell { card, target }`.
   - `trap`, `artifact`, `enchantment`: Cast. A `freeStanding` card is placed like a unit (T-086), with its `size` as the preview and R to rotate, and pushes `castPermanent { card, mode: 'freeStanding', cell, rotated }`. An `attached` card waits for a click on one of the seat's squads, and pushes `castPermanent { card, mode: 'attached', squad }`.
   - every card: Discard, which starts discard mode. Tick cards in the hand, then "Discard N" pushes one `discard { cards }`. Escape cancels.
   - The `uses` of a card in the hand aren't shown: they're never usable there (PROTOCOL.md › `HandCard`).
2. **The pool.** A resource with a Rest ability (`spell` not null) has Use, enabled when it's neither `rested` nor attached (`attachedTo` null). It pushes `useResource { resource }`, through the picker when it has a `target`.
3. **`SquadPanel`** gains:
   - Level up, with its `cost`. It's enabled when `unlocked` and `level` is below `settings.maxLevel`, and shows "Next level locked" when not `unlocked`. It pushes `levelUp { squad }`.
   - Attach, enabled when some pool resource is unrested and unattached. Tick resources in the pool (unrested, unattached ones only), then "Attach N" pushes one `attach { squad, resources }`. Escape cancels.
   - One button per `uses` entry: its cost, "Rests the squad" when `rest`, enabled when `usable`. It pushes `useAbility { card: squad.card, ability, target? }`, through the picker when it has a `target`.
   - The permanents attached to the squad (`squad` equal to its id), each with its own ability buttons, as below.
4. **`PermanentPanel`.** Clicking a free-standing permanent of the seat's on the grid inspects it (`inspect({ permanent })`) and shows it here: the card, face down or not, `rested`, Durability, and one button per `uses` entry as for a squad (`card: permanent.card`).
5. **`TargetPicker`.** It shows "Choose <what>" and Cancel (Escape cancels too), in place of the grid:
   - `seat`: one button per `seatsFor` seat, with its points ("You" for the seat's own). A click picks `{ kind: 'seat', seat }`.
   - `row`: one tab per `seatsFor` seat over that seat's `PlanGrid`. Hovering outlines the whole row (`targetCells`), and a click picks `{ kind: 'row', seat, row }`.
   - `area`: the same tabs, outlining `spec.size` anchored at the hovered cell. A click picks `{ kind: 'area', seat, cell }`.
   - `squad`: one tab per seat that has a `squadsFor` squad on its grid, with only those squads clickable, and under the tabs a list of the `squadsFor` squads from `view.spawned` ("Chaos: <card name>", "Seat 2's token: <card name>"). A click picks `{ kind: 'squad', squad }`.
   - `squadToCell`: the squad as above, then a cell of its owner's grid, with the squad's footprint (`size`, `rotated`) as the preview. It picks `{ kind: 'squadToCell', squad, cell }`.
   - The picker judges nothing beyond the spec's `side` and `noLeader` (D29). The other seats' grids show their squads, permanents and prizes as the snapshot lists them; a prize is never clickable.
   - `discardPileCard` and `spell`: not yet. A card or ability whose `target` has one of these kinds has its Cast or Use button disabled, titled "Not available yet". T-100 enables them.
6. **The plan list.** `describeAction` covers all ten `PlanActionType`s, with an exhaustive `switch` so a new action type fails typecheck, and adds the target from `describeTarget`: "Cast Scorch Line on seat 2's row 3".
7. **Fixture.** Add `snapshot-actions.json` to `apps/web/test/fixtures/planning/` and describe it in its README: a seat-0 Plan `Snapshot` with
   - in the hand: one spell per board target kind, a spell with no target, a `noLeader` squad spell (`spell.blood_pact` if it fits), a free-standing trap and an attached enchantment
   - in the pool: a resource with a Rest ability, a rested one and a plain one
   - on the grid: the Leader and a unit squad, one `unlocked`, one with a `usable` ability and one with an unusable one
   - two other seats with a squad each, one of them a token, and a Chaos squad in `spawned`

   Use real card ids where a card fits, so the names resolve. The tests check the file with the `Snapshot` schema.
8. **Tests:**
   - `targets.ts`: `seatsFor` for each `Side`; `squadsFor` for `own` and `opponent`, with the Chaos squad and the other seat's token for `opponent` and the Leader dropped by `noLeader`; `targetCells` of a row, and of a 4×4 area at col 28 (two columns off a 30-wide grid, kept); `describeTarget` for each of the seven kinds
   - `describeAction`: one line for each entry of `PlanActionType.options`, so a new type fails the test
   - the panel on `stubSession` with `snapshot-actions.json`:
     - the spell with no target sends `castSpell` without `target`
     - for each board target kind, the picker's clicks put the expected `Target` in the plan sent; the squad picker lists the Chaos squad and picks it, and the `noLeader` spell can't pick the Leader
     - Escape in the picker sends nothing
     - the free-standing trap, R, then a cell sends `castPermanent` with `rotated: true`; the attached enchantment, then a squad, sends `castPermanent { mode: 'attached', squad }`
     - Use is disabled on the rested resource and sends `useResource` on the other
     - Level up is enabled only on the `unlocked` squad; the unusable ability's button is disabled
     - Attach with two resources ticked sends one `attach` with both; Discard with two cards ticked sends one `discard` with both
   - with a real session (as in T-086): Place Leader on a cell, then click the Leader's block in the checked snapshot and Level up. The plan sent names the squad id that snapshot gave, and the panel draws core's answer: accepted, or struck through with its reason.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test -- planning` passes

## Out of scope

- Previewing what a spell will do, beyond its target.
- Telling the player a target is illegal before `plan.checked` does (D29).
- Drag and drop.
- Revive and copy targets, the discard pile and void panels, and the rules on this round (T-100).

## Notes

- Disable a button only on what the snapshot says (D29): `usable`, `unlocked`, `level` against `settings.maxLevel`, `rested`, `attachedTo`, `spell`. Affordability, room and Fog of War's `forbidden` are core's, and come back in `plan.checked`.
- `useAbility`'s `ability` is the `AbilityUse.ability` index, the index in the card's abilities, not the entry's position in `uses`.
- A card a utility spell drew is in `view.hand` once its `plan.checked` arrives, so it can be played in the same plan. `planView` already gives that; nothing more is needed.
- Default: Attach and Discard each collect their choices into one action.
- Another seat's face-down traps aren't in the snapshot, so they can never be picked.
- D34: during Plan, the other seats' grids are as they were when Plan began, so a squad another seat places this Plan can't be picked. That's the rule, not a bug.
- Clicks on a squad or permanent that T-086 used to inspect still inspect, except while a selection waits for a squad (`castPermanent` attached, a `squad` target).
