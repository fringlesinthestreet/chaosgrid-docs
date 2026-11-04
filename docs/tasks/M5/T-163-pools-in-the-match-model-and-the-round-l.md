---
id: T-163
title: Pools in the match model and the round log
milestone: M5
depends_on: [T-157]
branch: agent/T-163-pools-in-the-match-model-and-the-round-l
model: sonnet
effort: medium
scope:
  - apps/web/src/match/model/**
  - apps/web/src/match/overlays/log.ts
  - apps/web/src/match/overlays/log.test.ts
  - apps/web/src/i18n/en/overlays.json
context:
  - docs/APPS.md#The match
  - apps/web/README.md#Text (D50)
  - apps/web/README.md#Tests
---

# T-163 — Pools in the match model and the round log

## Goal

The human asked for events that say a resource was played, rested for mana or rested for its ability (playtest, 2026-11-04). T-155 and T-157 add them to the protocol, public to every seat (D57). After this task the web's match model keeps every seat's resource pool from those events, and the round log says what each seat played, rested and attached. T-161 draws the pools behind the grids from this model, and T-162 reads its rested permanents and attached resources.

## Interfaces

What exists (copied on 2026-11-04, and from the T-155 and T-157 cards):

```ts
// packages/protocol (T-155, T-157), every one visible to every seat:
// PoolCard { card: CardInstanceId; cardId: CardId; rested: boolean; attachedTo: SquadId | null }
// ResourcePlayedEvent    { type: 'resource.played', seat, card, cardId, rested }   // a resource entered a pool
// ResourceRestedEvent    { type: 'resource.rested', seat, card, cardId, reason: 'mana' | 'ability' }
// ResourcesAttachedEvent { type: 'resources.attached', seat, squad, resources }    // an attach action
// ResourcesDetachedEvent { type: 'resources.detached', seat, squad, resources }    // back in the pool mid-round
// ResourcesSpentEvent    { type: 'resources.spent', seat, resources }              // Cleanup: to the resource deck's bottom
// PermanentRestedEvent   { type: 'permanent.rested', permanent }
// Cleanup's resets have no events: every resource and permanent unrests, and every attached
// resource returns to its pool, before `round.ended` (PROTOCOL.md says so).

// apps/web/src/match/model/types.ts
export interface MatchModel { seats; settings; round; phase; tick; arena; points; squads; units;
  projectiles; permanents; chaos; simulateEnding; simulateEnded; winners; log: LogEntry[] }
export interface LogEntry { round: number; tick: number | null; event: Event }
export const LOGGED_EVENT_TYPES: readonly EventType[];   // what the log keeps
export const EMPTY_MODEL: MatchModel;
// PermanentModel { permanent, kind, owner, cardId, where, faceDown, hp, maxHp, durability, points, alive, ... }

// apps/web/src/match/model/apply.ts: applyEvent(model, event) folds one event; each logged case
// calls log(model, event). `case 'round.ended'` sets the scores, then unrests every unit.

// apps/web/src/match/overlays/log.ts
export interface Names { card(cardId: string): string; seat(seat: Seat): string }   // "You" for the viewer
export function describeLogEntry(entry: LogEntry, model: MatchModel, names: Names): string;
// squadLabel(model, names, squad) names a squad ("Seat 2's Cinder Grunt"); possessive(names, seat).
// roundSummary(model, round) switches on the logged types too.
```

## Deliverables

1. **`MatchModel.pools`**, `Record<Seat, PoolCard[]>` in pool order, one list per seat, empty at the start.
2. **The fold** in `apply.ts`:
   - `resource.played` adds the card to its seat's pool, rested as the event says, unattached.
   - `resource.rested` rests it. `resources.attached` sets `attachedTo` on each of its resources, and `resources.detached` clears it.
   - `resources.spent` removes them from the pool.
   - `round.ended` unrests every pool card and clears every `attachedTo`, as it unrests the units.
   - An event about a card the pool doesn't hold changes nothing and doesn't throw, as the model's other cases do.
3. **Rested permanents:** `PermanentModel.rested`, false when a permanent appears, set by `permanent.rested`, and cleared at `round.ended`.
4. **`attachedResources(model, squad): PoolCard[]`**, exported from `model/index.ts`: the pool cards attached to that squad. T-161's card view and T-162's Charge glow read it.
5. **The log** keeps `resource.played`, `resource.rested` and `resources.attached`, and `describeLogEntry` words them through `t()`, with the keys in `en/overlays.json`:
   - `log.resourcePlayed` "{seat} played {card}";
   - `log.resourceRestedForMana` "{seat} rested {card} for mana";
   - `log.resourceRestedForAbility` "{seat} rested {card} for its ability";
   - `log.resourcesAttached` "{seat} attached {count, plural, one {# resource} other {# resources}} to {squad}".
   `roundSummary` leaves them out of the summary.
6. **Tests:**
   - `apply.test.ts`: each event above, in order, on a model with two seats' pools. Also `round.ended`'s reset, `permanent.rested` and its reset, an event for an unknown card, and `attachedResources`.
   - `log.test.ts`: each line, with "You" for the viewer's seat and "Seat 2" for another; a `resource.rested` for an ability; an attach of one resource and of two.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test model log` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Drawing the pools and the piles, and what a click on them shows: T-161.
- Rested and charged cues on the battlefield and in PlanGrid: T-162.
- The log's existing lines, which are still plain strings: they move to `t()` when their own card comes.

## Notes

- Defaults: `resources.detached`, `resources.spent` and `permanent.rested` change the model but aren't logged, since the pools behind the grids show them. `resource.drawn` stays out of the model: the seat that drew sees the card when it's played.
- Plan's draws reach the model only when the plans apply (T-157), so during Plan the model's pools are as Plan opened, the viewer's own included. T-161 draws the viewer's live pool from the planning view.
- The PR lists the keys it added to `en/overlays.json`.
