---
id: T-053
title: Copy
milestone: M3
depends_on: [T-052]
branch: agent/T-053-copy
model: opus
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
  - docs/RULES.md#Non-unit permanents and spells
  - docs/RULES.md#Round structure
  - packages/cards/README.md#Targets
  - packages/cards/README.md#Caster choices
  - packages/cards/README.md#Spell classes
  - packages/cards/README.md#Trap triggers
  - docs/PROTOCOL.md#Plans
---

# T-053 — Copy

## Goal

A new effect, `copy` (RULES.md › Non-unit permanents and spells › Copy). When a spell or an ability's spell is copied, its player uses it again, for free, and may pick new targets.

- During Plan, a card copies a spell its player cast earlier in the same plan. It can be a spell card, a resource's Rest ability or a Plan ability.
- During Simulate, a trap copies the enemy spell that set it off, and the copy picks its own targets for the trap's owner.

A copy isn't a cast, but it sets off traps that react to spells like any spell, copy traps included. A trap fires only once, so a chain of copy traps always ends. A spell that copies can be copied too, so copies chain. Loops are allowed, and each copying card has a limit that ends them: a spell card is cast once, a Plan ability is used once a round, a trap fires once, and a permanent that copies by itself does it When played (`onPlay`, T-050), never On enter.

## Interfaces

What exists (copied from the code, plus the earlier M3 tasks):

```ts
// packages/protocol/src/plan.ts:78, renamed by T-040; :90; T-042
CastSpellAction { action: 'castSpell', card: CardInstanceId, target?: Target }
UseResourceAction { action: 'useResource', resource: CardInstanceId, target?: Target }
UseAbilityAction { action: 'useAbility', card: CardInstanceId, ability: number, target?: Target }
// packages/protocol/src/target.ts:25. A plan target. No kind refers to another plan action yet.
export const Target = z.discriminatedUnion('kind', [seat, row, area, squad, squadToCell]);
// packages/protocol/src/target.ts:39. What a card needs, for planners.
export const TargetSpec = z.discriminatedUnion('kind', [/* the same kinds, each with a side */]);
// packages/protocol/src/event.ts:~372
SpellResolvedEvent { type: 'spell.resolved', seat, card, cardId, spell: SpellClass, target }
// packages/core/src/combat/traps.ts:20: a trap fires once, then leaves the grid.
// packages/protocol/src/event.ts:113
export const RejectReason = z.enum(['wrongPhase', 'unavailable', 'wrongCardType', 'unaffordable', 'noRoom', 'illegalTarget', …]);
// packages/cards/src/dsl.ts:372, renamed by T-040. Mirror Snare's event.
AREA_TRAP_EVENTS = ['enemyEntersArea', 'enemySpellTargetsArea']
// packages/cards/src/dsl.ts:23, plus 'onUse' (T-042) and 'onPlay' (T-050, fires when castUnit, castLeader
// or castPermanent plays the card; on a revive only with `played: true`)
TRIGGERS = ['static', 'onEnter', 'onAttack', …, 'onRest', 'onDraw', 'onUse', 'onPlay']
```

What this task adds:

```ts
// cards
effect('copy', { target: 'chosenOwnSpell' | 'lastOwnSpell' | 'triggeringSpell' })
// chosenOwnSpell: a Plan caster choice. lastOwnSpell: the seat's latest earlier spell action in the plan,
// no choice (for onPlay, whose cast action has no target). triggeringSpell: only on a trap whose event is
// enemySpellTargetsArea.

// protocol
Target: + { kind: 'spell', action: z.int().min(0) }   // the index of an earlier action in the same plan
TargetSpec: + { kind: 'spell', side: 'own' }
CastSpellAction, UseResourceAction, UseAbilityAction: + copyTarget?: Target
// copyTarget: the copy's new choice. Absent: the copy keeps the original's.
SpellResolvedEvent: + copyOf?: CardInstanceId          // set on a copy: the card whose spell it copies
export const PROTOCOL_VERSION = /* T-052's + 1 */;
```

## Deliverables

1. **Cards.**
   - `copy` takes `chosenOwnSpell`, `lastOwnSpell` or `triggeringSpell`. A card or ability may hold at most one `copy`.
   - `triggeringSpell` is only valid on a trap whose trigger event is `enemySpellTargetsArea`.
   - `copy` is valid on spell cards, traps, and abilities with the triggers `onUse`, `onRest` and `onPlay`. On any other trigger, `onEnter` included, it fails with "a copy needs a limit: use a spell, onPlay, onUse, onRest or a trap" (RULES.md › Copy).
   - `chosenOwnSpell` and `lastOwnSpell` are valid where a Plan copy can happen: spell cards, `onUse`, `onRest` and `onPlay`. Neither is valid on a trap.
   - `copy` is allowed under every spell class. The copy's effects follow the original's class and side rules, not the copier's.
   - Only `chosenOwnSpell` is a caster choice: add it to the caster-choice table, with plan target `spell` on the own side. `lastOwnSpell` and `triggeringSpell` need no choice.
2. **Plan copies.**
   - The copying action's `target` is `{ kind: 'spell', action: n }`, where `n` is the index of an earlier `castSpell`, `useResource` or `useAbility` action in the same plan, by the same seat.
   - The copy has the original's class and resolves as the original does: a utility copy resolves at once, when the copying spell does, and a defensive or offensive copy resolves at tick 0 straight after its original.
   - `copyTarget`, when given, replaces the original's choice. It must be the kind and side the original's card needs. When it's absent, the copy uses the original's target.
   - `lastOwnSpell` needs no plan target: it names the seat's latest earlier `castSpell`, `useResource` or `useAbility` action that wasn't rejected. With none, the copy does nothing. A unit's `onPlay` copy uses it when its `castUnit` resolves. During Simulate (a unit revived with `played: true`, T-050), it names the seat's latest spell action of this round's plan that wasn't rejected.
   - The original may itself be a copying spell: its copy then makes a copy of what the original copied, with `copyTarget` replacing that choice. Every copy names an earlier action, so a Plan chain always ends.
   - The action is rejected (`illegalTarget`) when `n` isn't earlier, names something other than a spell, or names an action that was rejected, or when `copyTarget` doesn't fit.
3. **Simulate copies.**
   - A trap with `copy: triggeringSpell` copies the enemy spell that set it off, for the trap's owner. The original still resolves as cast. That spell may itself be a copy: then `copyOf` names the card the first copy came from.
   - The copy picks its own targets, aimed back at the original's caster:
     - an opponent-side choice names the caster: the same seat, the same row, the same area cell on the caster's grid, or the caster's squad nearest that grid cell (ties to the lowest squad id), the way T-042's `mirroredTarget` turns Mirror Snare's choices around: reuse it
     - an own-side choice names the trap's owner, with the same coordinates
   - If no target fits, the copy does nothing.
4. **What a copy is.**
   - It is free: it pays no cost, rests nothing and spends no attached resources (a `spendAttachedResources` effect does nothing in a copy).
   - Amounts that scale read what the original read, such as `{level}` or the number of attached resources.
   - It isn't a cast: it doesn't count as a card played or as a resource used. It does set off `enemySpellTargetsArea` and the other spell trap events, as a spell does, so a copy trap can copy a copy back. Each trap fires once, so each sends a spell back at most once and the chain ends.
   - Its card color is the original's (T-043).
   - The prize is never its target (T-048's guard).
   - Utility copies stay private to their seat until `plans.revealed`, as utility spells do.
5. **Events.** A copy resolves as a `spell.resolved` with `copyOf` set, followed by its effects' events, as a spell does. Bump `PROTOCOL_VERSION`.
6. **Bots.**
   - The random bot may copy any earlier spell action of its plan, with the original's target.
   - The greedy bot scores a copy as the copied spell's score, and copies its best-scoring spell of the plan.
7. **Tests:**
   - cards: `copy` validates with each target, and is rejected twice in one ability, with `triggeringSpell` off the trap event or on a spell card, with `chosenOwnSpell` or `lastOwnSpell` on a trap, with an unknown target, and on `onEnter` and `onAttack` with the message above
   - protocol: the `spell` target and `copyTarget` round-trip, and `{ kind: 'spell', action: -1 }` fails
   - core plan:
     - copying a utility draw draws twice
     - copying an offensive damage with a new `copyTarget` hits both squads at tick 0
     - copying a Plan ability doesn't rest the unit again or pay again
     - copying a spell that copies makes a second copy of its original
     - a unit's `onPlay` copy with `lastOwnSpell` copies the spell cast before it, and doesn't copy again when the unit is revived without `played`
     - each rejection in Deliverable 2
   - core sim:
     - a trap copies an enemy offensive spell back at the caster
     - a copy sets off a spell trap: Mirror Snare redirects a copy as it does a spell
     - two copy traps: seat 0's spell sets off seat 1's copy trap, the copy sets off seat 0's copy trap, that copy goes back once, and the chain stops because both traps have fired
     - a copy never names the prize
   - determinism: the same seed and plans, with copies in them, give the same events
8. **Docs.** packages/cards/README.md: a `#### \`copy\`` section with a Plan example ("Copy a spell you cast this Plan. You may choose new targets for the copy") and a trap example. Add the three targets to › Targets, and `chosenOwnSpell` to › Caster choices. docs/PROTOCOL.md: the `spell` target and `copyTarget` in › Plans, `copyOf` in the events, and a line in › Versioning.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm cards:validate` passes. Mirror Snare and the other existing cards don't change.
- [ ] A golden-style core test: a plan casts an offensive spell on one squad and copies it onto another squad. Its event log shows two `spell.resolved` at tick 0, the second with `copyOf`, and damage on both squads.

## Out of scope

- Cards with copy: T-060
- Re-expressing Mirror Snare as a copy plus a counter: it stays a script. If the copy code makes that easy, say so in the PR, and `lead` decides.
- Copying a triggered ability that isn't a spell (an `onAttack` effect, a unit's `every`): ask `lead` if a card needs it
- The UI for picking a spell to copy: M4

## Notes

- Copies set off spell traps (RULES.md › Copy). Two players' copy traps can't loop forever: a trap fires once and leaves, so a spell bounces back at most once per trap.
- Copies may chain and loop (RULES.md › Copy). What ends a chain is the limit on each copying card (Deliverable 1), not a ban on copying copies.
- Default: Simulate copies are aimed back at the caster, as Deliverable 3 sets out. It's a rule, so it's deterministic and needs no choice from the player.
- Default: one copy card makes one copy. Two copy cards may copy the same original.
- A copy of a Chaos card isn't possible: Chaos cards aren't spells (T-043 › Notes).
