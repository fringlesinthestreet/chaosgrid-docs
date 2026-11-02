---
id: T-021
title: Plan phase
milestone: M1
depends_on: [T-009, T-011, T-015, T-016, T-028]
branch: agent/T-021-plan-phase
scope:
  - packages/core/src/plan/**
  - packages/core/test/fixtures/plan/**
---

# T-021 — Plan phase

## Goal

Apply each seat's plan: cast and place cards, pay for them, level up, attach resources, set traps, queue sorceries and resolve rituals. Anything the rules don't allow is rejected, without failing the whole plan.

## Read first

- docs/PROTOCOL.md (plan actions), docs/CORE.md and packages/core/README.md
- docs/RULES.md: Round structure (Plan), Units (Leveling, Leader, Respawn), Resources and attaching, Non-unit permanents

## Deliverables

1. `applyPlans(ctx, plans)`: seats in seat order, and each seat's actions in the order given. Each action is checked and then applied, or skipped with a `plan.rejected` event that gives the reason.
2. The actions:
   - `castUnit`: pay through zones, place through arena, spawn the squad's units on `unitStartCells` (T-028), and fire On enter triggers
   - `castLeader`, and `moveLeader` (a free move to any empty cell)
   - `levelUp`: the unlock condition is met, the cost is paid again, the level stays at 9 or below, and Durability resets
   - `attach` (Charge)
   - `castPermanent`: attached or free-standing; traps go down face-down
   - `queueSorcery`: combat resolves it at tick 0
   - `castRitual`: resolves now, through effects, and stays hidden until the round starts
   - `useResource` and `discard`
3. `applyPlans` takes an optional `settle(ctx, seat)` hook and calls it after each action, so a seat's later actions can use what it gave: an `attach` that charges Jaksho draws its extra resource right away. T-023 wires it to effects' `settlePlanDraws` (T-018).
4. Card instances move between zones as they're cast: from the hand to a grid, or to the graveyard.
5. Tests for every action succeeding, and for each of the protocol's `RejectReason`s (unaffordable, no room, illegal target, not unlocked, already max level, wrong phase, …). Include actions in one plan that affect each other, such as attaching to Jaksho and then spending the extra resource.

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green

## Out of scope

- Resolving sorceries (T-020) and choosing plans (bots, T-017).
