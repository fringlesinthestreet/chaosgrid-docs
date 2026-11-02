---
id: T-004
title: Sample cards: units and leaders
milestone: M0
depends_on: [T-003]
branch: agent/T-004-cards-units-leaders
scope:
  - packages/cards/data/units/**
  - packages/cards/data/leaders/**
---

# T-004 — Sample cards: units and leaders

## Goal

Copy the RULES.md sample units and leaders into card JSON, so that the simulation (M1) and the deck builder (M3) have real cards to work with.

## Read first

- packages/cards/README.md (the format: follow it exactly)
- docs/RULES.md: Units, Keywords, Leveling, Leader, and Sample cards → Units and Leaders

## Deliverables

- One file per card: the 12 units in `packages/cards/data/units/`, and the 5 leaders (Vask, Oriel, Kettle, Jaksho, Dominic) in `packages/cards/data/leaders/`.
- Numbers exactly as in the tables. `text` is the table's Text column word for word. Fix only obvious typos, and list each one in the PR body.

## Acceptance

- [ ] `pnpm cards:validate` green
- [ ] 17 files: 12 in `units/`, 5 in `leaders/`
- [ ] The PR body has a table listing every value that needed interpretation and how you read it

## Out of scope

- The schema and the README in `packages/cards`. If the format can't express a card, send lead a `request`.
- Other card kinds (T-005, T-006).

## Notes

- If the format can't express an ability, keep it in `text`, make the structured part minimal (or `script: "<slug>"`), and note it in the PR body.
- Unless lead answers otherwise, use these defaults:
  - The "Squad Size" column is the footprint Size.
  - "Units per card" is the squad count.
  - RULES.md says "three Leaders" but lists five: add all five.
