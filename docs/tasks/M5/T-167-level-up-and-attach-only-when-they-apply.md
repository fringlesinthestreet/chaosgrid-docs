---
id: T-167
title: Level up and Attach only when they apply
milestone: M5
depends_on: []
branch: agent/T-167-level-up-and-attach-only-when-they-apply
model: sonnet
effort: low
scope:
  - apps/web/src/match/planning/SquadPanel.tsx
  - apps/web/src/match/planning/PlanningActions.test.tsx
context:
  - docs/RULES.md#Resources and attaching
  - apps/web/README.md#Tests
---

# T-167 — Level up and Attach only when they apply

## Goal

Two requests from the human's playtest (2026-11-04): "Only show 'level up' if available", and "Only show 'attach resources' if permanent has ability that requires to attach resource". Today the squad panel shows both buttons on every squad, disabled when they can't act. After this task it shows Level up only on a squad that can level, and Attach resources only on a squad whose card has Charge.

## Interfaces

What exists (copied on 2026-11-04):

```tsx
// apps/web/src/match/planning/SquadPanel.tsx:21-23, 68-83
const atMax = squad.level >= view.settings.maxLevel;
const canAttach = view.resources.some((resource) => !resource.rested && resource.attachedTo === null);
<Button disabled={!squad.unlocked || atMax || state.checking} onClick={() => push({ action: 'levelUp', squad: squad.squad })}>
  Level up ({formatCost(squad.cost)})
</Button>
{atMax ? <span>Max level</span> : !squad.unlocked && <span>Next level locked</span>}
<Button aria-pressed={attaching} disabled={!canAttach || state.checking} onClick={...}>Attach resources</Button>
// The panel's "Attached" row lists the squad's attached resources.

// @chaosgrid/cards: a unit's or Leader's card.stats.charge, a number or undefined. All 13 cards with an
// "If charged" ability have Charge 1 or more.
// apps/web/src/match/planning/PlanningActions.test.tsx:368, "turns off Level up on a squad whose
// next level is locked", expects the button disabled and the text "Next level locked".
```

## Deliverables

1. **Level up** shows only when the squad is `unlocked` and below `maxLevel`. Otherwise there's no button, and the existing "Max level" or "Next level locked" text says why. The button stays disabled while a check is pending.
2. **Attach resources** shows only when the squad's card has Charge above 0. It stays disabled when no resource is free. The "Attached" row stays on every squad, so resources attached some other way still show.
3. **Tests** in `PlanningActions.test.tsx`:
   - A locked squad has no Level up button and says "Next level locked". This replaces the test at :368, since the request changes the behavior it pinned.
   - A squad at the max level has no Level up button and says "Max level". An unlocked one below the max has the button, and a click still levels it.
   - A Charge 0 unit has no Attach resources button. A Charge 1 unit has it, disabled with no free resource.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test PlanningActions` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Whether the player can pay for the level: core checks that (D29), as today.
- The level-up badge on the grid: T-166 uses the same test as deliverable 1.

## Notes

- Defaults: no new text, so no language file changes. Legality stays core's: the panel only hides controls that can't do anything.
