---
id: T-031
title: Starter decks
milestone: M1
depends_on: [T-029, T-030, T-034]
branch: agent/T-031-starter-decks
scope:
  - packages/cards/decks/**
  - packages/cards/src/node/**
  - packages/cards/test/fixtures/starter/**
  - packages/cards/README.md
---

# T-031 — Starter decks

## Goal

Two legal decks ship with the game, Ember aggro and Tide control. Bots use them now, and new players get them in M3. This is pulled forward from M3.

## Read first

- docs/PLAN.md › M3 (Decks)
- packages/cards/README.md, including the deck rules (T-030)
- the sample cards, including T-029's
- `packages/core/test/fixtures/zones/` (T-015): two 40-card test decks, a useful starting point

## Deliverables

1. One JSON file per deck in `packages/cards/decks/`: an id (`starter.ember_aggro`, `starter.tide_control`), a name, the Leader, and the main and resource decks as card ids with counts.
2. `loadStarterDecks()` in `@chaosgrid/cards/node`. It reads and parses the files, expands the counts into a `Deck` (T-030), and fails with a clear message on a bad file.
3. `pnpm cards:validate` also validates every starter deck with `checkDeck`, and reports problems the way it does for cards.
4. Each deck plays to its plan:
   - Ember aggro: cheap fast units, Trample and damage sorceries, with a fire Leader
   - Tide control: Blockers, Reach, Artillery and traps, with a Tide Leader
   - both use some of T-029's utility sorceries and enchantments
5. Tests: both decks load and are legal, and a broken deck file (in `test/fixtures/starter/`) is reported.
6. README: a short "Starter decks" section (the file format, `loadStarterDecks`, what `cards:validate` checks), and the new `@chaosgrid/cards/node` exports in the entry points table. T-032 reads it.

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green
- [ ] `pnpm cards:validate` passes, and lists the two starter decks it checked

## Out of scope

- Seeding decks into the DB (T-032), and tuning them with sim reports (M4).
