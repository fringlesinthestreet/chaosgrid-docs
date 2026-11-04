---
id: T-162
title: Rested and charged cues
milestone: M5
depends_on: [T-161]
branch: agent/T-162-rested-and-charged-cues
model: sonnet
effort: medium
scope:
  - apps/web/src/match/battlefield/scene.ts
  - apps/web/src/match/battlefield/scene.test.ts
  - apps/web/src/match/planning/PlanGrid.tsx
  - apps/web/src/match/planning/PlanGrid.test.tsx
  - apps/web/src/theme/palette.ts
  - apps/web/src/theme/palette.test.ts
  - apps/web/src/theme/theme.css
context:
  - docs/RULES.md#Resources and attaching
  - apps/web/README.md#Rules a change must keep
  - apps/web/README.md#Tests
---

# T-162 — Rested and charged cues

## Goal

Two requests from the human's playtest (2026-11-04):

- "Permanents rested need to be distinguished: make them a bit darker (so u avoid focusing on them)."
- "Permanent with charge abilities available need to have a way of telling: make the borders glow a bit on some color."

Today only a rested unit looks rested, and only on the battlefield during playback. PlanGrid, which lies over the viewer's grid while planning, draws no rests, and a rested artifact looks like any other.

After this task, rested squads and permanents look rested wherever they're drawn. A squad whose "If charged" abilities are on glows, and while planning, so does one of the viewer's squads that the free resources can charge now.

## Interfaces

What exists (copied on 2026-11-04, and from the T-161 and T-163 cards):

```ts
// apps/web/src/match/battlefield/scene.ts
// UnitView.sync: a rested unit draws `sprite.tint = PALETTE.muted` and `node.alpha = 0.6`.
// SquadView.sync(squad, rect): the footprint `outline`, filled at alpha 0.25 and stroked 1 px in seatColor(seat).
// PermanentView.sync(permanent, rect, now): no rested look.
// T-161: the pools' rested stacks use the same look as a rested unit.

// apps/web/src/match/model (T-163): PermanentModel.rested, set by `permanent.rested` and cleared at
// `round.ended`; attachedResources(model, squad): PoolCard[].

// apps/web/src/match/planning/PlanGrid.tsx
export function PlanGrid(props: { view: Snapshot; seat: Seat; ...; look?: 'opaque' | 'clear' }): JSX.Element;
// 'opaque' draws the view's squads and permanents (CardArt in their footprint); 'clear' draws only
// previews and outlines over the battlefield's copy. `cg-dimmed` marks squads the target picker can't pick.
// The view: SquadSnapshot { squad, cardId, attached, rested, ... }, PermanentSnapshot { rested, ... },
// and view.resources: PoolResource { rested, attachedTo, floating, ... }.
// SquadPanel counts a free resource as `!resource.rested && resource.attachedTo === null`.

// @chaosgrid/cards: a unit's or Leader's `card.stats.charge`, a number or undefined.
// apps/web/src/theme/palette.ts: COLORS (the CSS custom properties `--cg-*` through CSS_VARIABLES) and PALETTE for Pixi.
```

## Deliverables

1. **Rested looks the same everywhere**, as a rested unit does on the battlefield (`PALETTE.muted` tint, alpha 0.6):
   - **On the battlefield:** a rested permanent (`PermanentModel.rested`), and a rested squad's footprint outline with its units.
   - **In PlanGrid:** a rested squad or permanent in the view. In the `opaque` look its art draws darker, matching the battlefield's look in CSS. In the `clear` look a dark overlay covers its footprint, since the battlefield's model doesn't know about a rest the plan made.
2. **The Charge glow**, in one new color token, `charge`:
   - **Charged:** a squad whose card has Charge above 0 and at least that many resources attached. On the battlefield that's `attachedResources(model, squad)`, for every seat. In PlanGrid it's the view's `attached`. Its outline glows steadily.
   - **Ready to charge**, in PlanGrid only, for the viewer's own squads while planning: Charge above `attached`, and enough free resources in `view.resources` for the rest. Its outline glows and pulses gently, once every 2 s. Under `prefers-reduced-motion` it holds steady at half strength.
   - A rested squad never glows.
3. **The glow's look**, inside the footprint, so two neighbours' glows never merge. In Pixi: the 1 px outline in the token's color, and a second 1 px ring just inside it at alpha 0.4, with no filters and no new dependency. In the DOM: `box-shadow: inset 0 0 0 1px var(--cg-charge), inset 0 0 4px 1px var(--cg-charge)` on the footprint.
4. **The token:** `charge` in `COLORS`, which reaches CSS as `--cg-charge` and Pixi as `PALETTE.charge`. It keeps 3:1 against the battlefield's ground and stays apart from the four seat colors. `palette.test.ts` checks it as it checks the others.
5. **Tests:**
   - `scene.test.ts`: a rested permanent's view has the muted tint and alpha 0.6. A Charge 2 squad glows with two resources attached and not with one. A rested charged squad doesn't glow.
   - `PlanGrid.test.tsx`: a rested squad and a rested permanent carry the rested look in both looks. One of the viewer's Charge 1 squads is ready with one free resource and isn't with none. Another seat's squad is never ready. A squad with `attached` 2 and Charge 2 is charged.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test scene PlanGrid palette` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `pnpm test:e2e` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- A glow for a usable Plan ability (`uses[].usable`) on a squad or a permanent: the lead read "charge abilities" as Charge. A later card adds it if the human meant every ability.
- Attaching from the battlefield or PlanGrid: the squad panel does it.
- The pools' rested resources: T-161 drew them.

## Notes

- Defaults: only units and Leaders have Charge, so only squads glow. The token's color is the worker's pick, and the PR names it.
