---
id: T-162
title: State cues on the battlefield
milestone: M5
depends_on: [T-161, T-165, T-170]
branch: agent/T-162-rested-and-charged-cues
model: sonnet
effort: medium
scope:
  - apps/web/src/match/battlefield/scene.ts
  - apps/web/src/match/battlefield/scene.test.ts
context:
  - docs/ART.md#Sizes
  - docs/RULES.md#Resources and attaching
  - apps/web/README.md#Tests
---

# T-162 — State cues on the battlefield

## Goal

From the human's playtests (2026-11-04): rested permanents should look darker, a squad whose Charge abilities are on should glow, and every squad should show icons for Flying, Reach, Blocker and rested, its level, its Durability, and a warning when it retires at this Cleanup.

On the battlefield today only a rested unit looks rested. A rested artifact looks like any other, and nothing shows Charge, Durability or keywords. After this task the battlefield draws rested permanents darker, a steady glow on charged squads, and ART.md's badge row on every squad's footprint. T-166 does the same in PlanGrid, which lies over the viewer's grid while they plan.

## Interfaces

What exists (copied on 2026-11-04, and from the T-161, T-163, T-165 and T-170 cards):

```ts
// apps/web/src/match/battlefield/scene.ts
// UnitView.sync: a rested unit draws `sprite.tint = PALETTE.muted` and `node.alpha = 0.6`.
// SquadView.sync(squad, rect): the footprint `outline`, filled at alpha 0.25 and stroked 1 px in
// seatColor(seat), and `level`, the level in pixel digits (drawText).
// PermanentView.sync(permanent, rect, now): no rested look.
// DETAIL_PX = 16: below it, markers instead of art. IconView(name) draws an icon with digits.
// T-161: the pools' rested stacks use the rested unit's look.

// apps/web/src/match/model (T-163): PermanentModel.rested, set by `permanent.rested` and cleared at
// `round.ended`; attachedResources(model, squad): PoolCard[].
// SquadModel { squad, seat, cardId, leader, level, durability: number | null, ... }; a squad's units
// carry `rested`. T-170: UnitModel.keywords (Keywords | null), the keywords core last sent for it.

// @chaosgrid/cards: card.stats.charge (a number or undefined); card.keywords.flying and .reach are
// true or absent; card.keywords.blocker is true, a number or an expression when the card has Blocker.
// apps/web/src/art (T-165): ui.durability, ui.retiring, ui.rested, ui.flying, ui.reach, ui.blocker;
// PALETTE.charge.
```

## Deliverables

1. **Rested:** a rested permanent (`PermanentModel.rested`) draws as a rested unit does, `PALETTE.muted` tint and alpha 0.6. So does a squad's footprint while its units are rested.
2. **The Charge glow**, for every seat: a squad whose card has Charge above 0 and at least that many resources in `attachedResources(model, squad)`. Its outline glows steadily in `PALETTE.charge`: the 1 px outline, and a second 1 px ring just inside it at alpha 0.4. No filters and no new dependency. A rested squad never glows.
3. **The badge row** on every squad's footprint, as ART.md › Sizes › State badges says:
   - `ui.durability` with the number, or `ui.retiring` alone at Durability 0; a Leader has none.
   - `ui.rested` while its units are rested.
   - the level in digits, from level 2, which replaces today's level digits.
   - `ui.flying`, `ui.reach` and `ui.blocker` for the keywords its units have now: `UnitModel.keywords` (T-170), printed plus granted, such as Lighthouse's Reach. While those are null, the card's printed keywords.

   There is no level-up badge: that's PlanGrid's, while planning. Badges that don't fit the footprint's width are left out, from the end of the row. Below `DETAIL_PX` there are no badges, only markers.
4. **Tests** in `scene.test.ts`:
   - A rested permanent's view has the muted tint and alpha 0.6.
   - A Charge 2 squad glows with two resources attached and not with one. A rested charged squad doesn't glow.
   - Durability 2 shows `ui.durability` with 2. Durability 0 shows `ui.retiring`. A Flying card shows `ui.flying`. A squad whose units' model keywords have Reach, from a card without it, shows `ui.reach`. A level 1 squad shows no level.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test scene` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `pnpm test:e2e` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- PlanGrid's cues, the level-up badge and the ready-to-charge glow: T-166.
- A glow for a usable Plan ability (`uses[].usable`): the lead read "charge abilities" as Charge.
- Keyword icons on each unit as it walks: the badges stay on the footprint.

## Notes

- Defaults: only units and Leaders have Charge, so only squads glow.
