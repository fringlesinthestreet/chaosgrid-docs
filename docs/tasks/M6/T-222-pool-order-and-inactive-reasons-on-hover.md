---
id: T-222
title: Pool order and inactive reasons on hover
milestone: M6
depends_on: []
branch: agent/T-222-pool-order-and-inactive-reasons-on-hover
model: sonnet
effort: medium
scope:
  - apps/web/src/match/battlefield/pools.ts
  - apps/web/src/match/battlefield/pools.test.ts
  - apps/web/src/match/planning/OwnPool.tsx
  - apps/web/src/match/planning/ResourceActions.tsx
  - apps/web/src/match/planning/HandEntry.tsx
  - apps/web/src/match/planning/HandEntry.test.tsx
  - apps/web/src/match/planning/ActionButton.tsx
  - apps/web/src/match/planning/Tray.test.tsx
  - apps/web/src/match/planning/PlanningActions.test.tsx
  - apps/web/src/match/planning/Zones.test.tsx
  - apps/web/src/theme/theme.css
context:
  - docs/APPS.md#The match
  - apps/web/README.md#Rules a change must keep
---

# T-222 — Pool order and inactive reasons on hover

## Goal

Resting a resource for mana never moves the other resources on the strip, and a card or action the player can't use now shows dimmed, with its reason only on hover or keyboard focus.

## Interfaces

On `main` (grep the names, the lines move). Core keeps the pool in its order; the reordering is the web's.

- `poolStacks()` (`battlefield/pools.ts`) groups the pool by `${card.cardId}|${card.rested}` and orders the stacks by each key's first card. `OwnPool.tsx`'s `stacksOf()` copies that logic, and `nextToRest()` (`ResourceActions.tsx`) rests the first unrested card of a stack. So the pool `[CryptA, Forest, CryptC]` shows `[Crypt ×2, Forest]`, and resting CryptA shows `[Crypt rested, Forest, Crypt]`: the ready Crypt jumps behind Forest.
- `HandEntry.tsx`: `unpayable = state.planning && !entry.payable` adds `cg-dimmed` (theme.css: `opacity: 0.45; filter: grayscale(0.6)`) and always shows `<span id={unpayableId}>{t('planning.inactive.unpayable')}</span>` ("Not enough mana: rest resources first"), which is also the tile's `aria-describedby`.
- `ActionButton.tsx`: with a `reason`, the button is `aria-disabled` and shows `<span id={hint} data-inactive-reason="">{reason}</span>` beside it. Callers pass `planning.inactive.unpayable`, `.rested`, `.used`, `.unusable` and `.locked`.

## Deliverables

1. **Order.** Stacks are ordered by the first pool position of their card id, and a card's ready stack comes right before its rested stack. Resting or unresting a card changes only the counts of that card's two stacks: in the example, `[Crypt ×2, Forest]` becomes `[Crypt, Crypt rested, Forest]`. `stacksOf()` calls `poolStacks()` instead of copying it.
2. **Reasons on hover.** Every inactive reason, on a hand tile or beside a button, stays the element's accessible description (`aria-describedby`), but its text is visually hidden until the tile or button is hovered or has keyboard focus, when it shows as a small tooltip above it. The dimmed look stays. Styles in `theme.css`.
3. **Tests:** `pools.test.ts` pins the new order with the example above and with resting the second copy of a stack; the planning tests check that the reason is still the description and carries the hidden-until-hover class.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test pools planning` green

## Out of scope

- How the strip draws the stacks it gets (`stripLayout`, `stackSpots`).
- The trap code in the planning files (T-223).

## Notes

- jsdom has no hover: test the class and the description, not what's visible.
