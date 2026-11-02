---
id: T-018
title: Remaining effects and scripts
milestone: M1
depends_on: [T-016, T-025, T-028]
branch: agent/T-018-effects-rest
scope:
  - packages/core/src/effects/**
  - packages/core/test/fixtures/effects/**
---

# T-018 — Remaining effects and scripts

## Goal

Finish the effect DSL: every effect T-016 left out, the round rules, and the hand-written scripts, so that every sample card does what its text says.

## Read first

- packages/cards/README.md (the DSL), and `packages/core/src/effects/` (T-016's engine and registry)
- docs/RULES.md: the sample cards, and Chaos deck and Emblems (rule-changing cards)
- docs/tasks/M1/README.md: the Hitting flyers and Buffs on one stat defaults

## Deliverables

1. Handlers, registered through T-016's registry, for:
   - `push` and `move`
   - `spawn` (for example Dominic's Cinder Grunts, which are destroyed at the end of the round), on cells from `freeCellsNear` (T-028)
   - `draw`: cards, and resources with `"what": "resource"` (ramp)
   - `reveal`, `rest`, `spendAttachedResources`
   - `grantKeyword`, with `effectiveKeywords(state, unit)`: printed plus granted. Trample's flyer check reads it instead of the printed Reach, and so does combat's targeting stats (T-020).
   - `buff` on player stats (`resourceDraw`, `cardDraw`, `pointsGained`, `pointsPerOpponentUnitKilled`, `firstLevelUpCost`), feeding the draw modifiers (zones), T-014's scoring modifiers and level-up costs
   - `setRule` (`noSorceries`, `trampleHitsFriendlyUnits`, `noHandSizeLimit`)
2. Round rules: the list of rule modifiers active this round, which other modules query. Examples: no resource draw, double Speed, Artillery disabled, traps fire twice, no sorceries, Trample hits friendly units.
3. A Durability heal (T-016's `heal` with `"stat": "durability"`) also emits `squad.durabilityChanged` (T-025).
4. `settlePlanDraws(ctx, seat)`: when a player stat such as `resourceDraw` or `cardDraw` has gone up since this round's Plan draw (Jaksho charged by an `attach`), the seat draws the difference right away. It's safe to call after every action, and plan/ calls it through a hook (T-021).
5. Scripts for the abilities the DSL can't express (today `mirror_ward`, which replaced M0's `redirect`, and `raider_pack`), each in its own file.
6. A coverage test: every ability of every sample card has a handler and runs on a small board without errors.

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green
- [ ] The coverage test passes for every sample card in `packages/cards/data/` (T-029 adds more)

## Out of scope

- When effects run within a tick (T-020), and the Chaos deck itself (T-019).
- A `level` effect: no sample card uses one, so the DSL has none (T-010).
