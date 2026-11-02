---
id: T-122
title: Effect sprites and spell casts
milestone: M5
depends_on: [T-121]
branch: agent/T-122-effect-sprites
model: sonnet
effort: high
scope:
  - apps/web/src/match/battlefield/**
context:
  - docs/ART.md#Keys
  - docs/ART.md#Sizes
  - docs/ART.md#Events
  - docs/ART.md#Fallbacks
  - apps/web/README.md#Rules a change must keep
---

# T-122 — Effect sprites and spell casts

## Goal

When the thing an event is about doesn't play an animation of its own (T-120), the battlefield plays the event's `fx.*` sprite, and shows today's code effect only when that's missing too. A spell's or a resource's `cast` plays on `spell.resolved`, centred on its target (D45). With no art manifest the battlefield looks as it does today.

## Interfaces

What exists (copied from the code on 2026-10-29). T-111, T-117, T-118, T-136, T-120 and T-121 change the battlefield first, so re-read scene.ts and grid.ts and keep their additions; T-112 edits model/apply.ts, so its line numbers may have moved:

```ts
// apps/web/src/match/battlefield/scene.ts
const CELL = 16; // :24, view px per cell
export interface SceneOptions { viewer; cards: ReadonlyMap<string, Card>; onBanner?; clock? } // :38-45
// `cards` holds every card the match loaded, spells, resources and Chaos cards included
//   (match/session.ts:36-37); the replay passes the whole catalog.
class Scene {}
// centers (:379): each squad's, permanent's and unit's centre in view px, set by syncSquads (:611),
//   syncPermanents (:635) and syncUnits (:677), and never deleted.
// rectPx(rect: WorldRect) (:519): a world rect in view px, turned for the viewer. squadRect(arena,
//   squad) (:534) = rectPx(footprintRect(seat, squad.cell, squad.size, squad.rotated)), with the seat
//   found in arena.seats; permanentRect(arena, model, permanent) (:539).
// draw (:437) syncs the views, then calls playEffects(model, step, now) (:717): the helpers at,
//   colorOf, flash, glow, puff, number and unitsOf (:718-744), then one handler per event (:745-800):
//     unit.died → puff(unit) (:758)
//     ability.triggered → flash(source) (:759); trap.fired → flash(permanent, warning) (:760)
//     unit.shielded → ArtView('ui.shield', CELL) on the unit, fading (:768-775)
//     unit.saved → flash(unit) and the '+LIFE' number (:776-779)
//     squad.sacrificed → flash(squad, error) (:780)
//     squad.revived, unit.respawned, permanent.respawned → glow (:781-783)
//     squad.despawned → a puff on each of the squad's units in the model, else on the squad (:784-788)
//     chaos.despawned → a puff on each of its units and permanents (:789-791)
//     card.banished → a bg-coloured burst on its squad or permanent (:792-795)
//     emblem.broken → two bursts (:796-799)
//   Nothing handles spell.resolved. burst(point, color, kind, now, cells = 1) (:809); addEffect (:825).

// apps/web/src/match/battlefield/grid.ts
footprintRect(seat: ArenaSeat, cell: Cell, size: Size, rotated: boolean): WorldRect; // :13
gridRect(arena: ArenaLayout, seat: ArenaSeat): WorldRect;                            // :31, a seat's grid

// apps/web/src/match/model/apply.ts: squad.despawned (:278-280) and a grid card.banished (:282-286)
//   remove the squad and its units (removeSquad, :37-46), or card.banished the permanent, and
//   chaos.despawned removes its units and permanents (:300-303). So the model the scene draws no
//   longer has them, and syncUnits prunes their views before playEffects runs. unit.died only marks
//   the unit dead (:191), and dead units stay in the model. squad.sacrificed keeps its units: it
//   comes after their unit.died (:266-271). squad.revived only logs: its squad.placed and
//   unit.spawned follow (:273-276).

// packages/protocol/src/event.ts
//   spell.resolved { seat, card: CardInstanceId, cardId, spell, target?: Target, copyOf?: CardInstanceId } (:557-566)
//   ability.triggered { source: EntityId, owner, cardId, ability } (:574-583)
//   card.banished { seat, card, cardId, from: 'grid' | 'discardPile' | 'deck' | 'hand', squad?, permanent? } (:776-788)
// packages/protocol/src/target.ts:29-43: seat { seat }, row { seat, row }, area { seat, cell },
//   squad { squad }, squadToCell { squad, cell }, discardPileCard { card, cell, rotated }, spell { action }.

// packages/cards/src/dsl.ts:141: an ability's optional `area`, a `[w, h]` of the caster's own grid.
// packages/core/src/view/cards.ts:109-113, which the battlefield may not import (CLAUDE.md › Import
//   boundaries): spellAbilities(card) is a spell's abilities, a resource's onRest ones, else [].
// packages/core/src/plan/spells.ts:33-43: a copy's spell.resolved names the copier's card and card
//   id, with copyOf the original's instance, and keeps the original's target.
// packages/core/src/combat/attacks.ts:146: unit.attacked comes before the blow, so an on-hit
//   ability.triggered follows it in the step.

// From T-119, through '../../art': hasSprite(key), and SpriteView (constructor(key, box, { anchor }),
//   has, play(animation, startMs) → false when missing or outranked, setSpeed, durationMs(animation),
//   update(now)). A SpriteView whose key has no sprite draws the key's still.
// From T-120: each handler plays the thing's own animation first and shows today's effect when
//   play() returns false; Scene.setSpeed. From T-121: the list of sprite effects in the 'effects'
//   layer, which update() updates and removes when their strip ends.
```

What this task adds: no export and no prop. Only scene.ts and its tests change.

## Deliverables

1. **`fx` sprites.** In each handler below, after the thing's own animation (T-120) and before today's effect:
   - When `hasSprite('fx.<name>')`, a new `SpriteView('fx.<name>', box, { anchor: 'centre' })` gets the scene's speed and plays `play` from `now`. When `play` returns false (its file is still loading), it's destroyed at once and today's effect shows: a `SpriteView` with no strip would draw a still.
   - It goes in T-121's list of sprite effects, which removes it when `play` ends.
   - The box is the thing's rect in view px: a unit's cell, a squad's footprint, a permanent's rect. So a 2 × 2 squad's `fx` draws at ×2.
   - Beside `centers`, the scene keeps each squad's and permanent's rect and each squad's living units as the previous draw left them, and `playEffects` reads them before this draw replaces them. That's how it finds a footprint or a unit the step removed from the model, or the units a sacrifice just killed.

   | Event | `fx` | Else, as today |
   | --- | --- | --- |
   | `unit.died`, when `die` doesn't play | `puff` on the unit | the puff |
   | `permanent.destroyed`, when `die` doesn't play | `puff` on the permanent | nothing, as T-120 has it |
   | `squad.despawned` | `puff` on the squad's kept rect (its units' `unit.died` came first) | the puff |
   | `chaos.despawned` | `puff` on each of its units and permanents | the puffs |
   | `squad.revived` | `respawn` on the squad | the glow |
   | `unit.respawned`, `permanent.respawned`, when `enter` doesn't play | `respawn` on it | the glow |
   | `unit.shielded` | `shield` on the unit | the `ui.shield` fade |
   | `unit.saved` | `save` on the unit; "+LIFE" shows either way | the flash |
   | `squad.sacrificed` | `sacrifice` on each unit the squad had alive at the previous draw, else on the squad | the flash |
   | `card.banished` from the grid | `banish` on each unit the squad had alive at the previous draw, where it was drawn; else on the squad's or the permanent's kept rect | the burst |
   | `emblem.broken` | `emblemBreak` on the Emblem | the two bursts |
   | `trap.fired`, when the trap's `ability` doesn't play | `trap` on the trap | the flash |
   | `ability.triggered`, when the source's `ability` doesn't play | `ability` on the source; for a squad, on each living unit that didn't play it, or on the squad when none is alive | the flash |

   A `card.banished` from a pile, the deck or the hand, and an `ability.triggered` whose source isn't on the battlefield, show nothing, as today.
2. **The same-step rules** (ART.md › Events) follow from T-119's priority order and the order core emits events in, with no special case. Test both:
   - `trap.revealed`, then `trap.fired`: `enter` refuses `ability`, so the trap plays `enter` and `fx.trap` shows.
   - `unit.attacked`, then the attacker's on-hit `ability.triggered`: `attack` refuses `ability`, so `fx.ability` shows.
3. **Casts.** On `spell.resolved` with a target, when `hasSprite(cardId)`, a `SpriteView(cardId, box, { anchor: 'centre' })` gets the scene's speed and plays `cast` from `now`, upright, centred on the target's box. When `play` returns false (no `cast`, or its file still loading), it's destroyed at once. It goes in T-121's list, which removes it when `cast` ends. There's no code fallback: today a spell shows nothing.

   | Target | Box, in view px through `rectPx` |
   | --- | --- |
   | `area` | `footprintRect(seat, cell, size, false)`: `size` is the first `area` among the card's spell abilities (a spell's abilities, a resource's `onRest` ones) |
   | `squad`, `squadToCell` | the squad's rect as the step left it: after a move, or the kept one when the step removed it (a banish) |
   | `row` | one sprite per cell of that row of the seat's grid, cols 0 to `arena.cols − 1`, each in its cell's `footprintRect(seat, { col, row }, [1, 1], false)`, all from `now` |
   | `seat` | `gridRect(arena, seat)` |
   | `discardPileCard`, `spell`, none | no cast |

   - A copy (`copyOf`) plays the copier's `cast`, on the original's target. For `area`, the size is the original's: the scene remembers each `spell.resolved`'s instance and card id, and looks `copyOf` up there. Resonance copying Kindle covers Kindle's 4 × 4.
   - When no size is found, the box is the anchor cell.
   - A Plan ability's `spell.resolved` names a unit's or a permanent's card, which has no `cast`, so it shows nothing.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test battlefield` passes, with tests for:
  - [ ] each row of deliverable 1: with the `fx` sprite, without it, with its file still loading, and, in the rows with a "when", where the thing's own animation plays instead
  - [ ] a banished squad's `fx` on its units where they were drawn, a sacrificed squad's on the units it just lost, and a despawned squad's on its kept rect
  - [ ] the two same-step rules
  - [ ] a cast for each target kind, a turned grid's area and a row's sprites in step included; a resource's Rest cast; a copy's area from its original
  - [ ] no cast without a sprite or without `cast`, and none for a Plan ability, `discardPileCard` or `spell`
- [ ] `grep -c -E "fx\." apps/web/src/match/battlefield/scene.ts` prints at least 1
- [ ] The existing scene tests pass unchanged, and `pnpm test:e2e` passes: with no manifest nothing looks different

## Out of scope

- The art module (T-119), the things' own animations (T-120), wind-ups and projectiles (T-121).
- Casts and `fx` in the DOM pages and PlanGrid: a utility cast on the viewer's own grid stays under T-117's planning layer (ART.md › Spell casts).
- A visual for Plan abilities.

## Notes

- Default: `fx` and casts aren't tinted. The seat's colour stays in the code fallbacks.
- Default: a copy plays the copier's `cast`, not the original's.
- Default: a `squadToCell` cast plays on the footprint after the move.
- Default: the tests reuse T-120's `SpriteView` fake, with `fx.*` and spell keys added.
- A utility spell resolves during Plan, and only its owner's events hold it, so only they see its cast. Defensive and offensive spells resolve on Simulate's first step, so their casts play with the tick-0 effects.
