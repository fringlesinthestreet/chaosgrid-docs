---
id: T-032
title: Decks database
milestone: M1
depends_on: [T-007, T-031]
branch: agent/T-032-decks-db
scope:
  - packages/db/**
---

# T-032 — Decks database

## Goal

Store decks, owned by player `0` (D12), and seed the starter decks with the cards. The API (M3) builds on this. This is pulled forward from M3.

## Read first

- docs/DECISIONS.md: D10, D11, D12
- packages/db/README.md, and the `cards` table and seed command (T-007)
- packages/cards/README.md: the deck rules (T-030) and starter decks (T-031)

## Deliverables

1. A Drizzle migration with two tables:
   - `decks`: id, owner (player `0`), name, Leader card id, the starter deck id it came from (or null), created and updated times
   - `deck_cards`: deck id, card id, pile (`main` or `resources`), count
2. `pnpm db:seed` also upserts the starter decks from `loadStarterDecks()`. A second run in a row changes nothing.
3. Helpers for the API (M3): `listDecks(db, owner)`, `getDeck(db, id)`, `saveDeck(db, owner, deck)` and `deleteDeck(db, id)`.
   - `getDeck` returns the `Deck` plus its `checkDeck` problems, with retired cards marked retired.
   - A deck that uses a retired card loads fine and is reported illegal. It never breaks (PLAN.md › M3).
4. Tests on `:memory:`: the migration, seeding twice, a round trip through `saveDeck` and `getDeck`, deleting, and a deck that uses a retired card.

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green
- [ ] On a fresh DB, `pnpm db:seed` twice in a row: the second run reports no changes, and the two starter decks are in `decks`

## Out of scope

- The HTTP API and the deck builder (M3).
- Decks for bots in sims (they load the starter decks directly).

## Notes

- This is the only task touching `packages/db/migrations/**` (docs/tasks/README.md, rule 3).
