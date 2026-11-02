---
id: T-044
title: Free-standing traps only
milestone: M3
depends_on: [T-043]
branch: agent/T-044-static-traps
model: sonnet
effort: medium
scope:
  - packages/cards/src/schema.ts
  - packages/cards/src/schema.test.ts
  - packages/cards/src/dsl.ts
  - packages/cards/src/dsl.test.ts
  - packages/cards/src/deck/check.test.ts
  - packages/cards/README.md
  - packages/cards/data/traps/backdraft.json
  - packages/cards/data/traps/riptide.json
  - packages/cards/decks/ember_aggro.json
  - packages/cards/decks/tide_control.json
  - packages/cards/test/fixtures/**
  - packages/core/src/**
  - packages/core/test/**
  - packages/protocol/test/fixtures/samples.ts
  - tools/sim-cli/test/golden-script.ts
  - tools/sim-cli/test/golden/**
  - tools/sim-cli/test/fixtures/golden/**
context:
  - docs/PLAN.md#M3
  - docs/RULES.md#Non-unit permanents
  - packages/cards/README.md#Traps
  - packages/cards/README.md#Trap triggers
  - tools/sim-cli/README.md#Tests
---

# T-044 — Free-standing traps only

## Goal

Traps no longer attach to units: every trap sits face down on a cell of its owner's grid and watches its area (RULES.md › Non-unit permanents). The attached trap events leave the card DSL and core, Backdraft and Riptide leave the card pool, and the starter decks and fixtures that used them get other traps.

## Interfaces

What exists (copied from the code):

```ts
// packages/cards/src/dsl.ts:372-375
export const AREA_TRAP_EVENTS = ['enemyEntersArea', 'enemySpellTargetsArea'] as const;
export const ATTACHED_TRAP_EVENTS = ['attachedUnitDies', 'attachedUnitHit'] as const;
export const TRAP_EVENTS = [...AREA_TRAP_EVENTS, ...ATTACHED_TRAP_EVENTS] as const;
// packages/cards/src/schema.ts:175-207: MODES = ['attached', 'freeStanding']; permanent() is a
// discriminated union on `mode`, shared by traps, artifacts and enchantments. TrapCardSchema's
// superRefine derives the required mode from the trigger's event.
// packages/core/src/combat/traps.ts: attachedTo (:148), trapsOnHit (:158), trapsOnDeath (:170);
// fireTrap reveals an attached trap with `mode: 'attached'` (:98).
// packages/core/src/combat/simulate.ts:44 simCtx: emit calls trapsOnHit on every unit.damaged.
// packages/core/src/combat/deaths.ts:34 calls trapsOnDeath.
```

What this task changes:

```ts
export const TRAP_EVENTS = ['enemyEntersArea', 'enemySpellTargetsArea'] as const; // AREA_TRAP_EVENTS and ATTACHED_TRAP_EVENTS go
// TrapCardSchema: `mode` must be "freeStanding"; "attached" fails with a message that says traps
// are free-standing. Artifacts and enchantments keep both modes.
```

The protocol doesn't change: `trap.revealed` shares the placement shape (`mode: 'freeStanding' | 'attached'`, `onGrid` in event.ts) with the other permanents, and core simply never sends `attached` for a trap.

## Deliverables

1. Cards: the schema and DSL changes above, and their tests: an attached trap and each removed event fail with a clear message.
2. Delete `data/traps/backdraft.json` and `data/traps/riptide.json`. In `decks/ember_aggro.json`, Backdraft's 2 copies become 2 Spike Pit (`trap.spike_pit`, colorless, not in the deck yet). In `decks/tide_control.json`, every free-standing trap that fits is already at 2, so Riptide's 2 copies become 2 Relocate (`spell.relocate`, Tide). Decks keep at most 2 copies of a card until T-063. In `packages/cards/test/fixtures/` and `packages/core/test/fixtures/`, replace each copy with a free-standing trap that fits, or with another fitting card where the fixture already holds 2 of each.
3. Core: remove `attachedTo`, `trapsOnHit`, `trapsOnDeath` and their calls, the `attached` branch of `fireTrap`, and the comments that describe attached traps. Core tests that used an attached trap use a free-standing one or go, when they only tested attached traps. Plan rejects a trap placed on a unit with the reject reason it uses today for a wrong placement.
4. Goldens: the frozen card copies in `tools/sim-cli/test/fixtures/golden/cards/` drop Backdraft, and `golden-script.ts` plays a free-standing trap where it played Backdraft. Regenerate `round-1.json` and `round-2.json` with `UPDATE_GOLDEN=1`, and say in the PR what changed in them.
5. packages/cards/README.md › Traps and › Trap triggers describe free-standing traps only.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm cards:validate` passes
- [ ] `grep -rn -e attachedUnitHit -e attachedUnitDies -e backdraft -e riptide packages tools --include='*.ts' --include='*.json' | grep -v node_modules` prints nothing

## Out of scope

- The protocol: no payload changes (see Interfaces)
- New trap cards: the content tasks add them

## Notes

- `protocol/test/fixtures/samples.ts` names `trap.backdraft` only as a sample id. Rename it to another trap so the grep stays clean.
- If a core test needs a trap that hits the unit that set it off, Spike Pit or Flare Mine will do.
