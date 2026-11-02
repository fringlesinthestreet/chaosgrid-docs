---
id: T-006
title: Sample cards: Chaos deck
milestone: M0
depends_on: [T-003]
branch: agent/T-006-cards-chaos
scope:
  - packages/cards/data/chaos/**
---

# T-006 — Sample cards: Chaos deck

## Goal

Copy the RULES.md sample Chaos cards and Emblems into card JSON.

## Read first

- packages/cards/README.md (the format: follow it exactly)
- docs/RULES.md: Chaos deck and Emblems, Sample Chaos deck and Emblems (all three tiers)

## Deliverables

- One file per Chaos card in `packages/cards/data/chaos/`: 9 in tier 1, 7 in tier 2 and 5 in tier 3, for 21 files.

## Acceptance

- [ ] `pnpm cards:validate` green
- [ ] 21 files, each with the correct `tier`
- [ ] The PR body lists every interpretation you made, plus the per-tier draw rules (see Notes)

## Out of scope

- The schema and the README in `packages/cards`. If the format can't express a card, send lead a `request`.
- Deck-building rules for the Chaos deck: those are M1 engine work.

## Notes

Unless lead answers otherwise, use these defaults:

- "Amount" is the number of copies of the card in its tier. The header says "8 tier-1, 7 tier-2, 5 tier-3", but the Amount columns add up to different totals. Copy the Amounts as written and flag the mismatch.
- The per-tier draw counts ("{round} cards", "{round}-4", "2 cards") are deck rules for M1, not card data. List them in the PR body.
- "Leader" under "Spawns in front of" means the current point leader, not the Leader card.
