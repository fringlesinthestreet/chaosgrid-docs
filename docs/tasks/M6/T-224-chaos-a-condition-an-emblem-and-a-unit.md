---
id: T-224
title: "Chaos: a condition, an Emblem and a unit"
milestone: M6
depends_on: [T-219]
branch: agent/T-224-chaos-a-condition-an-emblem-and-a-unit
model: opus
effort: high
scope:
  - packages/core/src/chaos/**
  - packages/core/src/state/config.ts
  - packages/core/src/state/config.test.ts
  - packages/core/src/round/*.test.ts
  - packages/core/src/view/*.test.ts
  - packages/core/src/targeting/*.test.ts
  - packages/core/src/effects/**/*.test.ts
  - packages/core/test/**
  - packages/core/README.md
  - packages/cards/src/schema.ts
  - packages/cards/src/schema.test.ts
  - packages/cards/data/chaos/**
  - packages/cards/test/sets/chaos.test.ts
  - packages/cards/README.md
  - tools/sim-cli/test/**
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Chaos deck and Emblems
  - docs/RULES.md#Sample Chaos deck and Emblems
  - docs/CORE.md#Defaults for open rules questions
  - packages/cards/README.md#Chaos (`chaos`)
  - tools/sim-cli/README.md#Tests
---

# T-224 — Chaos: a condition, an Emblem and a unit

## Goal

Every Reveal draws one condition, one Emblem and one unit card from the round's tier, a unit card spawns its squad once in front of each player it targets, and Extra Chaos is one more unit card against the point leader in tiers 2 and 3 (D80). Today Reveal draws one card, multiplies a unit card's squads by the Chaos factor and caps them at the round number, which made rounds after 5 unbearable.

## Interfaces

On `main` (grep the names, the lines move):

- `chaos/reveal.ts`: `revealChaos(ctx)` draws `NORMAL_DRAWS + state.chaos.extra` cards (`NORMAL_DRAWS = 1`); `revealChaosCard(ctx, card, extra)` branches on `def.kind`; the cap is `Math.min(factor, state.round - squadsInFront(state, seat))`.
- `chaos/deck.ts`: `chaosFactor(config, round)` and `TIER_3_FACTOR = 2`; `buildChaosDeck` stacks tiers 1, 2 and 3, each shuffled; `prepareTier` drops earlier tiers and reshuffles tier 3 every round; `drawChaosCard` reshuffles a tier's own used cards when it runs out; `chaosTier` reads `config.chaosTierStarts`.
- `chaos/cleanup.ts`: `extraChaosDue` gives one card per wiped seat (`wipedSeats`) plus one when `pointLead >= config.extraChaosLead`; `cleanupChaos` adds it to `state.chaos.extra`.
- `chaos/state.ts`: `ChaosState { deck, revealed, discard, extra, emblems }`; `RevealedChaos { card, extra, targets, squads, permanents }`.
- `chaos/targets.ts`: `chaosTargets` for `everyone`, `pointLeader` and `pointLeaderAndRunnerUp`; `CHAOS_SPAWNS` in `packages/cards/src/schema.ts`.
- The protocol doesn't change: `chaos.revealed { card, cardId, kind, extra, targets }` and `ChaosSnapshot { card, cardId, kind, targets, squads }` already carry what's needed, so `PROTOCOL_VERSION` stays.

## Deliverables

1. **Piles.** Each tier has three piles: conditions (kinds `rule` and `nothing`), Emblems and units, each built from its cards' `amount` copies and shuffled on its own. Tier 3's piles reshuffle every round, a pile that runs out reshuffles its own used cards, and an empty pile draws nothing.
2. **Reveal.** In this order: the condition, the Emblem, the unit card, then the extra card if one is due. `chaosFactor`, `TIER_3_FACTOR` and `squadsInFront` go: a unit card spawns one squad in front of each seat its `spawn` targets.
3. **Extra Chaos.** At Cleanup, when the next round is in tier 2 or 3 and the point leader ends `extraChaosLead` (10) or more shown points ahead of the runner-up, the next Reveal adds one more card from that tier's unit pile, sent against the point leader whatever its `spawn` says (each tied leader gets a squad). `state.chaos.extra` is 0 or 1. The wiped-seat trigger goes.
4. **Targets and data.** `pointLeaderAndRunnerUp` leaves `CHAOS_SPAWNS` and `chaosTargets`. As RULES.md › Sample Chaos deck has it: Lost Sentinel's `spawn` becomes `everyone`; Abyss Maw's becomes `pointLeader`; Raider Pack becomes squad 4, size `[4, 1]`, 6 / 2 / 1 / 4 Melee, 2 points. Each changed file's `version` + 1. A schema rule like the tier-1 Flying one: a tier-1 unit card's `spawn` is `everyone`, with an error that cites D80. The Flying error cites D80 too, in place of D65.
5. **A set test**, `packages/cards/test/sets/chaos.test.ts`: every tier has at least one card in each of the three piles.
6. **Tests** in `chaos/*.test.ts`:
   - Round 1 reveals three cards, in pile order.
   - A unit card sent against everyone spawns four squads, one per seat; in round 10 it still spawns one per seat.
   - Tier 2, the leader 10 points ahead: two unit cards, the extra one against the leader only. 9 points ahead: none. Tier 1, 10 ahead: none.
   - An empty Emblem pile draws nothing, and the round goes on.
7. **The golden game.** The golden game's own Chaos copies in `tools/sim-cli/test/fixtures/golden/cards/chaos/` need a card in each tier-1 pile: add copies of real cards there if one is empty. Then rewrite the streams with `UPDATE_GOLDEN=1 pnpm --filter @chaosgrid/sim-cli test`.
8. **Numbers in the PR**, for `pnpm sim --seed 1 --games 20` before and after: the median rounds, the Chaos kill share, and for one game the Chaos squads per seat each round.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check perf` green
- [ ] `crew check soak` green
- [ ] `pnpm cards:validate` green
- [ ] The tests of deliverable 6 pass, and the PR gives the numbers of deliverable 8

## Out of scope

- New Chaos cards and the amounts (T-226), Chaos off (T-229).
- The protocol, the web and the bots: they read the Chaos as `chaos.revealed` and the snapshot list it.
- `round/rebuild.ts`: the preview seats Chaos squads from the snapshot. If a preview needs a change, ask the lead.

## Notes

- Lead default: an extra card that prints `everyone` still spawns only in front of the point leader. That's intended.
- `state.chaos.revealed` keeps the reveal order: condition, Emblem, unit, extra.
