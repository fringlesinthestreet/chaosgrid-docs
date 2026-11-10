---
id: T-235
title: "Core: resources on the grid and the round's mana"
milestone: M6
depends_on: [T-224, T-234]
branch: agent/T-235-core-resources-on-the-grid-and-the-round
model: opus
effort: high
scope:
  - packages/core/**
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/bots/**
  - packages/cards/src/dsl.ts
  - packages/cards/src/dsl.test.ts
  - packages/cards/src/schema.ts
  - packages/cards/src/schema.test.ts
  - packages/cards/README.md
  - packages/cards/data/chaos/**
  - packages/cards/data/enchantments/**
  - packages/cards/data/leaders/**
  - packages/cards/data/spells/**
  - packages/cards/data/units/**
  - packages/cards/test/**
  - tools/sim-cli/**
  - packages/cards/src/node/load.test.ts
  - packages/cards/src/node/starter.test.ts
  - packages/cards/src/spells.test.ts
context:
  - docs/RULES.md#Resources and mana
  - docs/RULES.md#Round structure
  - docs/DECISIONS.md#Decision log
  - docs/CORE.md#Defaults for open rules questions
  - docs/PROTOCOL.md#Plans
  - docs/PROTOCOL.md#Snapshot
  - packages/core/README.md
  - packages/bots/README.md
---

# T-235 — Core: resources on the grid and the round's mana

## Goal

Core plays resources as cards of one deck (D60): the opening hand is 7, a Plan draws 1, a resource is cast onto the grid like an artifact, any number a round, and every unrested resource floats its mana at the start of Plan (D85, D64). On-enter resource draws search the deck for a basic resource, and every other resource gain is mana (D86). The bots play resources and pay from the round's mana. The protocol adds what this needs and keeps the old pool messages inert, so the web keeps compiling until T-236.

## Interfaces

On `main` (grep the names, the lines move).

- Config (`state/config.ts`): `cardsPerRound` 1, `resourcesPerRound` 2, `startingCards` 5, `startingResources` 0. Setup (`zones/setup.ts`): `SeatSetup { leader, main, resources }`, `createGame` shuffles two decks and `drawRound` (`zones/draw.ts`) draws `planDrawCounts` (`effects/players.ts`: the player stats `resourceDraw`, `cardDraw`, …) of each.
- The pool (`zones/resources.ts`): `ResourceStatus { rested, floating }`, `restForMana`, `floatingResources`, `spendMana`, `loseFloatingMana`, `useResource`, `cleanupResources`, `arrivesRested`; paying (`zones/pay.ts`): `planPayment(payers, cost)`, `pay`, `canPayFromFloating` (the snapshot's `payable`), `canPayByResting` (`usable`). `plan/apply.ts` applies the actions, `round/begin.ts` draws, `round/cleanup.ts` unrests, `round/rebuild.ts` rebuilds a seat from its snapshot for previews.
- Permanents: `Permanent { kind: PermanentKind, mode, alive, rested, faceDown, … }` in `state/state.ts`; `castPermanent` places a free-standing one (`plan/permanents.ts`); `targeting/attackable.ts` makes a free-standing permanent a target; artifacts stand again at Cleanup.
- Effects: `effects/handlers/draw.ts` handles `draw` with `what: "resource"`; `effects/registry.ts` maps every DSL effect to a handler (`coverage.test.ts`). The DSL (`packages/cards/src/dsl.ts`): `PLAYER_STATS` has `resourceDraw`, `cardDraw`, `firstLevelUpCost`, …
- Protocol: `PlanAction` has `restForMana` and `useResource`; the snapshot has `resources: PoolResource[]` per seat (`rested`, `floating`), `usable` on hand cards and abilities, and the events `resource.drawn`, `resource.played`, `resource.rested`. `PermanentKind` lists trap, artifact, enchantment, emblem and prize. `PROTOCOL_VERSION` is 39 after T-223.
- Bots: `pool.ts` (`payment`, `keepRests`) picks the resources to rest for a cost; each bot's draft (`draft.ts`) adds `restForMana` and `useResource` actions. sim-cli's `golden-script.ts` pins `startingResources: 2` and opens every plan with `restForMana` actions.

Cards that draw resources today (`grep -rl '"what": "resource"\|resourceDraw' packages/cards/data`): Wild Grove, Seedling Scout, Dusk Courier, Elder Mycelium, Root Tender, the Leaders Marrow, Brannoch, Jaksho, Thessaly and Grimbark, Sow, Bountiful Growth, Stoke the Embers, Overgrowth, and the Chaos cards Good Harvest, Supply Drop and Drought.

## Deliverables

1. **Config and setup.** `startingCards` 7; `resourcesPerRound` and `startingResources` go, with `resourceDraw`. `SeatSetup` takes `main` with the resources in it and still accepts `resources` (merged into the deck) until T-236 removes it from the host. One shuffle, one draw.
2. **Resources on the grid.** A resource card is cast with `castPermanent` (mode `freeStanding`, 1×1, cost nothing, any number a round) onto an empty cell of its owner's grid, as a `Permanent` of kind `resource`: 1 HP, a target, knocked down for the round and standing again at Cleanup, gone only to destroy, sacrifice or banish. One that `entersRested` is rested until Cleanup. Its Rest ability is a Plan ability (`useAbility`), once a round, which rests it.
3. **The round's mana.** `state.zones.mana[seat]`: the floating mana as units `{ source: CardInstanceId, gives }`. `beginRound` floats one unit per `mana` of every unrested resource on the seat's grid; casting a resource floats its units at once unless it enters rested; `addMana` and `manaPerRound` (below) add units. `planPayment` pays pips from units, `pay` spends them, `loseFloatingMana` clears them when the plans lock. `restForMana`, `useResource`, `canPayByResting` and the pool go: `restForMana` and `useResource` are refused as `notAllowed`.
4. **Searches and mana effects (D86).** The DSL effect `search` (`what: "basicResource"`), only on `onEnter`-style triggers, grants the seat a pending search; the plan action `searchResource { cardId }` takes a basic resource with that id from the deck into the hand during Plan and shuffles the deck, refused (`unavailable`) when none is left or no search is pending; a search not resolved by the lock is lost. The `addMana` effect (`target: "owner"`, `gives`, `amount` default 1) floats units for the round; the player stat `manaPerRound` replaces `resourceDraw`: at the start of Plan the seat floats that many generic units, and a rise during Plan floats the difference at once (CORE.md › Draws during Plan). `draw` with `what: "resource"` goes.
5. **Card data.** Seedling Scout and Dusk Courier: "When played: search for a basic resource" (`onEnter`, `search`). Elder Mycelium and Root Tender: "Rest this unit: +1 mana this round" (`addMana`). The five Leaders' "1: draw a resource" becomes "Rest: +1 mana this round" (`rest: true`, no mana cost, `addMana`). Sow "+2 mana this round", Bountiful Growth and Stoke the Embers "+3 mana this round" (`addMana` with `amount`), Overgrowth "+1 mana next round" (`buff` of `manaPerRound`, `nextRounds: 1`), Wild Grove "Static: +1 mana each round" (`buff` of `manaPerRound`). Chaos: Good Harvest "+1 mana this round for every player", Supply Drop "Buff: +1 mana a round for 2 rounds" (both `buff` of `manaPerRound`), Drought "No resource can be played this round" (a `setRule`, `noResources`, which `castPermanent` of a resource respects). Bump each changed file's `version`; the README documents `search`, `addMana`, `manaPerRound` and `noResources`.
6. **Protocol 40, additive.** `PermanentKind` gains `resource`; `PlanAction` gains `searchResource`; the seat's snapshot gains `mana: { source, gives }[]`, `searches` (pending count) and `deckBasicResources: { cardId, count }[]` (own seat only; `[]` for others), `Rule` gains `noResources`; a `castPermanent` of a resource emits the permanent events as an artifact's. `usable` stays but equals `payable`; `resources` stays and is always `[]`; `resource.drawn`, `resource.played` and `resource.rested` stay in the schema and are never emitted. `docs/PROTOCOL.md` says which messages T-236 removes.
7. **Bots.** Every bot casts every resource in its hand onto its back rows first, counts the round's mana units as its payers (`pool.ts` works on units, not resources), uses Rest abilities and `addMana` abilities when a spend needs the mana, and resolves a pending search with the first basic resource listed. The planner's guesses and previews use the seat's mana as the snapshot shows it (`rebuild.ts` rebuilds `mana`, `searches` and the resource permanents).
8. **sim-cli.** The golden script's decks and plans follow (resources cast in round 1, no `restForMana`), and the streams are rewritten with `UPDATE_GOLDEN=1`. `game.ts`'s unspent-resources stat counts unspent mana units.
9. **Tests:** a seat with two Volcanos and an Ocean on its grid floats R, R, T at the start of Plan and casts a `1R` card; a resource cast during Plan pays in the same plan, and one that enters rested doesn't; a knocked-down resource stands again and floats next round, a destroyed one doesn't; `restForMana` is `notAllowed`; Seedling Scout's search lists the deck's basics and `searchResource` puts the pick in the hand and refuses a second; Stoke the Embers floats three generic units; Wild Grove floats one more each round; Drought refuses a resource cast; `payable` reads the units; a preview keeps the mana; the referee (`packages/bots/test/referee.ts`) checks the new actions; a bot plays its resources and casts something in round 1 of every seeded game.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check perf` green
- [ ] `crew check soak` green
- [ ] `pnpm cards:validate` green
- [ ] `UPDATE_GOLDEN=1 pnpm --filter @chaosgrid/sim-cli test` rewrote the streams, and a second run changes nothing

## Out of scope

- The web (T-236) and the removal of the inert protocol messages (T-236).
- The mana artifacts and the `addMana` validation rule for them (T-228).
- The level-up rule (T-231).

## Notes

- Lead defaults: a resource's mana is generic when `gives` is `[]`, any color for Prism; a Unique ability resource's generic mana floats whether or not the ability is used that round; a bot that can't place a resource (no free back cell) holds it.
- `arrivesRested` became `entersRested` in T-234's schema; delete the text parsing if any is left.
- The one owner of the golden streams in this wave: rewrite them once at the end, and name the seed and round in the PR when a soak bar moves.
