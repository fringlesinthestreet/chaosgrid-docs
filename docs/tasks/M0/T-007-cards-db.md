---
id: T-007
title: Cards database and reseed
milestone: M0
depends_on: [T-003]
branch: agent/T-007-cards-db
scope:
  - packages/db/**
---

# T-007 — Cards DB and the reseed command

## Goal

Implement D10–D12. A single command, `pnpm db:seed`, builds or rebuilds the cards table from the JSON directory, and running it again changes nothing.

## Read first

- docs/DECISIONS.md: D10, D11, D12
- docs/PLAN.md: M0
- packages/cards/README.md and `loadCards()` from `@chaosgrid/cards/node` (T-003)

## Deliverables

1. `@chaosgrid/db` with `drizzle-orm` and `better-sqlite3`, `drizzle-kit` for migrations, and `@chaosgrid/cards` as a `workspace:*` dependency.
2. DB location: the `CHAOSGRID_DB` environment variable, falling back to `<repo root>/.data/chaosgrid.db`. Create `.data/` if it's missing (git already ignores it). `:memory:` must work.
3. Schema v1:
   - `players`: `id` (integer primary key), `name`, `created_at`. Seed row `0` as "Local player", and export `LOCAL_PLAYER_ID = 0`.
   - `cards`: `id` (text primary key), `type`, `name`, `set`, `version`, `cost`, `data` (the full validated card as JSON), `content_hash`, `retired_at` (nullable), `updated_at`.
   - No deck tables yet (M3).
4. Migrations generated with drizzle-kit and committed under `packages/db/migrations/`.
5. Two scripts (T-001's root scripts already call them):
   - `migrate` applies the migrations.
   - `seed [--dir <path>]` runs these steps:
     1. Apply the migrations.
     2. Make sure player 0 exists.
     3. Call `loadCards(dir)` from `@chaosgrid/cards/node`. The default directory is the cards package's `data/`.
     4. In one transaction:
        - insert new cards
        - update cards whose `content_hash` changed
        - set `retired_at` on cards that are no longer in the JSON
        - clear `retired_at` on cards that came back
     5. Print `inserted N, updated N, unchanged N, retired N, restored N`.

     The seed never deletes a row, because decks will point at cards. If any card is invalid, it prints the errors, exits 1 and writes nothing.
6. Exports: `openDb(path?)`, the Drizzle schema, `seedCards(db, cards)` (returns the counts), and `LOCAL_PLAYER_ID`.
7. Tests, on `:memory:` with fixture cards owned by this package. Don't use `packages/cards/data`, which T-004 to T-006 are still filling. Cover:
   - the first seed inserts everything
   - a second run reports everything `unchanged`
   - editing one card updates only that card
   - removing a card retires it, and restoring it brings it back
   - one invalid card means nothing is written
8. `packages/db/README.md`: the commands, `CHAOSGRID_DB`, how reseeding works, and how to open the DB in a SQLite viewer.

## Acceptance

- [ ] On a fresh checkout, run `pnpm db:seed` twice. The second run reports 0 inserted and 0 updated.
- [ ] `pnpm lint && pnpm typecheck && pnpm test` green
- [ ] Nothing gets written outside `.data/`, and `.data/` stays untracked

## Out of scope

- Deck tables and the API (M3).
- Changing the card schema. Ask lead.

## Notes

- `better-sqlite3` is a native module. If it won't install, send lead a `question` instead of quietly switching drivers.
- In M0, this is the only task that touches `packages/db/migrations/`. The lead runs later schema tasks one at a time.
