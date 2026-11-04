---
id: T-177
title: Cost label text and marked-cost style out of CardFace
milestone: M5
depends_on: []
branch: agent/T-177-cost-label-text-and-marked-cost-style-ou
model: sonnet
effort: medium
scope:
  - apps/web/src/cards/CardFace.tsx
  - apps/web/src/cards/CardFace.test.tsx
  - apps/web/src/cards/face.css
  - apps/web/src/i18n/en/cards.json
context:
  - docs/tasks/M5/T-169-live-costs-in-the-hand.md
---

# T-177 — Cost label text and marked-cost style out of CardFace

## Goal

T-169 left two things inline in `CardFace.tsx`: the English "printed" part of the cost's accessible label (`${t('cards.face.cost', { cost })}, printed ${card.cost}`) and the marked cost's outline (an inline style). Move the text into i18n and the outline into CSS, with no change in what the player sees or hears.

## Deliverables

1. A `cards.face.*` key in `apps/web/src/i18n/en/cards.json` for the printed-cost label (with the printed cost as a parameter), used by `CardFace.tsx`.
2. A class in `face.css` for the lower/higher marked cost's outline, used instead of the inline style.
3. `CardFace.test.tsx` still passes, adjusted only if it relied on the inline style.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test CardFace` passes

## Out of scope

- The sim-cli golden fixture `dark_toll.json`: it is a frozen copy.
