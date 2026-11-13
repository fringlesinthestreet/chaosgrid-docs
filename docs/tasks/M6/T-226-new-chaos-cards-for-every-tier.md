---
id: T-226
title: New Chaos cards for every tier
milestone: M6
depends_on: [T-224, T-235]
branch: agent/T-226-new-chaos-cards-for-every-tier
model: sonnet
effort: medium
scope:
  - packages/cards/data/chaos/**
  - packages/cards/test/sets/chaos.test.ts
  - apps/web/src/**/*.test.ts
  - packages/core/src/chaos/deck.test.ts
  - packages/core/src/chaos/reveal.test.ts
  - packages/core/src/round/begin.test.ts
  - packages/core/src/round/check.test.ts
  - packages/core/src/round/preview.test.ts
  - tools/sim-cli/src/game.test.ts
context:
  - docs/RULES.md#Chaos deck and Emblems
  - docs/RULES.md#Sample Chaos deck and Emblems
  - packages/cards/README.md#Chaos (`chaos`)
  - packages/cards/README.md#Targets
  - packages/cards/README.md#Durations
  - packages/cards/README.md#Stats
---

# T-226 — New Chaos cards for every tier

## Goal

Every round now draws a condition, an Emblem and a unit card (D80), so each tier's three piles need variety. After this PR the Chaos data matches RULES.md › Sample Chaos deck and Emblems: twelve new cards, and the amounts of the existing ones.

## Interfaces

The new cards, as RULES.md › Sample Chaos deck and Emblems gives them with their stats, points, Durability, effects and amounts. The ids are art keys (D13):

| Tier | Pile | Ids |
| --- | --- | --- |
| 1 | Emblems | `chaos.scrap_heap`, `chaos.wayfarer_cairn` |
| 2 | Units | `chaos.gloom_crawlers` |
| 2 | Conditions | `chaos.still_air`, `chaos.rich_vein` |
| 2 | Emblems | `chaos.war_drum`, `chaos.sunken_archive` |
| 3 | Units | `chaos.grim_legion` |
| 3 | Conditions | `chaos.eerie_calm`, `chaos.blood_moon` |
| 3 | Emblems | `chaos.heartstone`, `chaos.dragon_hoard` |

Write each like the existing card of its kind: `chaos.supply_drop` for an Emblem (`"kind": "emblem"`, `"spawn": "central"`, `points`, `durability`, an `onDestroyed` ability on `destroyer`), `chaos.calm` for `nothing`, `chaos.good_weather` for a rule (a `static` ability), `chaos.rat_swarm` for units.

## Deliverables

1. The twelve files, `version` 1, and the `amount` of every existing Chaos card set to the table's.
2. `chaos.test.ts`: each tier's piles hold the table's number of copies.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check soak` green
- [ ] `pnpm cards:validate` green

## Out of scope

- Core and the card schema. Use only effects, targets and stats the DSL has.

## Notes

- If an effect in the table can't be written with the DSL as it stands (for example a buff to the breaker's units, if `destroyer` has no units target the way a Chaos unit's killer has `killerUnits`), write the nearest one it can, keep the id and the name, and say so in the PR.
- Heartstone, Rich Vein and the existing Good Harvest and Supply Drop add mana, not resource draws (D86): a `buff` of the player stat `manaPerRound` (T-235), for the game, the round or two rounds. Drought is the `noResources` rule.
