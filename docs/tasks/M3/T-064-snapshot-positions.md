---
id: T-064
title: Positions in the snapshot
milestone: M3
depends_on: [T-053, T-096]
branch: agent/T-064-snapshot-positions
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
  - tools/sim-cli/test/**
context:
  - docs/DECISIONS.md#Decision log
  - docs/PROTOCOL.md#Arena layout
  - docs/PROTOCOL.md#Targets
  - docs/PROTOCOL.md#Visibility
  - docs/PROTOCOL.md#Snapshot
  - docs/RULES.md#Units
  - docs/RULES.md#Chaos deck and Emblems
  - docs/RULES.md#Traps (free-standing, face-down, automatic)
  - docs/tasks/M1/README.md#Defaults for open rules questions
---

# T-064 — Positions in the snapshot

## Goal

The snapshot should say where every permanent is. Today it lists only squads with a grid footprint and grid permanents. A Chaos squad, a token (RULES.md › Units › Token) and an Emblem appear only in events (`unit.spawned`), and no unit's live cell appears anywhere. So a bot can't aim at a Chaos squad, and a UI that reloads mid-round can't redraw the arena. This task adds every unit's world cell, the squads that have no footprint, and the Emblems' cells. With those in the snapshot, Chaos squads and other seats' tokens become valid squad targets.

## Interfaces

What exists (copied from the code):

```ts
// packages/core/src/state/state.ts:86-130
export interface Squad { id; owner: Owner; card; placement: Placement | null /* null for Chaos squads and tokens */; level; durability; isLeader; units: UnitId[]; … }
export interface Unit { id: UnitId; squad: SquadId; owner: Owner; cell: WorldCell; layer: Layer; hp: number; alive: boolean }
// packages/core/src/state/state.ts:136-160: an Emblem is a Permanent with kind 'emblem' and arenaCell: WorldCell
// packages/core/src/view/board.ts:39-44: squadSnapshot is null for Chaos, for placement null and for chaos cards
// packages/core/src/view/hide.ts: hidePlans keeps { round, counts, squads, permanents } from before the plans apply
// packages/core/src/view/snapshot.ts:32-41: ownLiveOthersBefore(seat, live, before, id) filters `before` by item.seat
// packages/core/src/effects/tokens.ts: isToken(state, squad); packages/core/src/effects/stats.ts:291 maxHp(state, unit)
// packages/core/src/effects/keywords.ts:149 effectiveKeywords(state, unit, changes?): printed + static grants + lasting grants
// packages/core/src/view/cards.ts:71 unitFacts(…).keywords is keywordsOf(card.keywords): the card's printed keywords
// packages/protocol/src/card.ts:79 Keywords = z.array(Keyword), each keyword at most once (no values)
// packages/protocol/src/snapshot.ts:204, :214
ChaosSnapshot { card, cardId, kind: ChaosKind, targets: Seat[] }
EmblemSnapshot { permanent, cardId, hp: Hp, points }
// packages/protocol/src/primitives.ts:13, :106, :129
Owner = Seat | 'chaos'; WorldCell { x, y }; Layer = 'ground' | 'air'
```

What this task adds:

```ts
// protocol
UnitSnapshot { unit: UnitId, squad: SquadId, owner: Owner, cell: WorldCell, layer: Layer, hp: Hp, maxHp: Hp, alive: boolean, keywords: Keywords }
SpawnedSquadSnapshot { squad: SquadId, owner: Owner, card: CardInstanceId, cardId: CardId, kind: 'chaos' | 'token', stats: UnitStats, keywords: Keywords, level: Level }
Snapshot: + units: z.array(UnitSnapshot)            // every unit of every squad, by id
Snapshot: + spawned: z.array(SpawnedSquadSnapshot)  // every squad without a grid footprint, by id
ChaosSnapshot: + squads: SquadId[]                  // the squads it spawned this round; empty when none
EmblemSnapshot: + cell: WorldCell
export const PROTOCOL_VERSION = /* T-053's + 1 */;
// core
squadGridCell(state, squad): { seat: Seat; cell: Cell } | null // the grid a squad counts as standing on, and its cell there
```

## Deliverables

1. **Units.**
   - `Snapshot.units` lists every unit of every squad, sorted by unit id: players' squads, Leaders, tokens and Chaos squads, alive or dead.
   - `cell` is the unit's world cell (PROTOCOL.md › Arena layout): its live cell mid-Simulate, and its start cell or spawn cell during Plan. A dead unit keeps the cell where it died. `maxHp` comes from `maxHp(state, unit)`, so it includes buffs.
   - A unit of a squad the seat can't see (Deliverable 4) isn't listed.
   - `keywords` are the unit's keywords now: printed plus granted (`effectiveKeywords`), each listed once, so a bot can see a granted Ward or Shield. Compute the static changes once per snapshot and pass them in, not once per unit. A squad's own `keywords` (`SquadSnapshot`, `SpawnedSquadSnapshot`, cards in hand) stay the card's printed ones.
2. **Spawned squads.**
   - `Snapshot.spawned` lists every squad without a grid footprint, sorted by squad id. `kind` is `chaos` for a Chaos squad and `token` for a token (`isToken`).
   - Bots can't read card definitions, so `stats` and `keywords` are the printed ones of the unit the squad was spawned as: the token's card, or the Chaos card's units. `level` is the squad's level.
   - `ChaosSnapshot.squads` names the squads each Chaos card spawned this round, so a UI can group them. It's empty for a rule, an Emblem or nothing.
3. **Emblems.** `EmblemSnapshot.cell` is the Emblem's `arenaCell`.
4. **Hidden plans.**
   - While plans are hidden, a seat sees its own units and spawned squads live, and every other owner's from before the plans applied. Chaos counts as another owner. A token that a utility spell spawned during this Plan stays hidden from the other seats until the plans are revealed, the way a newly placed squad does today.
   - `hidePlans` also keeps `units` and `spawned`. Generalize `ownLiveOthersBefore` to filter by owner, not `seat`.
   - Emblems stay live: plans can't change them.
5. **Targets.**
   - A `squad` plan target with side `opponent` or `any` may now name a Chaos squad or another seat's token. Lift T-042's restriction on `chosenEnemyUnit`. Check every caster choice that takes a squad and say in the PR which ones accept Chaos squads. The prize stays immune (T-048).
   - **The nearest squad.** Move the "caster's squad nearest a grid cell" rule into one helper that `mirroredTarget` (T-042) and copy (T-053) both use:
     - `squadGridCell` says where a squad stands. A squad with a footprint stands on its owner's grid, at its top-left cell. A squad without one stands under its lowest-id living unit: that unit's world cell converted to a grid's coordinates (the inverse of PROTOCOL.md › Arena layout's `toWorld`, clamped to the grid's nearest cell). A token uses its owner's grid. A Chaos squad uses the grid of the first seat in its card's `targets`, or the caster's grid when there's none. A squad with no living unit stands nowhere (null).
     - The chosen squad's cell is carried over to the caster's grid unchanged. The candidates are every caster squad that stands somewhere, tokens included (a token is a squad), and the Leader counts.
     - Distance is Chebyshev (M1 README › Defaults). Ties go to the lowest squad id. With no candidate, the spell does nothing.
6. **Bots.** Their target lists for a `squad` plan target on the opponent side now include Chaos squads and other seats' living tokens, read from `units` and `spawned`. Keep the change small and say in the PR how they choose. Update only the goldens this changes, and say why in the PR.
7. **Tests:**
   - protocol: parse and round-trip `UnitSnapshot`, `SpawnedSquadSnapshot`, and the new `ChaosSnapshot` and `EmblemSnapshot` fields.
   - core view: a unit that a static aura gives Ward and one with a lasting Shield grant list those keywords in `Snapshot.units`, while their squad's `keywords` stay printed.
   - core view:
     - a Chaos squad and a token appear in `units` and `spawned`, with world cells inside the arena
     - an Emblem has its cell
     - mid-Simulate, a unit's cell is the `to` of its last `unit.moved`
     - while plans are hidden, another seat's new token and its units aren't listed, and they appear after `plans.revealed`
   - core plan: a `chosenEnemyUnit` choice naming a Chaos squad is accepted. One naming the prize is still rejected.
   - core: `squadGridCell` for a squad with a footprint, a token, a Chaos squad (clamped onto its target's grid) and a squad with no living unit, plus a tie between two of the caster's squads.
   - core sim: Mirror Snare reflects a spell aimed at a token in its area onto the caster's nearest squad, a token in this case.
   - bots: the greedy bot can aim an offensive squad spell at a Chaos squad.
8. **Docs.**
   - docs/PROTOCOL.md: › Snapshot gets the two new rows and a subsection for `UnitSnapshot` and `SpawnedSquadSnapshot`. Add `squads` and `cell` to › `ChaosSnapshot` and `EmblemSnapshot`. › Visibility gets a sentence on hidden plans (Deliverable 4), › Targets says Chaos squads and tokens can be targets, and › Versioning gets a line.
   - packages/core/README.md: the view's new fields, if it describes them.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] A core test plays one game with four greedy bots (seed 1). After each round's `plans.revealed`, every living unit in `Snapshot.units` has the cell the log last gave it (`unit.spawned`, `unit.moved` or `unit.respawned`).

## Out of scope

- When a token expires: events carry it (T-065 adds `squad.despawned`), and the M4 UI can ask for it.
- Per-unit statuses (rested, feared, Shield left): events carry them (T-051's Notes). Granted keywords are in (Deliverable 1); how much Shield is left isn't.
- A Chaos artifact's position: Chaos artifacts are Emblems in RULES.md, so Deliverable 3 covers them.

## Notes

- Decision (lead, 2026-10-22): the snapshot shows where every permanent is, Chaos squads, tokens and Emblems included. Chaos squads and other seats' tokens can be chosen as squad targets.
- Decision (lead, 2026-10-22): Mirror Snare and copy share the nearest-squad rule in Deliverable 5. A squad without a footprint counts as standing under its lowest-id living unit (RULES.md › Sample cards › Traps).
- Default: a Chaos squad counts as standing on the grid of the first seat it was sent against. During Plan its units are still on the Chaos Grid, so the clamp puts it on that grid's edge nearest to them.
- Decision (human, 2026-10-26, from the merged M3 tasks' open questions): snapshot keywords were printed only, so a bot couldn't see a granted Ward and kept aiming at it. `UnitSnapshot.keywords` shows printed plus granted.
- Default: `units` lists dead units too, with `alive: false`, so a UI can tell a dead unit from a hidden one. A token's dead units stay listed until the token expires.
