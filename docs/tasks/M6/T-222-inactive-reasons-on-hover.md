---
id: T-222
title: Inactive reasons on hover
milestone: M6
depends_on: []
branch: agent/T-222-inactive-reasons-on-hover
model: sonnet
effort: medium
scope:
  - apps/web/src/match/planning/HandEntry.tsx
  - apps/web/src/match/planning/HandEntry.test.tsx
  - apps/web/src/match/planning/ActionButton.tsx
  - apps/web/src/match/planning/Tray.test.tsx
  - apps/web/src/match/planning/PlanningActions.test.tsx
  - apps/web/src/theme/theme.css
context:
  - docs/DECISIONS.md#Decision log
  - docs/APPS.md#The match
  - apps/web/README.md
---

# T-222 — Inactive reasons on hover

## Goal

A card or action the player can't use now shows dimmed, and its reason shows only on hover or keyboard focus (D72).

## Interfaces

On `main` (grep the names, the lines move).

- `HandEntry.tsx`: `unpayable = state.planning && !entry.payable` adds `cg-dimmed` (theme.css: `opacity: 0.45; filter: grayscale(0.6)`) and always shows `<span id={unpayableId}>{t('planning.inactive.unpayable')}</span>`, which is also the tile's `aria-describedby`.
- `ActionButton.tsx`: with a `reason`, the button is `aria-disabled` and shows `<span id={hint} data-inactive-reason="">{reason}</span>` beside it. Callers pass `planning.inactive.unpayable`, `.rested`, `.used`, `.unusable` and `.locked`.

## Deliverables

1. Every inactive reason, on a hand tile or beside a button, stays the element's accessible description (`aria-describedby`), but its text is visually hidden until the tile or button is hovered or has keyboard focus, when it shows as a small tooltip above it. The dimmed look stays. Styles in `theme.css`.
2. **Tests:** the planning tests check that the reason is still the description and carries the hidden-until-hover class.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test planning` green

## Out of scope

- The pool strip and its order: the pool goes with T-236.
- The trap code in the planning files (T-223).

## Notes

- jsdom has no hover: test the class and the description, not what's visible.
