---
id: T-034
title: Spells in protocol and core
milestone: M1
depends_on: [T-020, T-021, T-033]
branch: agent/T-034-spells
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/bots/**
  - packages/cards/src/**
  - packages/cards/README.md
  - packages/cards/test/fixtures/valid/**
  - packages/cards/test/fixtures/invalid/**
  - packages/core/src/plan/**
  - packages/core/src/combat/**
  - packages/core/src/view/**
  - packages/core/src/effects/**
  - packages/core/src/zones/setup.ts
  - packages/core/src/zones/setup.test.ts
  - packages/core/src/zones/pay.test.ts
  - packages/core/test/fixtures/plan/**
  - packages/core/test/fixtures/combat/**
  - packages/core/test/fixtures/view/**
  - packages/core/test/fixtures/effects/**
---

# T-034 — Spells in protocol and core

## Goal

Play by the spell model. Utility spells resolve during Plan. Defensive and offensive spells wait for tick 0, defensive first. Rituals are gone as a separate card type. The change has to land in one PR, because removing the ritual type breaks the cards, the protocol, the bots and core together.

## Read first

- docs/RULES.md: Round structure, Simulation rules › Tick 0, Non-unit permanents › Sorceries and spells
- docs/tasks/M1/README.md › Spells, and the `spell` field in packages/cards/README.md (T-033)
- docs/PROTOCOL.md (plan actions, `ritual.resolved`, `sorcery.resolved`, `plans.revealed`, `HandCard`, visibility)
- packages/core/src/plan/, combat/, view/ and effects/ (T-021, T-020, T-022, T-016, T-018)

## Deliverables

1. **Cards:**
   - `ritual` leaves the card types and folders
   - `spell` becomes required in `CardSchema` for sorceries and Rest abilities
   - the deck rules' main deck types (T-030) and `createGame`'s (`zones/setup.ts`) follow
   - test cards that break are fixed
2. **Protocol v4:**
   - `castSorcery` (card, target) replaces `castRitual` and `queueSorcery`
   - `HandCard` loses the `ritual` type and carries the sorcery's `spell` class; a pool resource carries its Rest ability's class
   - a utility spell that resolves during Plan stays private to its seat until `plans.revealed` lists it, as `ritual.resolved` does today: rename or reshape that event to fit
   - `PROTOCOL_VERSION` goes to 4, with docs/PROTOCOL.md and the bots' fixtures updated
3. **Bots:** the random bot casts sorceries with `castSorcery`.
4. **Plan (core):**
   - `castSorcery` pays, then a utility spell resolves at once, so later actions in the same plan can use what it gave. A defensive or offensive spell is queued with its class.
   - `useResource` does the same for a Rest ability, by its class
   - `noSorceries` (Fog of War) blocks defensive and offensive sorceries only
5. **Combat (core):** tick 0 resolves every queued defensive spell, then every queued offensive one. Units act from tick 1. A conflict inside a step still goes kill first.
6. **View and effects (core):** the snapshot shows each card's class. Hidden plans cover utility spells. `resolveCard` handles sorceries and traps only.
7. **Tests:**
   - a utility sorcery's result used by a later action in the same plan
   - defensive before offensive at tick 0, for example a heal that resolves before the damage
   - Fog of War blocking only defensive and offensive sorceries
   - a utility spell staying hidden from other seats until the reveal
   - every plan action and event parsing under protocol v4

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green
- [ ] `pnpm cards:validate` passes

## Out of scope

- New cards (T-029), and the round loop (T-023), which wires this module's hooks after it merges.

## Notes

- This PR is wide. Commit one package at a time (cards, protocol, bots, then core), and say in the PR body where each part is.
- The class limits are checked when cards are validated (T-033), so core trusts the card data and doesn't check them again.
