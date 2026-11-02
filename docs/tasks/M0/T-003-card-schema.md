---
id: T-003
title: Card schema and validator
milestone: M0
depends_on: [T-001]
branch: agent/T-003-card-schema
scope:
  - packages/cards/**
---

# T-003 — Card schema, loader and validator

## Goal

Define the card JSON format and its validator. Once this merges, three data tasks (T-004, T-005, T-006) and the DB seed (T-007) start in parallel. This card fixes the format; the data tasks only fill it in.

## Read first

- docs/RULES.md, these sections:
  - Units (stats table, keywords)
  - Leader
  - Non-unit permanents
  - Resources and attaching
  - Chaos deck and Emblems
  - every table under Sample cards
- docs/DECISIONS.md: D5, D7, D10, and import rule 6
- docs/ARCHITECTURE.md: Card JSON (v1 sketch)

## Deliverables

1. `@chaosgrid/cards`, following the internal-package pattern. Its only runtime dependency is `zod`; add `tsx` for the CLI.
2. Zod schemas forming a discriminated union on `type`, covering `unit`, `leader`, `ritual`, `sorcery`, `trap`, `artifact`, `enchantment`, `resource` and `chaos`. The common fields are `id`, `name`, `type`, `set`, `version`, `cost` and `text` (ARCHITECTURE.md › Card JSON). Per kind:
   - **Cost:** a pip string such as `"0"`, `"3"`, `"E"`, `"1E"`, `"2EE"` or `"2ET"`, plus `parseCost()` returning `{ generic, colors: { E, T } }`. Declare the colors in one list, so adding a third color is a one-line change.
   - **Units and leaders:** the RULES.md stats:
     - HP and Attack
     - Attack speed in hits per second
     - Speed in cells per second
     - range class
     - Charge
     - size `[w, h]`
     - units per squad
     - Durability (units only, not leaders)
     - keywords with parameters, such as `blocker: 2` or `"{level}"`
     - the level-unlock condition

     Leaders also carry their leader bonus.
   - **Traps:** trigger and area.
   - **Artifacts and enchantments:** attached or free-standing, durability, area.
   - **Resources:** which colors they give, plus an optional ability.
   - **Chaos:**
     - `tier` (1–3)
     - kind (`units`, `rule`, `emblem` or `nothing`)
     - spawn target
     - points
     - the RULES.md "Amount" column
   - **`abilities`:** structured enough to hold the sample cards: `trigger`, `effect`, parameters, the `{level}` and `{unitLevel}` placeholders, or `script: "<id>"` for a hand-written effect. Keep it loose, because M1 designs the effect DSL. `text` stays the readable source of truth either way.
3. Data layout, which T-004 to T-007 depend on:
   - path: `packages/cards/data/<folder>/<slug>.json`, one card per file, with `id = "<type>.<slug>"`
   - folders: `units`, `leaders`, `rituals`, `sorceries`, `traps`, `artifacts`, `enchantments`, `resources`, `chaos`
   - ship `data/` empty, with a `.gitkeep`
4. Two entry points, because core and the web UI import this package in the browser (DECISIONS.md, import rule 6):
   - `@chaosgrid/cards` (`src/index.ts`), browser-safe with no Node built-ins: the schemas, types, `parseCost()`, and `indexCards(cards)` (returns a `Map` from id to card).
   - `@chaosgrid/cards/node` (`src/node/`), Node-only: `loadCards(dir = <package>/data)` reads every `*.json` under `dir`, validates it and returns typed cards. On an error it throws with the file path and the Zod issue path. The CLI lives here too.
5. A `validate` CLI, run as `pnpm cards:validate` from the root or `pnpm --filter @chaosgrid/cards validate <dir>`. It reports every problem in every file, one line per problem with the path. Problems include schema errors, duplicate ids, a file name that differs from the slug, and a folder that doesn't match the type. It exits 1 if it finds any.
6. `packages/cards/README.md`: the format guide the data tasks follow. It contains:
   - a field reference per kind
   - the cost syntax
   - one complete example per kind, taken from RULES.md (for example Flame Lancer, Vask, Kindle, Spike Pit, Whetstone, Volcano, Rat Swarm)
   - the `set` and `version` values to use (`"base"`, `1`)
   - how to run the validator
7. Tests:
   - The README examples parse. Keep them as fixtures under `test/fixtures/valid/`.
   - Every file in `test/fixtures/invalid/` is rejected with a message that names the file and the field. Include a missing field, a bad cost string, an unknown keyword, a duplicate id, a wrong folder, and a file name that doesn't match its slug.

## Acceptance

- [ ] `pnpm cards:validate` exits 0 (with an empty `data/`)
- [ ] `pnpm --filter @chaosgrid/cards validate test/fixtures/invalid` exits 1 and lists every invalid fixture
- [ ] `pnpm lint && pnpm typecheck && pnpm test` green

## Out of scope

- Adding the sample cards to `data/`: that's T-004, T-005 and T-006.
- Deck rules (M3), the semantics of the effect DSL (M1), and anything in `packages/db`.

## Notes

- RULES.md is a draft with ambiguities. Model what it says, and keep fields optional where it says nothing. List every judgment call under "Open questions" in the PR body. If a judgment call changes the format, send it to lead as a `question` before you build on it.
- Model these known ambiguities so that either answer fits, because the data tasks will run into them:
  - The Units table's "Squad Size" column looks like the footprint Size, and "Units per card" looks like the squad count.
  - The artifacts table's "Type" column says Attached or Free-standing, not artifact or enchantment.
  - Leaders have no Durability.
  - The Chaos "Amount" values don't add up to the "20-card Chaos deck" totals.
