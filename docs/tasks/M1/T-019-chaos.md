---
id: T-019
title: Chaos deck and Emblems
milestone: M1
depends_on: [T-011, T-016]
branch: agent/T-019-chaos
scope:
  - packages/core/src/chaos/**
  - packages/core/test/fixtures/chaos/**
---

# T-019 — Chaos deck and Emblems

## Goal

Build the shared PvE layer:

- the tiered Chaos deck, and each round's draw
- Chaos units spawning in front of the right players
- Emblems in the center
- rule cards applied for the round
- everything cleared away at Cleanup

## Read first

- docs/CORE.md (the Chaos defaults) and packages/core/README.md
- docs/RULES.md: Chaos deck and Emblems, Sample Chaos deck and Emblems, Scoring and winning (Chaos kills, Emblems)
- packages/cards/README.md (Chaos cards and the DSL)

## Deliverables

1. A `chaos` slice, and `buildChaosDeck(state, cards)`: each tier holds each card `amount` times, is shuffled with the seeded RNG, and the tiers are stacked 1 over 2 over 3.
2. `revealChaos(ctx)` at Reveal:
   - draws this round's number of cards for the tier (CORE.md default)
   - reshuffles tier 3 every round
   - emits a `chaos.revealed` event per card
3. Spawning:
   - Chaos squads spawn on arena spawn cells in front of their targets: everyone, the point leader (or every tied leader), or the leader and the runner-up
   - Emblems and Chaos artifacts go in the central zone
4. Rule cards apply as this round's rules, through the effects engine. "Nothing" cards do nothing.
5. Extra Chaos, drawn when the RULES.md conditions are met (CORE.md default for when it's drawn):
   - a player's whole grid was wiped this round
   - the leader is 10+ points ahead at Cleanup
6. Cleanup: every Chaos unit and card of the round despawns. Breaking an Emblem gives the breaker its points and its permanent buff.
7. Tests:
   - deck composition, and order by tier
   - draw counts per round
   - spawn targets, including ties
   - rule cards and extra Chaos
   - despawning, and Emblem rewards

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green

## Out of scope

- Fighting Chaos units (T-020) and the effects that rule cards use (T-016, T-018).
