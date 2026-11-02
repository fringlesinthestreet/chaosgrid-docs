---
id: T-058
title: Light card set
milestone: M3
depends_on: [T-051]
branch: agent/T-058-light-set
model: sonnet
effort: medium
scope:
  - packages/cards/data/**
  - packages/cards/test/sets/light.test.ts
  - packages/core/src/effects/sources.ts
  - packages/core/src/effects/banish.ts
  - packages/core/src/effects/*.test.ts
context:
  - docs/PLAN.md#M3
  - docs/RULES.md#Resources and attaching
  - docs/RULES.md#Units
  - docs/RULES.md#Zone mechanics
  - docs/tasks/README.md#M3
  - packages/cards/README.md#Fields every card has
  - packages/cards/README.md#Units
  - packages/cards/README.md#Leaders
  - packages/cards/README.md#Keywords
  - packages/cards/README.md#Effects
  - packages/cards/README.md#Targets
  - packages/cards/README.md#Spell classes
---

# T-058 — Light card set

## Goal

Light (white, `L`) gets its cards: 30 for the main deck and a mono-Light Leader. Light protects and gives extra lives (RULES.md › Resources and attaching › Colors), using the keywords from T-051, and answers threats by banishing them (T-049).

## Interfaces

What exists after T-051:

```ts
// Card files: packages/cards/data/<folder>/<name>.json, one per card, id "<type>.<name>".
// Light's basic resource is data/resources/sanctum.json (T-041).
// Keywords from T-051: "shield": N, "extraLife": N, "ward": true, in "keywords" or through
// grantKeyword. Effects from T-049: banish, with the target chosenEnemyUnit (T-042).
// packages/cards/src/node/load.ts:120 loadCards(dir?) returns every card, validated.
```

Nothing new is exported.

## Deliverables

1. 30 main-deck cards with `"set": "light"` whose costs have only `L` pips and a generic number: about 16 units, 6 spells, 4 traps and 4 artifacts or enchantments, costs 1 to 7.
   - At least 6 cards with or granting Shield, 4 with or granting Extra life, 3 with or granting Ward, and 2 that banish, at cost 4 or more.
   - Every `text` says what the card's abilities do, in the style of the existing cards.
2. A Leader with `"set": "light"` and only `L` pips.
3. `packages/cards/test/sets/light.test.ts`: the `light` cards are 30 main-deck cards and 1 Leader, every card's `usageColors` (T-043) is `['L']`, no ability uses `script`, and the counts in Deliverable 1 hold.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm cards:validate` passes
- [ ] `git diff --diff-filter=MDR --name-only main...HEAD` prints nothing: this task only adds files

## Out of scope

- New effects, keywords or scripts. If an idea needs one, drop the idea and list it in the PR.
- Editing existing cards, decks or fixtures. Light's starter deck comes with T-061.

## Notes

- Content tasks run alongside the rules tasks (docs/tasks/README.md › M3). Add files only. A duplicate id fails `cards:validate`: if a set that merged meanwhile took one of your ids, rename yours after the rebase.
- Shield and Extra life refill every round (RULES.md › Balance knobs), so keep Extra life at 1 on cheap units and Shield small next to the unit's HP.
- If the M2 soak fails because a bot can't handle a legal card, send `lead` a `question` instead of changing the card.
