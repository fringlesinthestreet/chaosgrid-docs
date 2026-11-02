---
id: T-065
title: Permanent and token events
milestone: M3
depends_on: [T-064, T-099]
branch: agent/T-065-permanent-events
model: sonnet
effort: high
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/core/src/**
  - packages/core/test/fixtures/effects/**
  - packages/core/test/fixtures/round/board.ts
  - packages/core/README.md
  - tools/sim-cli/test/golden/**
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Round structure
  - docs/RULES.md#Non-unit permanents and spells
  - docs/PROTOCOL.md#Board
  - docs/PROTOCOL.md#Card events
  - docs/PROTOCOL.md#Visibility
  - docs/PROTOCOL.md#Versioning
---

# T-065 — Permanent and token events

## Goal

The event log should say whenever a permanent loses Durability, stands again, or leaves the game. Squads already get events for these (`squad.durabilityChanged`, `squad.retired`, `unit.respawned`). Traps, artifacts, enchantments and the prize get none:

- At Cleanup a destroyed one loses 1 Durability, goes to the discard pile at 0, or stands again, and nothing is reported.
- A Durability heal on a permanent changes it without an event.
- A fired trap goes to the discard pile without an event.
- A token that leaves the game reports its units' `unit.died`, then its squad vanishes without an event.

So a UI or a replay can't follow a permanent from the log alone. This task adds one event for each of these cases.

## Interfaces

What exists (copied from the code on 2026-10-22; T-040 to T-064 rename and move some of it, so look for the current names):

```ts
// packages/protocol/src/event.ts
'squad.durabilityChanged' { squad: SquadId, durability: Durability } // :294, visible to all
'squad.retired' { squad: SquadId }                          // :303, visible to all
'unit.respawned' { unit: UnitId, at: WorldCell, hp: Hp }    // :271, visible to all
'permanent.destroyed' { permanent: PermanentId, owner: Owner, killer: Owner | null, faceDown: boolean } // :463
// packages/protocol/src/visibility.ts:30: permanent.destroyed is visible to all unless faceDown, then to its owner only
// packages/core/src/round/cleanup.ts
toGraveyard(ctx, permanent, report = true)  // :48, the discard pile after T-040. With report, a standing permanent gets permanent.destroyed (killer null); then the card moves and the permanent is deleted
discardFiredTraps(ctx)                       // :71, step 3: toGraveyard(ctx, trap, false), silent
restorePermanents(ctx)                       // :119, step 4: an attached card whose squad is gone goes to the pile; a destroyed one loses 1 Durability, goes to the pile at 0, or stands again at PERMANENT_HP, all silent
// packages/core/src/effects/health.ts:120 restoreDurability(ctx, target, amount): squad.durabilityChanged for a squad, nothing for a permanent
// packages/core/src/effects/tokens.ts:104 despawn(ctx, squadId): unit.died (killer null) for living units, permanent.destroyed for standing attached cards, then deletes the units, the squad and the card instance. Called by despawnTokens (:140) mid-Simulate and at Cleanup
```

What this task adds:

```ts
// protocol, Board events
PermanentDurabilityChangedEvent { type: 'permanent.durabilityChanged', permanent: PermanentId, owner: Owner, durability: Durability, faceDown: boolean }
PermanentRespawnedEvent { type: 'permanent.respawned', permanent: PermanentId, owner: Owner, hp: Hp, faceDown: boolean }
PermanentRetiredEvent { type: 'permanent.retired', permanent: PermanentId, owner: Owner, faceDown: boolean }
SquadDespawnedEvent { type: 'squad.despawned', squad: SquadId }
export const PROTOCOL_VERSION = /* T-099's + 1 */;
```

## Deliverables

1. **Protocol.**
   - Add the four events to `Event`, each with a doc comment in the style of its neighbors.
   - In `isVisibleTo`, the three `permanent.*` events follow `permanent.destroyed`'s rule: visible to everyone, but only to `owner` while `faceDown`. `squad.despawned` is visible to everyone.
   - Add samples to `packages/protocol/test/fixtures/samples.ts` and bump `PROTOCOL_VERSION`.
2. **Cleanup** (`round/cleanup.ts`):
   - A destroyed permanent that prints a Durability loses 1: `permanent.durabilityChanged`. At 0 it goes to the discard pile: `permanent.retired` comes next, mirroring `squad.durabilityChanged` then `squad.retired`.
   - A destroyed permanent that stands again gets `permanent.respawned`, with the HP it stands with. This covers traps, artifacts and enchantments, and T-048's prize, which respawns at full HP.
   - An attached card whose squad left the board goes to the discard pile: `permanent.retired`. If it was still standing, `permanent.destroyed` (killer null) comes first, as it does today.
   - A fired trap goes to the discard pile at step 3: `permanent.retired`.
3. **Durability heals** (`effects/health.ts`). `restoreDurability` on a permanent emits `permanent.durabilityChanged` when it restores anything, as it already does for squads.
4. **Tokens** (`effects/tokens.ts`). `despawn` emits `squad.despawned` after its units' `unit.died` and its attached cards' `permanent.destroyed`, and before it deletes the squad. This happens both mid-Simulate and at Cleanup.
5. **The sweep.**
   - Check every code path that deletes from `state.permanents` or `state.squads`, or changes a permanent's `durability`. Each must emit exactly one leaving event, or one `permanent.durabilityChanged`.
   - The leaving events for a permanent are `permanent.retired`, `card.banished` (T-049) and `chaos.despawned`. For a squad they are `squad.retired`, `squad.sacrificed` (T-049), `squad.despawned` and `chaos.despawned`, where a Chaos squad is listed through its units.
   - List the paths in the PR.
6. **Goldens.** Update only the golden rounds this task changes, and say in the PR which events they gained.
7. **Tests:**
   - protocol: parse and round-trip each event. A face-down permanent's three events are visible only to their owner, and `squad.despawned` is visible to every seat.
   - core cleanup:
     - an artifact with Durability 2 destroyed in one round gives `permanent.durabilityChanged` (1) and then `permanent.respawned`
     - destroyed again in a later round, it gives `permanent.durabilityChanged` (0) and then `permanent.retired`, and its card is in the discard pile
     - one with no printed Durability gives only `permanent.respawned`
     - a fired trap gives `permanent.retired`
     - an attached card on a squad that retired gives `permanent.retired` after that squad's `squad.retired`
     - a destroyed prize gives `permanent.respawned` with its full HP
   - core health: a Durability heal on an artifact gives `permanent.durabilityChanged`.
   - core tokens:
     - a token that expires mid-Simulate gives `unit.died` for each living unit, then `squad.despawned`
     - a token that lasts until Cleanup gives `squad.despawned` at Cleanup
8. **Docs:**
   - docs/PROTOCOL.md:
     - add rows for the four events to › Board (`squad.despawned`, `permanent.durabilityChanged`, `permanent.respawned`) and › Card events (`permanent.retired`), placing each where its neighbors fit
     - extend the Durability bullet: "a permanent's changes are `permanent.durabilityChanged`, and at 0 `permanent.retired` comes next"
     - add a row to › Visibility and a line to › Versioning
     - if `trap.fired`'s row says the trap leaves silently, update it
   - packages/core/README.md: if it lists Cleanup's events, add these.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] A core test plays `playGame(gameSetup(4), 10)` from `packages/core/test/fixtures/round/games.ts` and checks every round against its states. Each permanent and squad that is in the round's events but not in `played.state` got exactly one leaving event (Deliverable 5). Each permanent that was destroyed and is still in `played.state` got `permanent.respawned`. Each `permanent.durabilityChanged` gives the Durability the state ends the round with, unless a later event in that round changed it.

## Out of scope

- A permanent's starting Durability on `permanent.placed`. The snapshot already has it (`PermanentSnapshot.durability`), and the card prints it.
- Chaos squads and Emblems: `chaos.despawned` already reports them at Cleanup.
- Banish, sacrifice and revive: T-049 and T-050 add their events (`card.banished`, `squad.sacrificed`, `squad.revived`). Check them only in the sweep.
- How the UI shows these events (M4).

## Notes

- Decision (human, 2026-10-22): losing Durability is an event of its own, and reaching 0 is another: the card goes to the discard pile, or the token leaves the game.
- Default: a fired trap gets `permanent.retired` too, so every permanent that leaves the grid gets one leaving event. `trap.fired` still says when it fired.
- Default: a squad never gets more than one leaving event. A token that is sacrificed or banished gets T-049's event, not `squad.despawned` as well.
- Default: `permanent.respawned` has no `at`, because a permanent stands again where it was.
- This task covers T-048's prize respawn, which planned no event, and T-064's "when a token expires" (› Out of scope there): `squad.despawned` says it.
- T-061 edits `packages/core/test/fixtures/round/games.ts` at the same time. Import from it, but don't edit it. Put new helpers in `board.ts` or `effects/`.
