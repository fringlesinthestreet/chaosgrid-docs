---
id: T-052
title: Fear
milestone: M3
depends_on: [T-051]
branch: agent/T-052-fear
model: sonnet
effort: high
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/cards/src/**
  - packages/cards/test/**
  - packages/cards/README.md
  - packages/core/src/**
  - packages/core/test/**
  - packages/bots/src/**
  - packages/bots/test/**
  - tools/sim-cli/test/**
context:
  - docs/RULES.md#Simulation rules
  - docs/RULES.md#Non-unit permanents and spells
  - packages/cards/README.md#Effects
  - packages/cards/README.md#`push` and `move`
  - packages/cards/README.md#Targets
  - docs/PROTOCOL.md#Board
---

# T-052 — Fear

## Goal

A new effect, `fear` (RULES.md › Simulation rules › Fear). A feared unit stops attacking and moves directly away from the source of the fear, at its Speed, for the time the card prints. Then it picks a new target. Fear works on units only. The prize is immune, as T-048 set out.

## Interfaces

What exists (copied from the code):

```ts
// packages/cards/src/dsl.ts:191. Effects are built with `effect(name, shape)` and the shared envelope.
effect('push', { … }), effect('move', { … }), effect('rest', { target: … }) // rest's targets from T-042
// packages/cards/src/dsl.ts:129
export const DurationSchema // seconds (an amount), "round", "game", or { "nextRounds": n }
// RULES.md › Tick order, step 3: "Rested units do neither, and feared units move away (see Fear)."
```

What this task adds:

```ts
effect('fear', { target: /* the unit and group targets `rest` takes */, seconds: PositiveAmount })
// protocol
UnitFearedEvent { type: 'unit.feared', unit, source: EntityId, from: WorldCell, until: Tick }
// source: the card or unit that feared it; from: the cell it moves away from; until: the tick it ends
UnitFearEndedEvent { type: 'unit.fearEnded', unit }
export const PROTOCOL_VERSION = /* T-051's + 1 */;
```

## Deliverables

1. **Cards.** `fear` takes the targets `rest` takes (T-042), the groups with a scope and a filter, and a required `seconds` amount, which may scale with `{level}`. It is offensive-only when it reaches enemies, as the side rules say. A `round` duration isn't allowed: fear is always timed.
2. **Core: moving away.**
   - While feared, a unit doesn't attack, and in tick order step 3 it moves one step per its Speed directly away from the fear's source, a cell fixed when the fear lands (RULES.md › Fear): the area's center for an area spell or a trap; the cell of the unit whose ability feared it, or the center of a permanent's footprint; the center of the caster's grid (its prize) for a spell aimed at a squad, a row or a seat. When a center falls between cells (an even side), take the middle cell with the lower world coordinate on that axis. `unit.feared`'s `from` is that cell.
   - It uses the same pathing as normal movement but in reverse: each step increases the distance from the source, choosing among equal steps the way movement breaks ties today.
   - At the battlefield's edge, or when no step increases the distance, it stays put. A static (Speed 0) or rested unit just doesn't attack.
3. **Core: the rest.**
   - The unit's abilities still fire. It can be attacked. While feared, a unit ignores enemy Blockers' taunts, and a feared Blocker taunts nobody until its fear ends.
   - When the fear ends, the unit drops its held target and picks a new one in the next targeting step.
   - Fearing a feared unit keeps whichever ends later and doesn't move the source.
   - Death ends a fear, and Cleanup clears every fear.
4. **Protocol.** The two events, with doc comments that quote the rule. Bump `PROTOCOL_VERSION`.
5. **Tests:**
   - cards: `fear` validates with each kind of target, and is rejected without `seconds`, with `"round"`, or under `defensive` on an enemy target
   - core:
     - a feared melee unit walks away for exactly the printed ticks, doesn't attack, then retargets
     - a feared static unit stays put and doesn't attack
     - fear at the battlefield's edge
     - fear from an area spell, from a unit's `onAttack` and from a spell aimed at a squad each moves away from the cell Deliverable 2 names
     - re-fear keeps the later end
     - the prize and Emblems are unaffected
     - determinism under a fixed seed
   - core: one `onAttack` fear ("hits fear the target for 1 second") played over a whole round
6. **Docs.** packages/cards/README.md gets a `#### \`fear\`` section with an example, and `fear` in the effects table. docs/PROTOCOL.md gets the events and a line in › Versioning.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm cards:validate` passes
- [ ] The core test that plays a whole round with fear has its event log checked against a fixture, in the style of the existing golden tests

## Out of scope

- Cards with fear: T-060
- How the UI shows a feared unit: M4

## Notes

- Decision (lead, 2026-10-22): the source cells in Deliverable 2. "Away from the source" means away from that cell, not from where the source moves later.
- Default: Chaos units can be feared like any unit.
- A fear on `allUnits` fears the caster's own units too (RULES.md › Fear), like a rest on `allUnits` (T-042). Only units can be feared: the prize and other non-unit permanents are skipped.
- If the reverse pathing gets expensive on the 130 × 130 battlefield, the cheap answer is a straight-line step on the major axis. Say which you used in the PR.
