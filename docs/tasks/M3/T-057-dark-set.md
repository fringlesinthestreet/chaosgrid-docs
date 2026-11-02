---
id: T-057
title: Dark card set
milestone: M3
depends_on: [T-050]
branch: agent/T-057-dark-set
model: sonnet
effort: medium
scope:
  - packages/cards/data/**
  - packages/cards/test/sets/dark.test.ts
  - packages/cards/src/dsl.test.ts
  - packages/core/src/effects/coverage.test.ts
  - tools/sim-cli/src/decks.test.ts
context:
  - docs/PLAN.md#M3
  - docs/RULES.md#Resources and attaching
  - docs/RULES.md#Zone mechanics
  - docs/tasks/README.md#M3
  - packages/cards/README.md#Fields every card has
  - packages/cards/README.md#Units
  - packages/cards/README.md#Leaders
  - packages/cards/README.md#Effects
  - packages/cards/README.md#Targets
  - packages/cards/README.md#Caster choices
  - packages/cards/README.md#Spell classes
---

# T-057 — Dark card set

## Goal

Dark (black, `D`) gets its cards: 30 for the main deck and a mono-Dark Leader. Dark fills its discard pile and brings units back (RULES.md › Resources and attaching › Colors): it dumps, revives and sacrifices, using the mechanics from T-049 and T-050.

## Interfaces

What exists after T-050:

```ts
// Card files: packages/cards/data/<folder>/<name>.json, one per card, id "<type>.<name>".
// Dark's basic resource is data/resources/crypt.json (T-041).
// DSL effects from T-049 and T-050: banish (units, permanents, or from a discard pile or deck top),
// sacrifice (self, chosenOwnUnit, ownPermanents), dump (amount, player target), revive
// (chosenDiscardPileUnit during Plan, lastDiscardPileUnit during Simulate). Target chosenEnemyUnit (T-042).
// packages/cards/src/node/load.ts:120 loadCards(dir?) returns every card, validated.
```

Nothing new is exported.

## Deliverables

1. 30 main-deck cards with `"set": "dark"` whose costs have only `D` pips and a generic number: about 16 units, 6 spells, 4 traps and 4 artifacts or enchantments, costs 1 to 7.
   - At least 5 cards that dump (your own deck, to fuel revives, or an opponent's), 5 that revive, and 4 that sacrifice for a payoff (draw, damage, a buff).
   - At least one revive during Plan (a utility spell with `chosenDiscardPileUnit`) and one during Simulate (an On death with `lastDiscardPileUnit`).
   - Every `text` says what the card's abilities do, in the style of the existing cards.
2. A Leader with `"set": "dark"` and only `D` pips.
3. `packages/cards/test/sets/dark.test.ts`: the `dark` cards are 30 main-deck cards and 1 Leader, every card's `usageColors` (T-043) is `['D']`, no ability uses `script`, and the counts in Deliverable 1 hold.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm cards:validate` passes
- [ ] `git diff --diff-filter=MDR --name-only main...HEAD` prints nothing: this task only adds files

## Out of scope

- New effects, keywords or scripts. If an idea needs one, drop the idea and list it in the PR.
- Editing existing cards, decks or fixtures. Dark's starter deck comes with T-061.

## Notes

- Content tasks run alongside the rules tasks (docs/tasks/README.md › M3). Add files only. A duplicate id fails `cards:validate`: if a set that merged meanwhile took one of your ids, rename yours after the rebase.
- A deck that dumps itself runs out: an empty deck draws nothing (RULES.md › Zone mechanics). Keep self-dump amounts small (1–3).
- If the M2 soak fails because a bot can't handle a legal card, send `lead` a `question` instead of changing the card.
