---
id: T-049
title: Void, banish and sacrifice
milestone: M3
depends_on: [T-048]
branch: agent/T-049-banish-sacrifice
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
  - docs/RULES.md#Components and setup
  - docs/RULES.md#Zone mechanics
  - docs/RULES.md#Scoring and winning
  - packages/cards/README.md#Caster choices
  - packages/cards/README.md#Spell classes
  - docs/PROTOCOL.md#Targets
  - docs/PROTOCOL.md#Card events
---

# T-049 — Void, banish and sacrifice

## Goal

Two of the four zone mechanics in RULES.md › Zone mechanics: banish (to the new void zone) and sacrifice. Cards can write them in the DSL, core resolves them, the protocol reports them, and the bots can aim them. The prize is immune to both (T-048). No card uses them yet; T-057, T-058 and T-060 write those cards.

## Interfaces

What exists (copied from the code, after T-040 to T-048):

```ts
// packages/core/src/zones/state.ts:10
export const SEAT_ZONES = ['deck', 'hand', 'discardPile', 'resourceDeck', 'resourcePool', 'command'] as const; // T-040's names
// packages/cards/src/dsl.ts:56-73
export const UNIT_TARGETS = ['self', 'attackTarget', 'killer', 'attachedUnit', 'triggeringUnit', 'nearestEnemy', 'chosenOwnUnit', 'chosenEnemyUnit'] as const; // chosenEnemyUnit: T-042
export const UNIT_GROUP_TARGETS = ['enemies', 'ownUnits', 'allUnits', 'killerUnits'] as const;
export const PLAYER_TARGETS = ['owner', 'allPlayers', 'destroyer', 'opponents'] as const; // opponents: T-043
export const PERMANENT_TARGETS = ['ownPermanents', 'chosenOpponentTraps'] as const;
// EFFECTS (dsl.ts:267) comes from EFFECT_SCHEMAS; each effect has a handler in
// packages/core/src/effects/handlers/. spells.ts maps every target to its side (chosenOwnUnit: 'own').
// packages/protocol/src/target.ts: Target and TargetSpec kinds seat, row, area, squad, squadToCell.
// packages/protocol/src/event.ts:301 SquadRetiredEvent { squad }; :510 ScoreReason 'kill', …
// packages/protocol/src/snapshot.ts:70 PlayerSnapshot { …, discardPileCount, … }
```

What this task adds:

```ts
// core
SEAT_ZONES: [..., 'void'] // banished cards, in the order they arrived; nothing leaves it
// cards DSL
{ effect: 'banish', target: <unit, unit group or permanent target>, scores?: true } // scores: it scores like a kill
{ effect: 'banish', from: 'discardPile' | 'deckTop' | 'hand', amount: <number>, target: <player target> }
{ effect: 'sacrifice', target: 'self' | 'chosenOwnUnit' | 'ownPermanents' }
// protocol
CardBanishedEvent { type: 'card.banished'; seat; card: CardInstanceId; cardId: CardId; from: 'grid' | 'discardPile' | 'deck' | 'hand'; squad?: SquadId }
SquadSacrificedEvent { type: 'squad.sacrificed'; squad: SquadId }   // after its units' unit.died
ScoreReason: [..., 'banish']
PlayerSnapshot: { ..., void: CardId[] } // the void is public, oldest first
PROTOCOL_VERSION + 1
```

## Deliverables

1. Cards: the two effects in the DSL, their side in spells.ts (banish takes its target's side, sacrifice is own side), validator errors for a bad target or a missing `amount`, tests, and packages/cards/README.md › Effects, › Targets and › Caster choices.
2. Core, as RULES.md › Zone mechanics says:
   - **Banish** from the grid removes the whole squad without a death: no On death, no respawn, no durability lost. Its attached cards go to their owners' discard piles, and its attached resources return to the pool. A banish scores nothing, unless the effect has `scores: true` and the permanent is an opponent's: then the banisher scores `banish` points as if each living unit were killed. A Leader can't be banished: it dies instead, and scores as a kill. A non-unit permanent goes to the void the same way.
   - **Banish from a discard pile** takes the `amount` cards that arrived last; **from the deck top** takes the top `amount`; **from a hand** takes `amount` cards picked at random with the seeded RNG. Fewer cards means all of them. These banishes never score.
   - **Nothing prevents them.** Banish and sacrifice take the card off the grid even from a unit that an effect keeps from dying: a static ability that stops a unit dying doesn't stop them. T-051's Shield and Extra life will skip them too, so give the removal a cause that a later keyword can check.
   - **Sacrifice** kills the permanent's living units (On death fires), sends its card to its owner's discard pile instead of respawning, and scores nothing. Leaders can't be sacrificed. If a sacrifice has nothing to sacrifice when it resolves, the ability or spell card that asks for it does nothing: none of its effects resolve. The card's other abilities aren't affected.
   - The prize can be neither banished nor sacrificed: the T-048 guard skips it, and a group banish leaves it alone.
   - Events and the snapshot as above; core tests for each rule in this list, during Plan and during Simulate, in `banish.test.ts` and `sacrifice.test.ts`, so the acceptance filter finds them.
3. Protocol: the events, the score reason, `PlayerSnapshot.void`, the version bump, tests, and docs/PROTOCOL.md › Card events, › Chaos and score, › Snapshot and › Versioning.
4. Bots: a sacrifice target is one of the bot's own squads that isn't its Leader, with a test. `chosenEnemyUnit` already has a target in the bots' picking (T-042).

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/core test -- banish sacrifice` passes
- [ ] `pnpm cards:validate` passes

## Out of scope

- Dump, discard and revive: T-050. Shield, Extra life and Ward: T-051.
- Cards that use the new effects: T-057, T-058 and T-060

## Notes

- Default: a squad banished in the middle of Simulate leaves at once; a projectile already flying at it lands on nothing.
- Default: `PlayerSnapshot.void` lists card ids, not instance ids, because nothing can pick a card out of the void.
- Default: a banished Chaos unit has no void to go to. It despawns. With `scores`, its banisher scores `chaosKill` as for a kill; without it, nothing. List it in the PR.
- Default: a hand banish is public. The banished cards go to the void, which every player sees, so `card.banished` names them.
- The Chaos card that was Void Maw is Abyss Maw since T-040, so "void" names only the zone.
