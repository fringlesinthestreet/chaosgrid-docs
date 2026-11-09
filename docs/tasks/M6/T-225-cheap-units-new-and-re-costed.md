---
id: T-225
title: Cheap units, new and re-costed
milestone: M6
depends_on: [T-219]
branch: agent/T-225-cheap-units-new-and-re-costed
model: sonnet
effort: high
scope:
  - packages/cards/data/units/**
  - packages/cards/decks/**
  - packages/cards/src/node/starter.test.ts
  - packages/cards/test/sets/cheap-units.test.ts
context:
  - docs/RULES.md#Units
  - docs/RULES.md#Card colors
  - packages/cards/README.md#Units (`unit`)
  - packages/cards/README.md#Keywords
  - packages/cards/README.md#Projectiles
  - packages/cards/README.md#Starter decks
---

# T-225 — Cheap units, new and re-costed

## Goal

With one resource a round (D60), round 1 has 1 mana and round 3 has 3, and most units cost 3 or more. After this PR every color has more units at cost 1 and 2: eleven new ones, and ten cheaper versions of existing ones. Expensive cards stay as they are.

## Interfaces

The new units. The ids are art keys (D13), so they stay as written; set HP, Attack, Attack speed, Speed and any ability yourself:

| Id | Name | Cost | Range | Size | Squad | Flying | Role |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `unit.spark_pup` | Spark Pup | `R` | Melee | 1×1 | 1 | no | fast striker |
| `unit.cinder_slinger` | Cinder Slinger | `1R` | Ranged | 1×1 | 1 | no | fireball thrower |
| `unit.reef_skimmer` | Reef Skimmer | `T` | Melee | 1×1 | 1 | yes | flying harasser |
| `unit.mist_adept` | Mist Adept | `1T` | Ranged | 1×1 | 1 | no | a slow or weaken On attack |
| `unit.moss_grub` | Moss Grub | `E` | Melee | 1×1 | 1 | no | sturdy blocker of the front row |
| `unit.bramble_hog` | Bramble Hog | `1E` | Melee | 2×2 | 1 | no | Trample |
| `unit.bone_mite` | Bone Mite | `D` | Melee | 2×1 | 2 | no | fodder for sacrifice and revive |
| `unit.carrion_picker` | Carrion Picker | `1D` | Melee | 1×1 | 1 | yes | flyer |
| `unit.candle_squire` | Candle Squire | `L` | Melee | 1×1 | 1 | no | Shield (1) |
| `unit.dawn_novice` | Dawn Novice | `1L` | Ranged | 1×1 | 1 | no | Extra life (1) |
| `unit.tin_soldier` | Tin Soldier | `1` | Melee | 1×1 | 1 | no | colorless filler |

## Deliverables

1. **The eleven units**, `version` 1, with stats in line with their color's existing 1- and 2-cost units (read those first), abilities from the existing DSL only, and a level unlock like theirs. A timed ability that reaches other units makes the card Unique (D66).
2. **Re-costs.** In each color, two units costing 2 or 3 drop to cost 1, with numbers cut so that they play like 1-cost units: HP, Attack, squad size or an ability's number. `version` + 1, text to match. The PR lists the ten with their numbers before and after.
3. **Starter decks.** Each holds at least 24 units of cost 1 or 2 from its colors, new or re-costed, and stays 100 legal cards with a true `description`.
4. **Tests**, `packages/cards/test/sets/cheap-units.test.ts`: each new id exists with the cost, range, size, squad and flying of the table, and each color has at least four units of cost 1. `starter.test.ts`: each starter deck's cheap-unit count.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check perf` green
- [ ] `crew check soak` green
- [ ] `pnpm cards:validate` green

## Out of scope

- The costs of Leaders, spells, artifacts and enchantments; the mana artifacts (T-228); Chaos cards.

## Notes

- Cost 1 means a mana value of 1: one colored pip, or `1` for Tin Soldier.
- The web draws placeholders until each id's art exists.
