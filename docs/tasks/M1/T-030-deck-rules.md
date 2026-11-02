---
id: T-030
title: Deck rules
milestone: M1
depends_on: [T-026]
branch: agent/T-030-deck-rules
scope:
  - packages/cards/src/deck/**
  - packages/cards/src/index.ts
  - packages/cards/README.md
  - packages/cards/test/fixtures/decks/**
---

# T-030 — Deck rules

## Goal

Say whether a deck is legal, and list everything wrong with it, as a pure function the deck builder (M3), the DB (T-032) and the starter decks (T-031) all use. This is pulled forward from M3.

## Read first

- docs/RULES.md › Components and setup
- docs/PLAN.md › M3 (Decks)
- packages/cards/README.md and `src/cost.ts` (pips and colors)
- `packages/core/src/zones/setup.ts` (T-015): `createGame` takes a seat's `leader`, `main` and `resources`. A deck uses the same shape.

## Deliverables

1. `Deck`: `{ leader, main, resources }`, as card ids, with copies listed once each.
2. `checkDeck(deck, cards, { retired? })` returns every problem, not just the first. Each problem has a code, the card ids involved, and a message. It checks:
   - the main deck has 40 cards, with at most 2 copies of any card
   - the resource deck has 30 resources
   - the Leader is a Leader card
   - main deck cards are units, rituals, sorceries, traps, artifacts or enchantments, and the resource deck holds only resources
   - every card id exists and isn't retired
   - every card's colors are within the Leader's colors
3. Exported from `@chaosgrid/cards`, browser-safe, and documented in the README.
4. Tests, one per rule and with several problems at once, using fixtures in `test/fixtures/decks/`.

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green

## Out of scope

- The starter decks (T-031), storing decks (T-032), and the deck builder and API (M3).

## Notes

Defaults for questions RULES.md leaves open. List them in the PR's Open questions:

- The Leader's colors are the colored pips of its cost.
- A card's colors are its colored pips. Colorless cards fit any Leader.
- A resource's colors are the colors it gives. A two-color resource needs both colors in the Leader's. Prism and colorless resources fit any Leader.
- The 2-copy limit applies to the main deck only. Resources have no copy limit.
- The Leader can't also be in the main deck.
