---
id: T-201
title: Removal, wipes and Dark sacrifice cards
milestone: M5
depends_on: [T-191, T-198, T-200]
branch: agent/T-201-removal-wipes-and-dark-sacrifice-cards
model: opus
effort: high
scope:
  - packages/cards/data/**
  - packages/cards/decks/**
  - packages/cards/test/**
  - packages/cards/src/node/starter.test.ts
  - packages/core/src/effects/**
  - packages/core/test/fixtures/effects/**
  - tools/sim-cli/test/**
  - packages/cards/src/spells.test.ts
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Zone mechanics
  - docs/RULES.md#Card colors
  - docs/RULES.md#Balance knobs and open questions
  - packages/cards/README.md#Effect DSL
  - packages/cards/README.md#Starter decks
---

# T-201 — Removal, wipes and Dark sacrifice cards

## Goal

The human's playtest (2026-11-05) asked for more ways to answer a board, now that nothing wears out (D67): more removal, cheaper destroys and banishes with a drawback, wipes at a medium cost, and cheaper big Dark cards that pay with a sacrifice. After this PR the card pool has them, in the colors where they fit, built only from the DSL that T-191 finished (`destroy`, `enemyPermanents`, `allPermanents`, the `type` filter), and each starter deck plays some of them.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// The effect DSL (packages/cards/README.md › Effects, › Targets, › Scopes and filters; T-191 added destroy and the rest):
// destroy (T-191: units die at once, On death fires; permanents are destroyed; at Cleanup the card goes to the discard
//   pile; scores nothing unless `"scores": true`; a Leader dies instead), banish, sacrifice, kill, damage, discard, dump,
//   draw, revive, spawn. Targets: chosenEnemyUnit, chosenOwnUnit, enemies, ownUnits, allUnits, owner, opponents,
//   ownPermanents, enemyPermanents, allPermanents, chosenOpponentTraps. FilterSchema: color, range, hpAtMost,
//   excludeSelf, survived, type (T-191). A spell has one plan target: a card can choose one thing.
// The removal there is today (cost, text):
//   spell.exile 4L "Banish an enemy unit"; spell.oblivion 6D "Banish an enemy unit";
//   spell.radiant_purge 6L "Banish an enemy unit. Your units get Shield (2) this round";
//   trap.banishing_rune 4L; unit.judgment_angel 6L "… 4L: banish an enemy unit. Rests this unit";
//   spell.soul_drain 3D "Sacrifice one of your units. Deal 6 to all enemy units"
// The sacrifice-first pattern (spell.blood_pact 1D "Sacrifice one of your units. Draw 2 cards"): the first ability
//   sacrifices `chosenOwnUnit`, the next ones act; the choice is the spell's one target.
// Big Dark units today: unit.wight_lord 6D "On enter: dump the top 3 cards of each opponent's deck",
//   unit.soul_reaper 5D "On kill: draw a card", unit.ghoul 4D "On kill: heal this unit 4 HP".
// Fleeting (T-189): the card goes to the discard pile at its first Cleanup: the "sacrifice at the end of the round"
//   the human asked for in place of Durability 0.
// packages/core/src/effects/coverage.test.ts:309 runs every ability of every card in the data through core.
```

A unit takes no target when it's cast (`castUnit` has a cell, no target), so a unit can't ask its owner which unit to sacrifice. The sacrifice cost lives on spells; a big Dark unit pays with its own Fleeting.

## Deliverables

1. **Targeted removal, cheaper, with a drawback.** At least four cards at cost 2 or 3, across at least three colors. The lead's starting list, numbers yours:
   - Dark, "Grave Hex", 2D: destroy an enemy unit; discard a card.
   - Light, "Unmake", 3L: banish an enemy unit; each opponent draws a card.
   - Tide, "Undertow", 2T: destroy an enemy unit with 6 HP or less.
   - Earth, "Bramble Snare", 2E: destroy an enemy Ranged unit.
2. **Medium wipes.** At least three cards at cost 4 or 5, each hitting its caster's side too unless its cost says why not:
   - Light, "Purging Light", 4L: destroy every artifact and enchantment;
   - Ember, "Cinderstorm", 5R: deal 4 to every unit;
   - Dark, "Plague Wind", 4D: each unit with 4 HP or less dies.
3. **Cheaper big Dark cards with a sacrifice.**
   - Two Fleeting Dark units about 3 mana cheaper than the big Dark units they echo: "Bone Colossus" (Wight Lord's body, 3D, Fleeting) and "Gravecall Horror" (Soul Reaper's, 2D, Fleeting).
   - One Dark spell with the sacrifice-first pattern: "Dark Bargain", 2D: sacrifice one of your units; destroy every enemy artifact and enchantment.
4. **Card text** in the style of the existing cards (packages/cards/README.md › Fields every card has), `version` 1, set `base`, ids from the names. Every new card validates and passes the coverage test. If a card needs core to do something it can't, fix it in `effects/` with a test, or drop the card and say why.
5. **Starter decks.** Each starter deck swaps four of its cards for two copies each of two new cards in its colors, a removal and a wipe where its colors have them, still 100 cards and legal. The PR names the cards swapped out and why.
6. **Tests.**
   - A set test in `packages/cards/test/sets/` (like the others there): each new card's ability does what its text says in a small game;
   - the destroys leave the card in the discard pile after Cleanup;
   - a wipe hits its caster's units too;
   - a Fleeting Dark unit leaves at its first Cleanup.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm cards:validate` passes.
- [ ] `pnpm --filter @chaosgrid/cards test` passes.
- [ ] `pnpm --filter @chaosgrid/core test effects` passes.
- [ ] `pnpm test` passes.
- [ ] `pnpm test:soak` passes.
- [ ] On main and on the branch, `pnpm sim --games 20 --seed 1 --bots planner,greedy,turtle,random --decks starter` runs; both reports go in the PR, with the median rounds per game and the squads on the grid at the last round.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- A unit that sacrifices another unit as it's cast: it needs a target on `castUnit`, a protocol change for a later card.
- Tuning the existing removal (Exile, Oblivion): the balance pass.
- RULES.md's sample tables: these cards aren't samples.

## Notes

- Lead default: a wipe hits every side, the caster's included, as RULES.md's "every player's included" means; a card that spares its caster costs more.
- Lead default: no new card scores (`scores` stays off), so removal answers a board without feeding the point race.
- The names are the lead's suggestions: keep them unless one clashes with an existing card.
