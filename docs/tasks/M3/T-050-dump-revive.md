---
id: T-050
title: Dump, discard and revive
milestone: M3
depends_on: [T-049]
branch: agent/T-050-dump-revive
model: opus
effort: high
scope:
  - packages/protocol/src/**
  - packages/protocol/test/**
  - packages/protocol/README.md
  - docs/PROTOCOL.md
  - packages/cards/src/**
  - packages/cards/test/fixtures/**
  - packages/cards/README.md
  - packages/core/src/**
  - packages/core/test/**
  - packages/core/README.md
  - packages/bots/src/**
  - packages/bots/test/**
context:
  - docs/PLAN.md#M3
  - docs/RULES.md#Zone mechanics
  - docs/RULES.md#Units
  - packages/cards/README.md#Caster choices
  - packages/cards/README.md#Spell classes
  - docs/PROTOCOL.md#Targets
  - docs/PROTOCOL.md#Card events
---

# T-050 — Dump, discard and revive

## Goal

The other three zone mechanics in RULES.md › Zone mechanics: dump (the top of a deck to its discard pile), discard (random cards from a hand to its discard pile) and revive (a unit card from your discard pile back onto your grid). A revive during Plan lets the caster pick the card and its cells, so the plan needs a new target kind; a revive during Simulate picks for itself. The snapshot shows the discard piles' cards, since they are public and a planner needs them to choose.

A revived unit enters the grid without being played, so this task also adds the When played trigger (RULES.md › Units › Keywords): it fires only when a card is played, while On enter fires every time a card enters.

## Interfaces

What exists after T-040 to T-049 (T-040 named the zone `discardPile`):

```ts
// packages/cards/src/dsl.ts: PLAYER_TARGETS = ['owner', 'allPlayers', 'destroyer', 'opponents'], plus banish and
// sacrifice. Effects resolve in packages/core/src/effects/handlers/; spawn.ts places tokens.
// packages/protocol/src/target.ts: Target and TargetSpec kinds seat, row, area, squad, squadToCell.
// packages/protocol/src/snapshot.ts:70 PlayerSnapshot { …, discardPileCount, void: CardId[], … }
// packages/protocol/src/event.ts: SquadPlacedEvent ('squad.placed'), UnitSpawnedEvent.
// packages/core/src/plan/squads.ts:100 fires 'onEnter' when castUnit places a squad; chaos/spawn.ts:77 when Chaos spawns.
```

What this task adds:

```ts
// cards DSL
TRIGGERS: + 'onPlay' // When played: the card's owner cast it (castUnit, castLeader, castPermanent)
{ effect: 'dump', amount: <number>, target: <player target> }
{ effect: 'discard', amount: <number>, target: <player target> } // random cards from each target's hand
{ effect: 'revive', target: 'chosenDiscardPileUnit' | 'lastDiscardPileUnit', filter?: <filter>, played?: true }
// played: the revived card counts as played, so its onPlay abilities fire too
// chosenDiscardPileUnit: a caster choice (Plan only); lastDiscardPileUnit: the unit card that entered
// the owner's discard pile last and passes the filter
// protocol
Target: { kind: 'discardPileCard'; card: CardInstanceId; cell: Cell; rotated: boolean }  // the card, its top-left cell, and its rotation as castUnit takes it
TargetSpec: { kind: 'discardPileCard'; side: 'own' }
CardsDumpedEvent { type: 'cards.dumped'; seat; cards: CardId[] } // top first
CardsDiscardedEvent { type: 'cards.discarded'; seat; cards: CardId[] } // by an effect or Cleanup's hand limit, in the order discarded
SquadRevivedEvent { type: 'squad.revived'; squad: SquadId; from: CardInstanceId; card: CardInstanceId } // from: the discard pile card; card: its new instance; with its squad.placed
PlayerSnapshot: { ..., discardPile: { card: CardInstanceId; cardId: CardId }[] } // oldest first; replaces discardPileCount
PROTOCOL_VERSION + 1
```

## Deliverables

1. Cards: the `onPlay` trigger (valid on unit, Leader, artifact and enchantment cards), `dump`, `discard`, `revive`, the two revive targets and their sides (own), validator errors (`chosenDiscardPileUnit` only on what resolves during Plan: utility spell cards and utility `onUse` and `onRest` abilities), tests, and packages/cards/README.md › Triggers (an `onPlay` row, and the `onEnter` row's new text: each time the card enters, not on respawn), › Effects, › Targets and › Caster choices.
2. Core, as RULES.md › Zone mechanics says:
   - **When played:** core fires `onPlay` when `castUnit`, `castLeader` or `castPermanent` puts the card on the grid, just before its `onEnter`. A Chaos spawn fires `onEnter` only: Chaos cards are never played.
   - **Dump** moves the top `amount` cards of each target player's main deck to their discard pile, top card first, or all of them.
   - **Discard** moves `amount` cards, picked at random with the seeded RNG, from each target player's hand to their discard pile, or the whole hand when it has fewer. The `discard` plan action (the player's own choice) stays as it is. Cleanup's automatic hand-limit discard (RULES.md › Cleanup) now emits `cards.discarded` too.
   - **Revive** puts the unit card on its owner's grid, for free. It's a new card instance with a new id, like a fresh cast: level 1, printed durability, nothing carried over from before (buffs, debuffs, attached cards, levels). It enters but isn't played: `onEnter` fires, and `onPlay` fires before it only when the revive has `played: true`. A Plan revive uses the plan's `discardPileCard` target, and core rejects it (`plan.rejected`, with the closest existing reason) when the card isn't a unit card in the caster's discard pile or its footprint doesn't fit. A Simulate revive takes `lastDiscardPileUnit` and places it on the free cells nearest the front middle of the grid: row 1 first, then the column closest to the middle, ties to the left. It acts from the next tick. If it fits nowhere, nothing happens.
   - Nothing is revived from a void or another player's discard pile, and a Leader is never in a discard pile.
   - A revive never lands on the prize's cells (T-048), and the prize can't be dumped or revived: it's never in a pile.
   - Core tests for each rule in this list, in `dump.test.ts`, `discard.test.ts` and `revive.test.ts`, so the acceptance filter finds them.
3. Protocol: the target kind, the events, `PlayerSnapshot.discardPile`, the version bump, tests, and docs/PROTOCOL.md › Targets, › Card events, › Snapshot and › Versioning.
4. Bots: a `discardPileCard` target in the bots' target picking (the random bot picks any unit card and any fitting cell; the greedy bot the highest-cost unit card at the cell its placement would pick), with tests.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/core test -- dump discard revive` passes
- [ ] A core test: a unit with an `onPlay` and an `onEnter` ability fires both when cast, only `onEnter` when revived, and both when revived with `played: true`
- [ ] `grep -rn discardPileCount packages tools --include='*.ts'` prints nothing

## Out of scope

- Cards that use the new effects: T-057 and T-060
- Reviving into another player's grid, or reviving non-unit cards

## Notes

- A revived unit is a new card instance and a new squad (RULES.md › Zone mechanics › Revive): it gets a new `CardInstanceId` and a new `SquadId`, and respawn and durability start fresh.
- The DSL effect `discard` and the plan action `discard` share a name but not a namespace. Keep both.
- Existing cards keep `onEnter`. `onPlay` is for abilities that must not fire again on a revive, such as a copy (T-053, RULES.md › Copy).
- Default: a discard by an effect is public, like the discard pile it fills.
- Default: a revive during Simulate that can't be placed is skipped silently. A Plan revive that can't be placed is a rejection, so a bot's mistake shows.
- Default: a retired squad's card moves to the discard pile after its On death abilities resolve, so an On death revive never brings back its own card.
- Tokens are never played and never enter as cards: they fire neither `onPlay` nor `onEnter`, as now (`spawnTokens` emits only `unit.spawned`).
- If the protocol's rejection reasons have nothing close to "that card isn't in your discard pile", add one, and say so in the PR.
