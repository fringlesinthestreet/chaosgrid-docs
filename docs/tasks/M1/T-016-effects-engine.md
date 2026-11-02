---
id: T-016
title: Effects engine
milestone: M1
depends_on: [T-008, T-009, T-010]
branch: agent/T-016-effects-engine
scope:
  - packages/core/src/effects/**
  - packages/core/test/fixtures/effects/**
---

# T-016 — Effects engine

## Goal

Run card abilities: compute each unit's effective stats, apply damage, healing and timed buffs, and fire triggers, all following T-010's effect DSL. T-018 adds the rest of the DSL on top of this engine.

## Read first

- packages/cards/README.md: the DSL reference (T-010)
- docs/tasks/M1/README.md, packages/core/README.md and docs/PROTOCOL.md
- docs/RULES.md: Units (stats, Charge, Leveling, Keywords), Resources and attaching ("If charged"), Simulation rules (Damage and death, Trample)

## Deliverables

1. `effectiveStats(state, unit)`, combining:
   - level scaling: HP and Attack scale; Speed, Attack speed and Charge don't
   - static abilities and auras
   - timed buffs
   - "If charged" abilities, which apply when the attached resources reach the unit's Charge
2. An `effects` slice for active modifiers: source, target, stat, amount or factor, expiry tick, maximum stacks.
3. Damage and death:
   - `dealDamage(ctx, source, target, amount)`, crediting the kill to the source's owner
   - `heal` and `kill`
   - deaths are reported, not resolved: combat decides when they take effect
4. Trample: `trampleTargets(state, hit, area)` returns the enemies within `config.trampleRadius` cells (default 1) of the unit that was hit, or within the printed area.
5. Triggers:
   - `fire(ctx, trigger, payload)` for `onEnter`, `onAttack`, `onDeath`, `onKill`, `onDestroyed`, `onRoundEnd`, `onRest` and `onDraw`
   - per-tick scheduling for `every` and `at`
   - the conditions `charged` and `survived`
6. The effects `buff` on unit stats (`amount`, `factor` and `set`, including `damageTaken`), `damage`, `heal` (HP, and Durability with `"stat": "durability"`) and `kill`, each emitting the matching protocol events through `ctx.emit`.
7. A registry where T-018 and the scripts add effect handlers, each in its own file.
8. Tests:
   - every stat rule, and buff expiry and stacking
   - Charge switching abilities on and off
   - kill credit, and trample areas
   - every trigger type

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green

## Out of scope

- `push`, `move`, `spawn`, `draw`, `reveal`, `rest`, `grantKeyword`, `setRule`, `spendAttachedResources`, `buff` on player stats, round rules and scripts (T-018).
- The order things happen within a tick (T-020).
