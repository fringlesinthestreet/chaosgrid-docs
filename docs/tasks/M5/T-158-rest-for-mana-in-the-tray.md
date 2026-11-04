---
id: T-158
title: Rest for mana in the tray
milestone: M5
depends_on: [T-152, T-155]
branch: agent/T-158-rest-for-mana-in-the-tray
model: sonnet
effort: medium
scope:
  - apps/web/src/match/planning/ResourceEntry.tsx
  - apps/web/src/match/planning/Tray.tsx
  - apps/web/src/match/planning/FloatingMana.tsx
  - apps/web/src/match/planning/FloatingMana.test.tsx
  - apps/web/src/i18n/en/planning.json
  - apps/web/src/match/planning/PlanningPanel.test.tsx
context:
  - docs/RULES.md#Resources and attaching
  - docs/PROTOCOL.md#Plans
  - apps/web/README.md#Text
  - apps/web/README.md#Tests
---

# T-158 — Rest for mana in the tray

## Goal

T-155 adds floating mana (D58): a plan's `restForMana` rests one resource, and its mana floats until a cost spends it. Casting spends floating mana first, then auto-pay rests whatever else it needs. The human asked for this to choose which resources pay for each card (2026-11-04). After this task the tray lets the player rest a resource for mana, and shows the mana that floats.

## Interfaces

What exists (copied on 2026-11-04, and from the T-152 and T-155 cards):

```ts
// T-155: packages/protocol
export const RestForManaAction = z.strictObject({ action: z.literal('restForMana'), resource: CardInstanceId });
// PoolResource gains `floating: boolean`: rested for mana, its mana not spent yet. A resource that
// floats is also `rested`. Floating mana is gone once the plans lock.

// apps/web/src/match/planning/ResourceEntry.tsx: one resource in the tray's pool
const free = !resource.rested && resource.attachedTo === null;
// It renders the CardTile, "(gives)", "rested", "attached", and while planning a "Use" button
// (aria-label `Use ${name}`, a Rest ability) and, while collecting for Attach, a checkbox.
// `usePlan()` gives push(action), selection and select(); `state.checking` disables the buttons.

// apps/web/src/match/planning/Tray.tsx:56-80: <section aria-label="Resources"><h3>Resources</h3>
//   …the Attach button while attaching… <ul className="cg-tray-row">{view.resources.map(ResourceEntry)}</ul>

// T-152: apps/web/src/cards exports CostPips({ cost }), the face's pips: a grey pip for the generic
// number, one disc per colored pip in COLORS order, each with its letter.

// apps/web/src/match/planning/PlanningActions.test.tsx shows the way to test a click:
const stubAt = (view: Snapshot) => stubSession({ snapshot: view, planning: true }, cards);
const plansOf = (stub) => stub.sent.flatMap((command) => command.type === 'plan.submit' ? [[...command.plan]] : []);
const resource = (id: string) => within(document.querySelector(`[data-resource="${id}"]`)!);
```

`en/planning.json` is empty: this card adds the planning folder's first keys (D50). The folder's older text stays where it is.

## Deliverables

1. **Rest for mana.** While planning, each free resource (unrested, unattached) has a button "Mana", named "Rest {name} for mana", that pushes `{ action: 'restForMana', resource }`. It's disabled while `state.checking`, as the other buttons are. A resource with a Rest ability shows both "Use" and "Mana".
2. **What a resource shows:** "Floating" while its mana floats, "Rested" when it's rested otherwise, "Attached" as now. The words go through `t()`.
3. **`FloatingMana`**, at the top of the Resources section while planning: the label "Floating mana" and one pip per floating resource, in pool order. A pip shows what that mana pays: the resource's color, a split pip for two or three colors, a Prism pip for `'any'`, a grey pip for `[]`. Reuse T-152's pip look; a multi-color pip may be new. With nothing floating it shows "None". A sentence under it says "Casting spends floating mana first, then rests what else it needs."
4. **Text** in `en/planning.json`: `resource.mana` "Mana", `resource.restForMana` "Rest {name} for mana", `resource.floating` "Floating", `resource.rested` "Rested", `resource.attached` "Attached", `mana.title` "Floating mana", `mana.none` "None", `mana.hint`.
5. **Tests** in `FloatingMana.test.tsx`, with a stub session at a planning snapshot:
   - a click on "Rest {name} for mana" sends a plan that ends with that `restForMana`;
   - a rested, an attached or a floating resource has no enabled "Mana" button, and outside planning there's none;
   - with two resources floating (one Ember, one Prism) the row shows two pips, Ember's first, and both entries say "Floating";
   - with none, the row says "None".

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test FloatingMana Tray PlanningActions` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `pnpm test:e2e` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The battlefield's pools: T-161.
- Showing which hand cards the floating mana could pay: D29 keeps that core's (`plan.checked` refuses an unaffordable cast).
- Moving the planning folder's older text into `en/planning.json`.

## Notes

- Defaults: the button says "Mana" so the tray stays narrow; its accessible name says the rest. No confirmation: a rest stays done, as every plan action does (D37).
- Build test snapshots in the test from the planning fixtures, with `floating` set where needed; don't edit `test/fixtures/`.
- The PR says which keys it added to `en/planning.json`.
