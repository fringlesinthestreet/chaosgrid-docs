---
id: T-056
title: Colorless top-up
milestone: M3
depends_on: [T-044]
branch: agent/T-056-colorless-top-up
model: sonnet
effort: medium
scope:
  - packages/cards/data/**
  - packages/cards/test/sets/colorless.test.ts
context:
  - docs/PLAN.md#M3
  - docs/RULES.md#Units
  - docs/tasks/README.md#M3
  - packages/cards/README.md#Fields every card has
  - packages/cards/README.md#Units
  - packages/cards/README.md#Effects
  - packages/cards/README.md#Targets
  - packages/cards/README.md#Spell classes
---

# T-056 — Colorless top-up

## Goal

Colorless reaches 20 main-deck cards, from 6. With at most 4 copies of a card (T-063), a 100-card mono-color deck needs at least 25 different cards, more when some are Unique. A color's 30 cover that, so the 14 cards this adds, which any deck can play, are for variety: they give every deck choices outside its color.

## Interfaces

What exists (copied from the code):

```ts
// Card files: packages/cards/data/<folder>/<name>.json, one per card, id "<type>.<name>".
// A colorless card's cost is a generic number only ("3").
// packages/cards/src/node/load.ts:120 loadCards(dir?) returns every card, validated.
```

Nothing new is exported.

## Deliverables

1. 14 main-deck cards with a generic-only cost and `"set": "colorless"`: a mix of units, spells, traps and artifacts, costs 1 to 6. A colorless card is a little weaker than a colored card of the same cost, and doesn't do what a color is known for (RULES.md › Resources and attaching › Colors).
2. `packages/cards/test/sets/colorless.test.ts`: the `colorless` cards are 14 main-deck cards whose `usageColors` (T-043) is empty, with no `script`, and over `loadCards()` there are at least 20 colorless main-deck cards.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm cards:validate` passes
- [ ] `git diff --diff-filter=MDR --name-only main...HEAD` prints nothing: this task only adds files

## Out of scope

- New effects, keywords or scripts. If an idea needs one, drop the idea and list it in the PR.
- Editing existing cards, decks or fixtures

## Notes

- Content tasks run alongside the rules tasks (docs/tasks/README.md › M3). Add files only. A duplicate id fails `cards:validate`: if a set that merged meanwhile took one of your ids, rename yours after the rebase.
- Traps are free-standing only (T-044).
- If the M2 soak fails because a bot can't handle a legal card, send `lead` a `question` instead of changing the card.
