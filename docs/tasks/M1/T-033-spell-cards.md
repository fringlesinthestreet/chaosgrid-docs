---
id: T-033
title: Spell classes in card data
milestone: M1
depends_on: [T-026, T-030]
branch: agent/T-033-spell-cards
scope:
  - packages/cards/**
  - packages/db/test/fixtures/cards/sorceries/**
---

# T-033 — Spell classes in card data

## Goal

Every spell says its class (utility, defensive or offensive) in the card data, and the validator holds each class to its limits. This covers sorcery cards and resources' Rest abilities. The protocol and core switch over in T-034.

## Read first

- docs/RULES.md: Round structure (Plan, Simulate), Simulation rules › Tick 0, Non-unit permanents › Sorceries and spells
- docs/tasks/M1/README.md › Spells
- packages/cards/README.md (card format, DSL, targets and zones)

## Deliverables

1. `SPELL_CLASSES`: `utility`, `defensive`, `offensive`. A `spell` field on sorcery cards and on abilities with the `onRest` trigger (a resource's Rest ability).
   - The file validator (`pnpm cards:validate` and `loadCards`) requires it on every sorcery and Rest ability.
   - In `CardSchema`'s TypeScript type it stays optional, so test cards in core keep compiling until T-034 makes it required.
2. The validator holds each class to its limits (RULES.md › Sorceries and spells), with messages that name the broken rule:
   - utility: no `damage` or `kill` effect; every target and zone is the caster's own side (the caster, its units, squads, cells, rows, permanents, hand or resources); no `every` or `at` trigger and no duration in seconds, since it resolves during Plan
   - defensive: every target and zone is the caster's own grid or permanents, or the caster
   - offensive: no limit on targets; the caster's own permanents are allowed
3. Rituals are merged into sorceries: the validator rejects a card of type `ritual` in `data/` with "a ritual is a utility sorcery now". The `ritual` type itself stays in the schema until T-034 removes it together with the protocol.
4. Every sample sorcery and Rest ability gets a class that fits its text and passes the limits, for example Relocate utility, Kindle defensive, Scorch Line offensive. Fog of War's text becomes "No defensive or offensive sorceries this round (utility sorceries still allowed). Trample damages friendly units". Its `noSorceries` rule keeps its name, and T-034 limits it to those two classes.
5. Give the db test fixture `packages/db/test/fixtures/cards/sorceries/kindle.json` its class, the same as the sample.
6. README: the spell model (classes, limits and when each resolves), the field in the format tables, and examples that `readme.test.ts` keeps valid. Valid and invalid fixtures for each limit.

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green
- [ ] `pnpm cards:validate` passes for every sample card and rejects the new invalid fixtures
- [ ] A second `pnpm db:seed` in a row changes nothing

## Out of scope

- The protocol, the bots and core (T-034), and new cards (T-029).

## Notes

- The class is the designer's call within the limits. As a guide: utility sets things up (draw, ramp, extra units, moving your own units), defensive protects or strengthens your side (buffs, heals, keywords), and offensive hurts or hinders anyone else. List each sample card's class in the PR body.
- Undertow reveals an opponent's traps and draws a card, so it's offensive, and its draw happens at tick 0.
