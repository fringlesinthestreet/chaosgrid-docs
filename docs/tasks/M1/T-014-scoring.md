---
id: T-014
title: Scoring and winning
milestone: M1
depends_on: [T-008]
branch: agent/T-014-scoring
scope:
  - packages/core/src/scoring/**
  - packages/core/test/fixtures/scoring/**
---

# T-014 — Scoring and winning

## Goal

Turn kills, Emblems and survival into points. Keep totals fractional, show them rounded, and decide when someone has won.

## Read first

- docs/tasks/M1/README.md and packages/core/README.md
- docs/RULES.md: Scoring and winning (including Shown points), Leader, Chaos deck and Emblems

## Deliverables

1. The point rules, as pure functions:
   - **An opponent's unit killed:** the squad's cost × its level ÷ units per squad. Killing a Leader also scores the leader card's `leaderBonus`.
   - **A Chaos unit killed:** its card's points ÷ units per squad.
   - **An Emblem broken:** its points.
   - **Surviving the round** with at least one unit alive.
   - **Chaos event bonuses**, as printed.

   Kills made by Chaos score for nobody.
2. A `scoring` slice with each seat's gains this round, plus modifiers that cards can set. The fractional total lives on `Player.points` (T-008), and scoring adds the round's gains to it at Cleanup. Toxic turns this round's gains into losses; Crown Shard adds 1 point per opponent unit killed.
3. `shownPoints(total)`: the nearest integer, with .5 rounding up (RULES.md › Shown points, and the protocol's `Points`).
4. `winners(state)` at Cleanup: every seat strictly above the target is a candidate, and the one with the most points wins. Seats tied exactly on points win together.
5. Tests:
   - every rule above, and fractions adding up over several rounds
   - rounding edges: 1.5 → 2, 2.49 → 2
   - Toxic and Crown Shard
   - every tie case

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green

## Out of scope

- Detecting kills (combat reports them, T-020) and running Cleanup (T-023).

## Notes

- The killer is the owner of the unit, trap or sorcery that dealt the final damage (RULES.md). Take it as an input.
