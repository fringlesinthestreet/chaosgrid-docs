---
id: T-005
title: Sample cards: spells, traps, artifacts, resources
milestone: M0
depends_on: [T-003]
branch: agent/T-005-cards-spells-resources
scope:
  - packages/cards/data/rituals/**
  - packages/cards/data/sorceries/**
  - packages/cards/data/traps/**
  - packages/cards/data/artifacts/**
  - packages/cards/data/enchantments/**
  - packages/cards/data/resources/**
---

# T-005 — Sample cards: sorceries, traps, artifacts, enchantments, resources

## Goal

Copy the RULES.md sample non-unit cards and resources into card JSON.

## Read first

- packages/cards/README.md (the format: follow it exactly)
- docs/RULES.md: Non-unit permanents, Resources and attaching, and Sample cards → Sorceries, Traps, Artifacts and enchantments, Resources

## Deliverables

- One file per card:
  - the 6 sorceries
  - the 5 traps
  - the 5 artifacts and enchantments
  - the 8 resource kinds: Volcano, Ocean, Prism, Ember Vent, Tide Pool, Underwater Volcano, Old Library, Harvest Cycle
- `text` is the rules text word for word. Fix only obvious typos (for example "volvano"), and list each one.

## Acceptance

- [ ] `pnpm cards:validate` green
- [ ] 24 files
- [ ] The PR body lists every interpretation you made, plus the resource "Count" values (see Notes)

## Out of scope

- The schema and the README in `packages/cards`. If the format can't express a card, send lead a `request`.
- Units, leaders and Chaos cards (T-004, T-006).

## Notes

Unless lead answers otherwise, use these defaults:

- The resources table's "Count" column describes the composition of a resource deck. It belongs to the starter decks (M3), not to the cards. Put the counts in the PR body so M3 can use them.
- The artifacts table's "Type" column is the attachment mode:
  - Whetstone and Barnacle Plate are attached.
  - Furnace Core, Tide Clock and Siege Beacon are free-standing.
- RULES.md doesn't say which of those five are artifacts and which are enchantments. Use `artifact` for all five and flag it.
- There are no sample rituals, so `rituals/` stays empty unless lead says otherwise. Flag Undertow (draw a card) and Relocate (move a unit): they read like Plan-time rituals, but they're listed as sorceries.
