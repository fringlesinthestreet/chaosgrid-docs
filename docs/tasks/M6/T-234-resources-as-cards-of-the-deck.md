---
id: T-234
title: Resources as cards of the deck
milestone: M6
depends_on: [T-223, T-225]
branch: agent/T-234-resources-as-cards-of-the-deck
model: opus
effort: high
scope:
  - packages/cards/src/**
  - packages/cards/README.md
  - packages/cards/data/resources/**
  - packages/cards/decks/**
  - packages/cards/test/**
  - packages/cards/stats/**
  - packages/db/**
  - packages/http/src/**
  - apps/api/src/**
  - apps/web/src/decks/**
  - apps/web/src/lobby/**
  - apps/web/src/host/host.ts
  - apps/web/src/host/host.test.ts
  - apps/web/src/i18n/en/decks.json
  - apps/web/src/i18n/en/lobby.json
  - apps/web/e2e/**
  - apps/web/README.md
  - packages/core/src/zones/**
  - packages/core/src/effects/**
  - packages/core/src/view/cards.test.ts
  - tools/sim-cli/src/**
  - tools/sim-cli/test/golden-script.ts
  - packages/core/test/fixtures/zones/decks.ts
  - apps/web/src/host/bot-seats.test.ts
  - apps/web/src/match/planning/Zones.test.tsx
  - apps/web/src/api/fixture.test.ts
  - apps/web/src/i18n/en/deckEditor.json
  - apps/web/src/i18n/en/deckList.json
  - tools/sim-cli/test/planner.perf.test.ts
  - tools/sim-cli/test/scripted.ts
  - tools/sim-cli/test/snapshot-positions.test.ts
  - packages/core/test/fixtures/plan/cards.ts
  - packages/core/test/fixtures/effects/cards.ts
context:
  - docs/RULES.md#Resources and mana
  - docs/RULES.md#Components
  - docs/DECISIONS.md#Decision log
  - docs/APPS.md#HTTP API
  - packages/cards/README.md#Resources
  - packages/db/README.md
---

# T-234 — Resources as cards of the deck

## Goal

A deck is one list of 90 cards, resources included (D60, D85): the card files say which resources are basic, which enter rested and how much mana each gives; the deck rules, the starter decks, the DB, the HTTP API and the deck editor hold one pile. The game still plays as before this PR: the host splits the resources out of the deck for core until core takes them with the rest (T-235).

## Interfaces

On `main` (grep the names, the lines move).

- `packages/cards/src/schema.ts`: `ResourceCardSchema` has `colors` (identity), `gives` (`"any"`, a color list, or `[]` for one generic pip) and `unique`; "When drawn is rested" is only text today, read by core's `arrivesRested` (`zones/resources.ts`).
- `packages/cards/src/deck/check.ts`: `MAIN_DECK_SIZE = 100`, `RESOURCE_DECK_SIZE = 30`, `MAIN_DECK_TYPES`, `maxCopies`, and the problem codes `mainDeckSize`, `resourceDeckSize`, … `checkDeck` is what the API and the editor both run.
- `packages/cards/src/node/starter.ts`: `StarterDeck { leader, main: Record<CardId, number>, resources: Record<CardId, number> }` from `packages/cards/decks/*.json`, and `pile(RESOURCE_DECK_SIZE, 'a resource deck')`.
- `packages/db/src/schema.ts`: `deck_cards(pile IN ('main', 'resources'))`, `DECK_CARD_PILES`; `decks.ts` (`SavedDeck`, `DeckInput`, `saveDeck`, `getDeck`), `starters.ts` seeds the starters per pile. Schema changes are drizzle migrations: `pnpm --filter @chaosgrid/db generate` writes to `migrations/`.
- `packages/http/src/decks.ts`: `DeckBody { leader, main, resources }`, `DECK_PILES`, a problem's `pile`.
- `apps/web/src/decks/editor/`: `deck.ts` (`EMPTY_DECK`, `pileFor`, `addCard`, `pileRows`), `DeckPanel.tsx` draws the two piles, `problems.ts` (`fixFor`, `applyFix`), `QuickAdd.tsx`. The lobby reads `deck.main` and `deck.resources` for a deck's key cards; `host.ts` passes `{ main: deck.main, resources: deck.resources }` to core's `createGame` (`SeatSetup`).

## Deliverables

1. **Card schema.** A resource card gains `entersRested?: true` (in place of the "When drawn is rested" text, which becomes "Enters rested") and `mana?: 0 | 2` (default 1: how many mana it gives a round). Export `isBasicResource(card)`: not Unique, no abilities, `mana` 1, no `entersRested`, `gives` one color or `[]`. Validation, with errors that cite D85: a resource with abilities that isn't Unique has `mana: 0`; a Unique resource with abilities has `mana` 1 and `gives: []`; a two-color `gives` has `entersRested`. The README's Resources section states the shape and the basic rule.
2. **Data.** The 29 resource files follow: the ten two-color resources get `entersRested` and the text "Enters rested"; Ember Vent and Tide Pool get `mana: 0` and keep only their "Rest: …" text; the five colored Harvest Cycles keep their `colors` but give `[]`, like Harvest Cycle and Old Library; Prism, Waystone and the one-color basics are unchanged. Bump each changed file's `version`.
3. **Deck rules.** One pile: `DECK_SIZE = 90`, `MAIN_DECK_TYPES` includes `resource`, `maxCopies` is unlimited for a basic resource, 1 for a Unique card and 4 otherwise (D26); `mainDeckSize` and `resourceDeckSize` become one `deckSize` problem, and a problem's pile is `leader` or `main`. `StarterDeck` has `main` only, and each starter in `packages/cards/decks/` is 90 cards: 30 resources (its color's basics, its Harvest Cycle, and the two-color resources of a two-color deck) and 60 others, keeping T-225's at least 24 units of cost 1 or 2.
4. **DB.** `deck_cards` loses `pile`: a migration moves the `resources` rows into the one pile and drops the column and its check; `SavedDeck`, `DeckInput` and `starters.ts` follow. Opening a DB with the old schema migrates it, and `pnpm db:seed` reseeds the starters.
5. **HTTP and API.** `DeckBody { leader, main }` and `DECK_PILES = ['leader', 'main']`; the routes and their tests follow. If `docs/APPS.md` › HTTP API needs a word about the deck shape, say so in the PR: the lead edits it.
6. **Deck editor and lobby.** One list of 90 with the resources in it, grouped by card type as the two piles were; the quick add offers resources too; problems and fixes follow the new codes; the lobby's key cards read `main`. The e2e deck test builds a legal 90-card deck.
7. **Host.** `host.ts` splits `deck.main` by card type into core's `{ main, resources }`, so a match plays exactly as before this PR.
8. **Tests:** the schema accepts each shape above and refuses each violation; `isBasicResource` says yes to Volcano and Waystone and no to Prism, Ember Vent, Underwater Volcano and Harvest Cycle; `checkDeck` accepts 90 cards with 30 Volcanos and refuses 89, 91 and five Flame Lancers; the migration runs on a DB file made from `main`'s schema; a saved deck round-trips through the API; the editor adds a resource to the one list.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm cards:validate` green
- [ ] `pnpm db:seed` green on a fresh DB and on a DB seeded from `main`
- [ ] `pnpm test:e2e` green

## Out of scope

- Core, the protocol, the bots and sim-cli: resources still arrive in the pool and rest for mana until T-235.
- The match screen (T-236) and the hand window (T-238).

## Notes

- The colored Harvest Cycles keep their color in `colors`, so they still need it in the Leader's allowance; only what they pay changes.
- `arrivesRested` reads the text today: make it read `entersRested` so the data has one source, and leave the rest of core alone.
- Leave `stats/` alone unless a key changes; the baseline (T-233) regenerates it.
