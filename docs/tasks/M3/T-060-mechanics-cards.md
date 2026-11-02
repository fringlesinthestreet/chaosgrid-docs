---
id: T-060
title: Rest, fear, copy and color cards
milestone: M3
depends_on: [T-053, T-063, T-094]
branch: agent/T-060-mechanics-cards
model: sonnet
effort: medium
scope:
  - packages/cards/data/**
  - packages/cards/test/sets/mechanics.test.ts
  - packages/core/src/effects/coverage.test.ts
context:
  - docs/PLAN.md#M3
  - docs/RULES.md#Simulation rules
  - docs/RULES.md#Card colors
  - docs/RULES.md#Units
  - docs/RULES.md#Non-unit permanents and spells
  - docs/tasks/README.md#M3
  - packages/cards/README.md#Fields every card has
  - packages/cards/README.md#Deck colors
  - packages/cards/README.md#Triggers
  - packages/cards/README.md#Effects
  - packages/cards/README.md#Targets
  - packages/cards/README.md#Spell classes
---

# T-060 — Rest, fear, copy and color cards

## Goal

Real cards for the mechanics that T-042 to T-053 and T-063 add and that no color set covers yet: Plan abilities that rest, enemy rests, fear, copy, Unique permanents, Colorless cards, color-matters effects and cost changes, and a Leader whose color allowance is wider than its cost. The cards are spread over the five colors, so T-061's decks can pick them up. The set uses only what the DSL has after T-053 and T-063.

## Interfaces

What exists (copied from the code, after T-042 to T-053):

```ts
// Card files: packages/cards/data/<folder>/<name>.json, one per card, id "<type>.<name>".
// T-042: Plan abilities: { "trigger": "onUse", "cost"?: "…", "rest"?: true, "spell": "utility" | …, … };
//        effect('rest', { target }) with chosenEnemyUnit and the unit groups
// T-043: "colorless": true; effect('costChange', { target, amount, cards: { type?, color? } });
//        a `color` filter reads card color; colorAllowance(leader) = the pips of cost and of its onUse costs
// T-052: effect('fear', { target, seconds })
// T-063: "unique": true on units, artifacts, enchantments and traps (at most 1 per deck)
// T-053: effect('copy', { target: 'chosenOwnSpell' | 'lastOwnSpell' | 'triggeringSpell' }), valid on spells,
// traps, onUse, onRest and onPlay only; T-050: the onPlay trigger (When played)
// packages/cards/src/node/load.ts:120 loadCards(dir?) returns every card, validated.
```

Nothing new is exported.

## Deliverables

1. 24 main-deck cards with `"set": "mechanics"`. Each color (`R`, `T`, `E`, `D`, `L`) gets at least 4 of them, counted by `usageColors` (T-043), and at least 2 are colorless (empty `usageColors`), which count toward no color. A card's `usageColors` has one color at most, so every card fits a mono-color deck. Costs run from 1 to 6.
   - **Rest:** at least 3 units, outside Earth, whose Plan ability rests them for a payoff (a draw, a resource, a buff or a Shield for the others). At least 2 offensive spells or abilities rest enemy units, one of them a group.
   - **Fear:** at least 4 cards: an offensive spell on one enemy squad, an area fear, a unit whose hits fear their target for 1 second (`onAttack`), and a trap.
   - **Copy:** at least 4 cards: a utility spell that copies a spell you cast this Plan (`chosenOwnSpell`), a unit whose Plan ability copies one, a unit that copies the last spell you cast When played (`onPlay` with `lastOwnSpell`, its `text` saying "When played"), and a trap on `enemySpellTargetsArea` that copies the spell back (`triggeringSpell`). No card copies On enter (RULES.md › Copy).
   - **Card color:** at least 3 cards whose effects read card color (for example "Your red units get +1 Attack"), and at least 2 `costChange` cards: one that makes its owner's spells of its color cost 1 less, and one that makes opponents' spells of a color cost 1 more.
   - **Unique:** at least 2 non-Leader permanents with `"unique": true`, for example a legendary unit or a one-of artifact. Their `text` says "Unique".
   - **Colorless:** at least 2 cards with colored pips and `"colorless": true`, for example an artifact that costs `3D` but that no `color` filter matches. Their `text` says "Colorless".
   - Every `text` says what the card's abilities do, in the style of the existing cards.
2. A Leader, `leader.<name>.json`, with `"set": "mechanics"`, a generic-only cost and an `onUse` ability whose `cost` has the pips of two colors. Its color allowance is those two colors (T-043).
3. `packages/cards/test/sets/mechanics.test.ts`: over `loadCards()`, the cards with `set === 'mechanics'` are 24 main-deck cards and 1 Leader, the counts in Deliverable 1 hold, no main-deck card's `usageColors` has two colors, no ability uses `script`, at least 2 non-Leader cards are Unique, and the Leader's `colorAllowance` has two colors while its cost has none.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm cards:validate` passes
- [ ] `git diff --diff-filter=MDR --name-only main...HEAD` prints nothing: this task only adds files

## Out of scope

- New effects, keywords or scripts. If an idea needs one, drop the idea and list it in the PR.
- Editing existing cards, decks or fixtures. The decks come with T-061.
- Banish, sacrifice, dump, revive, Shield, Extra life and Ward cards: T-057 and T-058 have them. A card here may use one, but it isn't counted.

## Notes

- Content tasks run alongside the rules tasks (docs/tasks/README.md › M3). Add files only. A duplicate id fails `cards:validate`: if a set that merged meanwhile took one of your ids, rename yours after the rebase.
- Default: the set is `mechanics`, not a color's set name, so the color sets' tests (T-054, T-057, T-058) keep their exact counts.
- Traps are free-standing only (T-044): give each trap an `area` and an area trigger.
- Rest and fear that reach enemies are offensive-only, as the side rules say (T-042, T-052). The prize is never a target (T-048).
- The M2 soak builds generated decks around every Leader, this one too. If it fails because a bot can't handle a legal card, send `lead` a `question` instead of changing the card.
- Default names are yours: keep them distinct from existing card names (`ls packages/cards/data/*`).
