---
id: T-048
title: The prize
milestone: M3
depends_on: [T-047]
branch: agent/T-048-prize
model: sonnet
effort: high
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/core/src/**
  - packages/core/test/**
  - packages/core/README.md
  - packages/bots/src/**
  - packages/bots/test/**
  - tools/sim-cli/src/**
  - tools/sim-cli/test/**
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Components and setup
  - docs/RULES.md#Non-unit permanents and spells
  - docs/RULES.md#Scoring and winning
  - docs/RULES.md#Simulation rules
  - docs/PROTOCOL.md#Snapshot
---

# T-048 — The prize

## Goal

Every player has a prize: a 2×2 static permanent that the game places in the middle of their grid (D25, RULES.md › Non-unit permanents › Prize). An opponent who destroys it scores points, so a player who builds nothing still gives points away when attacked. It has no attack and no abilities. Only damage affects it. It respawns at Cleanup.

## Interfaces

What exists (copied from the code):

```ts
// packages/core/src/state/state.ts:136-160
export type PermanentKind = 'trap' | 'artifact' | 'enchantment' | 'emblem';
export interface Permanent { id; card: CardInstanceId; kind; owner; mode; attachedTo; placement; arenaCell; hp; durability; alive; faceDown; … }
// packages/protocol/src/event.ts:450, :462. An Emblem's damage and destruction already use these.
PermanentDamagedEvent { type: 'permanent.damaged', permanent, source, amount, hp }
PermanentDestroyedEvent { type: 'permanent.destroyed', permanent, owner, killer, faceDown }
// packages/protocol/src/event.ts:508
export const ScoreReason = z.enum(['kill', 'leaderKill', 'chaosKill', 'emblem', 'survival', 'chaos']);
// packages/core/src/scoring/points.ts:105-117: survival counts seats with a unit alive.
```

What this task adds:

```ts
PermanentKind: + 'prize'           // core; its `card` is null, the only permanent without one
// core config
prizeSize: [2, 2], prizeHp: 20, prizePoints: 2
// protocol
PrizeSnapshot { permanent: PermanentId, seat: Seat, cell: Cell, size: Size, hp: Hp, maxHp: Hp, alive: boolean }
Snapshot board: prizes: z.array(PrizeSnapshot) // one per seat, in seat order
ScoreReason: + 'prize'
export const PROTOCOL_VERSION = /* T-047's + 1 */;
```

## Deliverables

1. **Setup.**
   - `createGame` places one prize per seat, anchored at grid cell `{ col: (cols − 2) / 2, row: (rows − 2) / 2 }`: cells 14–15 with the 30 × 30 default (RULES's 15–16, counted from 1). On an odd-sized grid it rounds down.
   - Its owner is the seat. It is never in a deck, a hand or the discard pile.
2. **Placement.** The prize's cells are blocked for every placement: units, Leaders, `moveLeader`, free-standing permanents, traps and moves by effects. The bots' grid treats them as taken.
3. **Combat.**
   - It is a target like a free-standing artifact: attacks, projectiles, Trample splash and areas hit it.
   - Area damage hits every permanent of the side it names, not only units (RULES.md › Simulation rules › Area damage). Today the damage handler's group targets and `trample.ts` collect units only. Make one helper collect, on the affected cells, the units, free-standing artifacts and enchantments, revealed traps, the prize and Emblems, and use it for damage with a scope (`radius`, `area`, `zone`) and for the splash. Face-down traps and attached cards are never collected. Damage without a scope, and every other effect, still reach units only. Under Fog of War's friendly splash, the attacker's own permanents are hit too.
   - It never moves, attacks or triggers anything.
   - Blocker can't come from it, and Chaos targets it like any player permanent.
4. **Immunity.** No spell or ability chooses it, and no effect but damage changes it. Every effect handler skips it, including the ones T-049 to T-053 add: rest, fear, move, push, buff, heal, kill, sacrifice, banish, level, copy and grantKeyword. A `kill` effect on a group skips it. Put the check in one place, such as an `isPrize` guard where effects collect their targets, so later effects get it for free.
5. **Scoring.**
   - Destroying an opponent's prize scores `prizePoints` to the destroyer's owner, with reason `prize`. A seat's own units or Chaos destroying it score nothing.
   - It doesn't count for survival or for "no units left": those checks look at units only, so make sure they still do. `chaosWon` also counts a player's targetable permanents (RULES.md › Round structure › End conditions): leave the prize out of that count, so a seat with only its prize left counts as having nothing.
6. **Cleanup.** A destroyed prize respawns at full HP, at the start of the respawn step. It has no durability. Don't add an event for the respawn: T-065 adds `permanent.respawned` for every permanent that stands again.
7. **Protocol.**
   - `PrizeSnapshot` and `board.prizes`. Every seat sees every prize: it's public.
   - `ScoreReason` `prize`.
   - The permanent events now cover prizes: update their doc comments.
   - Bump `PROTOCOL_VERSION`.
8. **Bots.** The greedy bot sees a prize as a target worth `prizePoints` when it weighs aggressive plans, and it never targets one with a spell. Keep the change small and say in the PR how it scores.
9. **Tests:**
   - core: setup places 4 prizes, and placing a unit on a prize cell is rejected
   - core sim: a melee unit kills an undefended prize, its owner scores 2, and the prize respawns at Cleanup
   - core: a group `kill`, a `push` and a `buff` all leave the prize alone, while an area `damage` hits it
   - core: an area `damage` and a Trample splash destroy an enemy artifact and a revealed trap but not a face-down trap, and `enemies` damage without a scope (Ember Rain) leaves the artifact alone
   - core: a seat with only its prize left doesn't get the survival point
   - bots: the greedy and random bots never place on the prize's cells
10. **Docs.** docs/PROTOCOL.md › Snapshot and the score reasons, and a line in › Versioning. packages/core/README.md: the prize in its state description, plus the config values.

## Acceptance

- [ ] `crew check` green
- [ ] An ASCII map test of the default battlefield shows the 4 prizes
- [ ] Over `pnpm sim --bots greedy,greedy,greedy,greedy --games 20 --seed 1`, the PR reports how many prize points were scored per game. More than zero means prizes are reachable.

## Out of scope

- The prize's art: M4
- Lobby options for the prize's numbers: they're config, and that's enough for now

## Notes

- Decision (lead, 2026-10-22): areas and the Trample splash damage every enemy permanent, not only units (RULES.md › Area damage).
- Default: the prize's HP doesn't scale with the round or with levels.
- Default: a prize has no owner-side effects, so the owner's own `allUnits` areas hit it too. Friendly fire scores nothing.
- If a card from T-049 to T-053 needs a different prize rule, that card asks `lead`. This card sets the immunity rule.
