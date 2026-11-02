---
id: T-059
title: Dual Leaders and resources
milestone: M3
depends_on: [T-054, T-057, T-058]
branch: agent/T-059-dual-leaders
model: sonnet
effort: medium
scope:
  - packages/cards/data/**
  - packages/cards/test/sets/duals.test.ts
  - packages/core/src/zones/resources.test.ts
context:
  - docs/PLAN.md#M3
  - docs/RULES.md#Resources and attaching
  - docs/RULES.md#Resources (30-card deck)
  - docs/tasks/README.md#M3
  - packages/cards/README.md#Leaders
  - packages/cards/README.md#Resources
  - packages/cards/README.md#Effects
  - packages/cards/README.md#Targets
---

# T-059 — Dual Leaders and resources

## Goal

Every pair of colors that includes a new color gets a Leader and a two-color resource: Ember–Earth, Ember–Dark, Ember–Light, Tide–Earth, Tide–Dark, Tide–Light, Earth–Dark, Earth–Light and Dark–Light. That makes 9 Leaders and 9 resources, so a deck can be built around any of them.

## Interfaces

What exists after T-054, T-057 and T-058:

```ts
// packages/cards/data/resources/underwater_volcano.json, the Ember–Tide dual, with T-041's letters:
{ "id": "resource.underwater_volcano", "name": "Underwater Volcano", "type": "resource", "set": "base",
  "version": 1, "cost": "0", "text": "When drawn is rested", "colors": ["R", "T"], "gives": ["R", "T"],
  "abilities": [{ "trigger": "onDraw", "effect": "rest", "target": "self" }] }
// Leaders: packages/cards/data/leaders/*.json (Jaksho, Cultivator is the Ember–Tide one).
// Mechanics from T-042 to T-053: Plan abilities and rest, banish, sacrifice, dump, revive, Shield,
// Extra life, Ward and fear. Copy (T-053) runs alongside this task: don't use it.
// T-043: a Leader's color allowance is the pips of its cost and of its onUse abilities' costs.
```

Nothing new is exported.

## Deliverables

1. 9 Leaders with `"set": "duals"`, one per pair above. Each one's cost has one pip of each of its two colors (for example `"1RE"` for Ember–Earth), and its abilities mix what both colors do. Its color allowance must be exactly its pair: an `onUse` ability's cost may only use the pair's pips.
2. 9 resources with `"set": "duals"`, one per pair, shaped like Underwater Volcano: `colors` and `gives` are the pair, and each has a drawback (enters rested, or something as costly).
3. `packages/cards/test/sets/duals.test.ts`: the `duals` cards are 9 Leaders and 9 resources, each Leader's `colorAllowance` and each resource's colors are one of the 9 pairs, each pair has exactly one of each, and no ability uses `script`.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm cards:validate` passes
- [ ] `git diff --diff-filter=MDR --name-only main...HEAD` prints nothing: this task only adds files

## Out of scope

- Two-color main-deck cards: decks of a pair play both colors' mono cards
- New effects, keywords or scripts. If an idea needs one, drop the idea and list it in the PR.
- Editing existing cards, decks or fixtures

## Notes

- Content tasks run alongside the rules tasks (docs/tasks/README.md › M3). Add files only. A duplicate id fails `cards:validate`: if a set that merged meanwhile took one of your ids, rename yours after the rebase.
- It waits for the Earth, Dark and Light sets: generated decks (`tools/sim-cli/src/decks.ts`) need enough fitting main-deck cards to fill a deck at 4 copies each (1 for a Unique card), and an Earth–Dark, Earth–Light or Dark–Light Leader fits only the colorless cards without them.
- If the M2 soak fails because a bot can't handle a legal card, send `lead` a `question` instead of changing the card.
