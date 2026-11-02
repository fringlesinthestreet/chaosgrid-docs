---
id: T-008
title: Core skeleton and state model
milestone: M1
depends_on: [T-002, T-003]
branch: agent/T-008-core-skeleton
scope:
  - packages/core/**
---

# T-008 — Core skeleton and state model

## Goal

Create `@chaosgrid/core` with the shared pieces every other M1 task builds on: the state model, the seeded RNG, tick conversions, and one folder per module. With those in place, up to seven tasks can work in core at the same time without touching each other's files.

## Read first

- docs/CORE.md: the conventions this card turns into code
- docs/RULES.md: Components and setup, Round structure, Simulation rules, Units, Leveling, Resources and attaching, Non-unit permanents, Balance knobs
- docs/DECISIONS.md: D2, D7, D8, import rules 2 and 6
- packages/cards/README.md and `packages/cards/src/schema.ts`: the card types core consumes

## Deliverables

1. `@chaosgrid/core`, following the internal-package pattern. Its dependencies are `zod` (catalog), `@chaosgrid/protocol` and `@chaosgrid/cards` (workspace). It must be browser-safe; the ESLint zone for `packages/core` already applies.
2. A folder under `src/` for every module in CORE.md, each with an `index.ts` and a `state.ts`:
   - For the modules other tasks own, `state.ts` exports an empty `<Module>State` interface and `initial<Module>State()`, and `index.ts` exports nothing else yet.
   - `src/index.ts` re-exports `state`, `rng`, `view` and `round`, so no later task edits it.
3. `state/`:
   - `GameConfig` with the RULES.md knobs and their defaults: point target 30, rounds of 1000 ticks, 15×15 grids, 1 card and 2 resources drawn per round, a starting hand of 5 cards and 2 resources, hand limit 8, max level 9, Blocker default range 2, survival bonus 1, Chaos tiers starting at rounds 1, 6 and 11, extra Chaos when the leader is 10+ points ahead.
   - `GameState`: config, round, phase, tick, `rng`, `nextId`, `players` (seat, leader card instance, fractional points), `cards` (every card instance: id, card id, owner, zone), `squads`, `units`, `permanents`, and one field per module slice.
   - The shared entity types, built from RULES.md and the card schema:
     - `Squad`: owner, card instance, placement (grid cell, rotated, footprint), level, durability, roundsOnGrid, damageDealt, isLeader, attached resource instances
     - `Unit`: squad, owner (a seat or `chaos`), world cell, layer (ground or air), hp, alive
     - `Permanent`: a trap, artifact or enchantment instance, with owner, mode, attached squad or grid cells, hp, durability, faceDown, rested
   - Helpers every module needs:
     - `newId(state, prefix)`
     - `distance(a, b)`: Chebyshev
     - footprint cells and rotation
     - `levelScale(base, level)` = base × (1 + 0.5 × (level − 1)) (RULES.md › Leveling)
     - `evalAmount(amount, { level, unitLevel })`, for card amounts such as `"4+{level}"`
   - `src/state/testing.ts`: small builders (`makeState`, `addSquad`, …) for other modules' tests.
4. `rng/`: a seeded PRNG whose whole state is a JSON-safe value kept in `GameState.rng`, for example sfc32 or xoshiro128**.
   - Functions: `seedRng(seed)`, `nextFloat`, `nextInt(min, max)`, `pick`, `shuffle` (Fisher–Yates).
   - The same seed must give the same sequence on every platform.
5. `time/`: `TICKS_PER_SECOND = 10`, `secondsToTicks`, `attackInterval(attackSpeed)` (1 → 10 ticks, 0.5 → 20, 0.2 → 50), and `cellsPerTick(speed)`.
6. `packages/core/README.md` for the tasks that follow. It covers the module map, state slices, the rule that functions change a working copy, ids, coordinates, events, and how to add a module.
7. Tests:
   - RNG determinism and a distribution sanity check, and shuffles that reproduce
   - the time conversions above
   - `levelScale` (level 3 is 2×, level 9 is 5×), `evalAmount`, `distance`, footprint rotation
   - a `GameState` survives `structuredClone` and a JSON round trip

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green
- [ ] Every module folder in CORE.md exists, with an `index.ts` and a `state.ts`
- [ ] `pnpm --filter @chaosgrid/core test` covers rng, time and the state helpers

## Out of scope

- Any module logic beyond state, rng and time. Arena, movement, targeting, scoring, zones, effects, chaos, combat, plan, view and round are separate tasks (T-011 to T-023).
- Protocol changes (T-009) and the effect DSL (T-010).

## Notes

- The shared fields on `Unit`, `Squad` and `Permanent` are a contract for ten later tasks. Check them against RULES.md carefully now: once this merges, later tasks can't edit `state/`. Data that only one module needs belongs in that module's slice, keyed by id.
- T-009 builds protocol v2 at the same time, with the same ids and coordinates from CORE.md. Use them exactly.
