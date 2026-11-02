---
id: T-010
title: Effect DSL v1
milestone: M1
depends_on: [T-003, T-004, T-005, T-006]
branch: agent/T-010-effect-dsl
scope:
  - packages/cards/**
---

# T-010 — Effect DSL v1

## Goal

Replace M0's loose ability format with a typed effect DSL that covers every sample card, so core can run abilities without guessing what a field means. The DSL is the contract between the card data and the effects engine (T-016, T-018).

## Read first

- docs/RULES.md: Units (Keywords, Leveling), Non-unit permanents, Resources and attaching, Chaos deck and Emblems, every sample card table
- docs/DECISIONS.md: D5, D7
- packages/cards/README.md, `src/schema.ts`, and every file in `packages/cards/data/`

## Deliverables

1. Typed schemas, in `src/schema.ts` or a new `src/dsl.ts`:
   - **Triggers:** the vocabulary the data already uses (`static`, `onEnter`, `onAttack`, `onDeath`, `onKill`, `onDestroyed`, `every`, `at`, `onRoundEnd`, `onRest`, `onDraw`), each with its own parameters (`every` takes seconds, `at` takes a second).
   - **Effects:** a discriminated union on `effect`, one schema per effect with typed parameters. The data uses `buff`, `damage`, `heal`, `setStat`, `push`, `spawn`, `draw`, `reveal`, `restore`, `rest`, `kill`, `grantKeyword`, `preventDamage`, `redirect`, `move`, `reduceCost`, `forbidCast`, `setRule`, `removeHandSizeLimit` and `spendAttachedResources`. Merge synonyms where that makes the DSL smaller (for example, `setStat` as a `buff` with a factor), and note each merge in the README.
   - **Shared vocabularies:**
     - targets: self, the attacked unit, the killer, the attached unit, the nearest enemy, enemies or allies within a radius or area, a grid row, all enemies, …
     - durations: round, seconds
     - conditions: charged, …
     - filters
   - **Trap triggers**, typed the same way.
2. Every card in `data/` migrated to the typed DSL, with `text` unchanged. `pnpm cards:validate` stays green. Abilities the DSL can't express keep a `script` id; today those are `mirror_ward` and `raider_pack`. List them in the README.
3. A DSL reference in the README, which T-016 and T-018 implement against: each trigger, effect, target, duration and condition, with an example from the sample cards.
4. Tests:
   - one valid sample per effect and per trigger
   - unknown effects, triggers and parameters are rejected
   - every data card validates

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green
- [ ] `pnpm cards:validate` green, and `pnpm db:seed` still seeds all 62 cards
- [ ] The README lists every effect, trigger and target, and every remaining script id

## Out of scope

- Running effects (T-016, T-018) and new cards (M4).

## Notes

- Keep amounts in card units: seconds, hits per second, cells per second (D7). Core converts them.
- Migrating the data changes the cards' content hashes, so the next seed updates every row. That's expected.
