---
id: T-219
title: Traps out of the cards, core and bots
milestone: M6
depends_on: []
branch: agent/T-219-traps-out-of-the-cards-core-and-bots
model: opus
effort: high
scope:
  - packages/cards/**
  - packages/core/**
  - packages/bots/**
  - packages/db/src/**
  - packages/db/test/**
  - tools/sim-cli/**
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Non-unit permanents and spells
  - docs/RULES.md#Simulation rules
  - packages/cards/README.md#Starter decks
  - packages/core/README.md#Module map
  - tools/sim-cli/README.md#Tests
---

# T-219 — Traps out of the cards, core and bots

## Goal

The game has no traps (D81). After this PR no card is a trap, no card reveals one, core has no trap mechanics, and no bot sets one. The protocol keeps its trap types and events, unused, until T-223.

## Interfaces

What goes, by package (grep `trap` in each; these are the files with the most hits):

- **Cards.** The 24 files in `packages/cards/data/traps/`, and the two spells that only reveal traps: `spell.searchlight` and `spell.undertow`. `trap` leaves the card types (`schema.ts`, `ids.ts`, `colors.ts`, `spells.ts`, `deck/check.ts`). The DSL loses the `reveal` effect, its only target `chosenOpponentTraps`, and the trap triggers. In the README, `## Traps (trap)` and `### Trap triggers` go, and `#### draw, reveal and rest` becomes `draw and rest`. `chaos.raider_pack`'s text drops "and revealed traps" (`version` + 1).
- **Starter decks.** Each of the five loses its 3 or 4 trap entries, 12 to 16 copies. Refill each deck to 100 with cards of its colors, as more copies (up to 4) of cards it already plays or cheap units of its colors, and keep each `description` true (Ember Aggro's ends "…with damage spells and traps").
- **Core.** `combat/traps.ts` and its test; `effects/scripts/mirror_snare.ts`; the trap code in `combat/settle.ts`, `combat/spells.ts` (a trap copying a spell), `combat/simulate.ts` (tick step 1's traps), `combat/state.ts`, `round/cleanup.ts` (fired traps to the discard pile), `plan/permanents.ts` (casting face-down), `arena/placement.ts` (a trap sharing cells), `effects/filters.ts`, `effects/triggers.ts`, `effects/state.ts`, `state/state.ts`, `view/` (hiding face-down traps) and targeting (revealed traps). Core's own types drop `trap`, and core never emits `trap.set`, `trap.revealed` or `trap.fired`.
- **Bots.** `greedy-bot.ts`, `turtle-bot.ts`, `draft.ts` and `grid.ts` stop casting traps; their tests follow.
- **DB.** The seed marks removed cards retired with no code change (D10); fix `seed.test.ts` and any fixture that names a trap.
- **sim-cli.** The golden game's own copies in `tools/sim-cli/test/fixtures/golden/cards/traps/`, the golden script's trap actions, and the trap cards in test fixtures.

## Deliverables

1. Everything in Interfaces removed. Tests that used a trap as a stand-in permanent use an artifact; tests about traps go with their code.
2. New tests: the validator rejects a card of type `trap` (an unknown type), and `checkDeck` reports a deck that names a removed card with the existing unknown-card problem.
3. The golden streams rewritten with `UPDATE_GOLDEN=1 pnpm --filter @chaosgrid/sim-cli test`, with one line in the PR saying why.
4. `grep -rniwE "traps?" packages/cards packages/core packages/bots tools/sim-cli --exclude-dir=node_modules` prints nothing.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check perf` green
- [ ] `crew check soak` green
- [ ] `pnpm cards:validate` green
- [ ] The grep of deliverable 4 prints nothing

## Out of scope

- The protocol, `docs/PROTOCOL.md`, `docs/ART.md` and the web: T-223.
- RULES.md and DECISIONS.md, which already say this (D81).

## Notes

- Copy stays, during Plan only: copying a spell, a Plan ability or a Rest ability earlier in the same Plan works as today. Only a trap's copy during Simulate goes.
- The end conditions' "face-down traps don't count" exception goes with them.
- `packages/cards/stats/cards.json` drops the removed cards' entries; the baseline (T-233) rewrites the rest.
- Lead default: no new cards replace the two reveal spells.
