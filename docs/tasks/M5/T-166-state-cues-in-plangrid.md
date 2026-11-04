---
id: T-166
title: State cues in PlanGrid
milestone: M5
depends_on: [T-156, T-165, T-168]
branch: agent/T-166-state-cues-in-plangrid
model: sonnet
effort: medium
scope:
  - apps/web/src/match/planning/PlanGrid.tsx
  - apps/web/src/match/planning/PlanGrid.test.tsx
  - apps/web/src/theme/theme.css
  - apps/web/src/i18n/en/planning.json
context:
  - docs/ART.md#Sizes
  - docs/RULES.md#Resources and attaching
  - apps/web/README.md#Text (D50)
  - apps/web/README.md#Tests
---

# T-166 — State cues in PlanGrid

## Goal

From the human's playtests (2026-11-04):

- "Permanents rested need to be distinguished: make them a bit darker."
- "Permanent with charge abilities available need to have a way of telling: make the borders glow a bit on some color."
- "Add icon on permanents for flying/reach/blocker/rested. Also should show current level. If level up is available then it should show a sign too. Also show durability remaining on units and use a special icon on those that will be removed after the round (so players can focus on leveling them up)."

PlanGrid lies over the viewer's grid while they plan, and today it draws no state: a rested squad looks like any other, and the level is a bare "L2" after the name. After this task PlanGrid draws rested squads and permanents darker, a Charge glow, and ART.md's badge row on every squad. T-162 draws the same cues on the battlefield.

## Interfaces

What exists (copied on 2026-11-04, and from the T-156 and T-165 cards):

```ts
// apps/web/src/match/planning/PlanGrid.tsx
export function PlanGrid(props: { view: Snapshot; seat: Seat; preview?; onCell?; onSquad?; onPermanent?;
  pickable?; disabled?; placement: GridOnScreen; look?: 'opaque' | 'clear' }): JSX.Element;
// 'opaque' draws the view's squads and permanents, each with CardArt in its footprint (T-156: the
// full footprint); 'clear' draws only previews and outlines over the battlefield's copy. A squad's
// button is labelled `${name}, level ${squad.level}` (', Leader'), and shows "{name} L{level}".
// `cg-dimmed` marks the squads the target picker can't pick.

// The view (planView: the latest plan.checked snapshot, else the round's):
// SquadSnapshot { squad, cardId, leader, level, durability: number | null, unlocked, attached, rested, ... }
// PermanentSnapshot { rested, durability, ... }; view.settings.maxLevel;
// view.units: UnitSnapshot[] { unit, squad, keywords, ... }; keywords: "Its keywords now: printed plus granted, each once."
// view.resources: PoolResource[]; SquadPanel counts a free one as `!resource.rested && resource.attachedTo === null`.

// @chaosgrid/cards: card.stats.charge (a number or undefined); card.keywords.flying and .reach are
// true or absent; card.keywords.blocker is true, a number or an expression when the card has Blocker.

// apps/web/src/art (T-165): the keys ui.durability, ui.retiring, ui.levelUp, ui.rested, ui.flying,
// ui.reach, ui.blocker, drawn through CardArt; ICON_PX = 8. apps/web/src/theme: --cg-charge, --cg-muted.
// The battlefield's rested look (scene.ts): tint PALETTE.muted, alpha 0.6.
```

## Deliverables

1. **Rested**, for a squad or a free-standing permanent whose `rested` is true. In the `opaque` look its art draws darker, matching the battlefield's look in CSS. In the `clear` look a dark overlay covers its footprint, since the battlefield's model doesn't know about a rest the plan made.
2. **The Charge glow**, in `--cg-charge`, inside the footprint so neighbours' glows don't merge: `box-shadow: inset 0 0 0 1px var(--cg-charge), inset 0 0 4px 1px var(--cg-charge)`.
   - **Charged:** the card's Charge is above 0 and `attached` reaches it. The glow is steady.
   - **Ready to charge:** Charge is above `attached`, and the free resources in `view.resources` cover the rest. The glow pulses gently, once every 2 s. Under `prefers-reduced-motion` it holds steady at half strength.
   - A rested squad never glows.
3. **The badge row** on every squad, as ART.md › Sizes › State badges says, in both looks:
   - `ui.durability` with the number, or `ui.retiring` alone at Durability 0; a Leader has none.
   - `ui.levelUp` when `unlocked` and `level` is below `maxLevel`, the same test as the squad panel's Level up (T-167).
   - `ui.rested` when rested.
   - the level in digits, from level 2; the "L{level}" text goes.
   - `ui.flying`, `ui.reach` and `ui.blocker` for the keywords its units have now: theirs in `view.units`, printed plus granted, such as Lighthouse's Reach. A squad with no units there shows its card's printed keywords.

   Badges that don't fit the footprint's width are left out, from the end of the row.
4. **The label:** the squad's button names its states after its name and level, through `t()` with keys in `en/planning.json`. For example: "Cinder Grunt, level 2, Durability 0, retires this round, can level up, rested, Flying".
5. **Tests** in `PlanGrid.test.tsx`:
   - A rested squad and a rested permanent carry the rested look in both looks.
   - A Charge 1 squad of the viewer's is ready with one free resource, and isn't with none. A squad with `attached` 2 and Charge 2 is charged. A rested charged squad doesn't glow.
   - Badges: Durability 3 shows the number; Durability 0 shows `ui.retiring` and no number; `ui.levelUp` shows when unlocked below the max and not at the max; a Flying, Reach Blocker card shows the three keyword badges; a squad whose units in `view.units` have Reach, from a card without it, shows `ui.reach`; a level 1 squad shows no level.
   - The label lists the states.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test PlanGrid` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `pnpm test:e2e` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The battlefield's cues: T-162.
- Badges on free-standing permanents beyond the rested look: ART.md puts the row on squads.
- A glow for a usable Plan ability (`uses[].usable`): the lead read "charge abilities" as Charge.

## Notes

- Defaults: the `--cg-charge` color is T-165's. The badges scale with the cell size: ×1 at 16 px per cell, ×2 at 32.
- T-166 waits for T-168 only because both edit `en/planning.json`.
