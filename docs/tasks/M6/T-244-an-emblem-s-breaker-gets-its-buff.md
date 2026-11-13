---
id: T-244
title: An Emblem's breaker gets its buff
milestone: M6
depends_on: []
branch: agent/T-244-an-emblem-s-breaker-gets-its-buff
model: sonnet
effort: medium
scope:
  - packages/core/src/effects/filters.ts
  - packages/core/src/effects/triggers.ts
  - packages/core/src/effects/targets.test.ts
  - packages/core/src/effects/triggers.test.ts
  - packages/cards/README.md
context:
  - docs/RULES.md#Scoring and winning
  - packages/cards/README.md#Targets
---

# T-244 — An Emblem's breaker gets its buff

## Goal

War Drum and Wayfarer Cairn buff the units of the seat that broke them. Today their `onDestroyed` buff targets `killerUnits`, which core resolves only from a killer, so the buff reaches no unit.

## Interfaces

On `main` (grep the names, the lines move).

- `fireDeath(ctx, death)` in `packages/core/src/effects/triggers.ts`: for an Emblem it runs `fire(ctx, 'onDestroyed', { permanent: death.victim, destroyer: breakerOf(death.killer) })`, with no `killer` fact. For a unit it passes `killer` and `killerUnit` to `onDeath`.
- `breakerOf(killer: Owner | null): number | null` in `effects/health.ts`: the seat that broke an Emblem, null when Chaos or nothing did.
- `groupOf(target, run)` in `effects/filters.ts`: `killerUnits` gives `{ side: 'own', owner: run.facts.killer }`, or null when `run.facts.killer` is null. `unitTargets`'s `killerUnits` case calls it.
- `AbilityRun.facts` (`effects/state.ts`): `killer: Owner | null` (`onDeath`), `destroyer: Seat | null` (`onDestroyed`). `effects/sources.ts` fills `destroyer: facts.destroyer ?? null`.
- The cards: `chaos.war_drum` (tier 2, "Buff: the breaker's units have +1 Attack for 2 rounds") and `chaos.wayfarer_cairn` (tier 1, "+2 HP next round"), each one `onDestroyed` buff with `"target": "killerUnits"`. `chaos.siege_colossus` uses `killerUnits` on `onDeath` and works.
- The DSL's target table in `packages/cards/README.md`: `killerUnits` is "Every unit of the player whose unit killed this one", with Siege Colossus as its example.

## Deliverables

1. **Core.** On an Emblem's `onDestroyed`, `killerUnits` is every unit of the seat that broke it, and nobody when Chaos or nothing broke it. Either `groupOf` reads the destroyer when there's no killer, or `fireDeath` passes the breaker as the `killer` fact too: pick the smaller change and keep `destroyer` as it is (the `destroyer` target uses it).
2. **Docs.** The `killerUnits` row in the cards README says it covers an Emblem's breaker, with War Drum beside Siege Colossus.
3. **Tests**, in the existing files:
   - `targets.test.ts`: `killerUnits` from an `onDestroyed` run with a destroyer seat is that seat's units; with a null destroyer, nobody.
   - `triggers.test.ts`: a seat's unit breaks War Drum, and that seat's units, and no one else's, have +1 Attack in the next round and the one after.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/core test effects` green
- [ ] `pnpm test:perf` and `pnpm test:soak` green

## Out of scope

- A new DSL target such as `destroyerUnits`: the card data stays as it is.
- The Chaos card data and the other Emblems.

## Notes

- The golden streams don't draw these two Emblems. If one changes, stop and ask the lead instead of regenerating it.
