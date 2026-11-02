---
id: T-029
title: More sample cards
milestone: M1
depends_on: [T-018, T-026, T-030, T-033]
branch: agent/T-029-more-cards
scope:
  - packages/cards/data/**
  - packages/cards/src/spells.test.ts
  - packages/cards/src/dsl.test.ts
  - packages/core/src/view/cards.test.ts
---

# T-029 — More sample cards

## Goal

Fill the gaps in the sample set, so the M1 sims and the starter decks (T-031) exercise every mechanic. Today there are no rituals and no enchantments, no unit seeks Emblems, no squad has more units than its footprint has cells, and Trample has only one projectile.

## Read first

- packages/cards/README.md (card format, DSL, the `projectile` field from T-026, spell classes from T-033)
- docs/RULES.md: Units (the stat ranges), Non-unit permanents, Chaos deck and Emblems, Balance knobs
- the existing cards in `packages/cards/data/`

## Deliverables

1. About 16 new cards, data only, with the effects, targets and triggers the DSL already has (no new scripts):
   - 3 utility sorceries (rituals are merged into sorceries), for example ramp, card draw and extra units, plus at least one defensive and one offensive sorcery
   - 2 enchantments: one attached, one free-standing
   - a unit that seeks Emblems, and a unit with an On enter ability (no sample uses `onEnter` yet)
   - sorceries that aim at something (a unit, a row, an area or a seat), not only untargeted ones
   - a squad with more units than its footprint has cells, for example a 1×1 swarm of 3
   - 2 Ranged or Artillery units with projectile kinds the samples use least, one of them with Trample
   - enough one-color cards for the starter decks (T-031). Today an Ember Leader can play only 14 distinct main deck cards (Ember or colorless), and a Tide Leader also 14, but a 40-card deck at 2 copies needs 20. Add at least 8 for each side, so each has 22 or more. Colorless cards count for both.
2. Stats inside RULES.md's ranges (Units table). `set` is `"base"` and `version` is 1.

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green, including T-018's coverage test, which runs every sample card on a small board
- [ ] `pnpm cards:validate` passes
- [ ] The PR body gives the counts of distinct main deck cards an Ember-only Leader and a Tide-only Leader can play (deck rules, T-030): each at least 22
- [ ] A second `pnpm db:seed` in a row changes nothing

## Out of scope

- New effects or scripts: a card the DSL can't express waits for M4.
- Balance (M4).

## Notes

- Three tests list the sample cards by name: the spell classes (`spells.test.ts`), the caster choices and the one unused trigger (`dsl.test.ts`), and the TargetSpecs (core's `view/cards.test.ts`). Add the new cards to those lists, and change nothing else in them.
- RULES.md's sample tables aren't updated: the JSON files are the source of truth (D10). List the new cards, with a one-line summary each, in the PR body.
