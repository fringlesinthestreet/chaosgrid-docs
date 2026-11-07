---
id: T-214
title: Chaos squad cap and tier-1 Reach
milestone: M5
depends_on: [T-213]
branch: agent/T-214-chaos-squad-cap-and-tier-1-reach
model: sonnet
effort: high
scope:
  - packages/core/src/chaos/**
  - packages/core/src/targeting/*.test.ts
  - packages/core/src/effects/**/*.test.ts
  - packages/core/src/round/cleanup.test.ts
  - packages/cards/data/chaos/lost_sentinel.json
  - packages/cards/data/chaos/scavenger_drone.json
  - tools/sim-cli/test/golden/**
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Chaos deck and Emblems
  - docs/RULES.md#Sample Chaos deck and Emblems
  - docs/CORE.md#Defaults for open rules questions
  - packages/cards/README.md#Keywords
  - tools/sim-cli/README.md#Tests
---

# T-214 — Chaos squad cap and tier-1 Reach

## Goal

The Chaos grows with the rounds without turning the game into PvE: after this PR a player faces at most as many Chaos squads in a round as the round number, Extra Chaos included, and tier 1's Scavenger Drone and Lost Sentinel have Reach, so flyers no longer farm tier 1 (D76). Today every Extra Chaos card spawns its whole Chaos factor again in front of each seat it targets.

## Interfaces

D76, as `docs/DECISIONS.md` has it: the round's unit cards spawn in the order they're revealed, each giving a player it targets its Chaos factor of squads or what that player's cap has left, so a card that finds a player's cap spent spawns nothing in front of them and doesn't list them among its targets. RULES.md › Chaos deck and Emblems › Squad cap and CORE.md › Chaos per round say the same.

What exists on `main` (copied on 2026-11-07; grep the names, the lines move):

```ts
// packages/core/src/chaos/reveal.ts, revealChaosCard: entry.targets is chaosTargets(state, def.spawn),
// and chaos.revealed is emitted with those targets before anything spawns. Then:
if (def.kind === 'units') {
  const factor = chaosFactor(state.config, state.round);
  for (const seat of entry.targets) {
    for (let copy = 0; copy < factor; copy++) {
      entry.squads.push(spawnChaosSquad(ctx, card, seat).id);
    }
  }
}
// revealChaos reveals the round's normal draw first, then the state.chaos.extra extra cards.

// packages/core/src/chaos/state.ts, RevealedChaos
/** The seats its units spawned in front of, in seat order. Empty when it spawns none. */
targets: Seat[];
/** Its squads: one per seat in `targets`, in the same order (CORE.md › Chaos "everyone"). */
squads: SquadId[]; // wrong since D65: a seat gets its Chaos factor of squads

// packages/core/src/chaos/spawn.ts
export function spawnChaosSquad(ctx: EffectsCtx, card: CardInstanceId, seat: Seat): Squad; // spawnedFor: [seat]
```

`chaos.revealed`'s `targets`, as docs/PROTOCOL.md has it: "the seats its units spawn in front of and attack first; empty when it spawns none". The payload doesn't change, so `PROTOCOL_VERSION` stays.

The two cards, as `chaos.ironback_boar` writes its Reach (`"text": "Reach. Trample"`, `"keywords": { "reach": true, "trample": true }`):

| File | Today | After |
| --- | --- | --- |
| `lost_sentinel.json` | `"text": "Blocker (2)"`, `"keywords": { "blocker": 2 }`, `"version": 2` | `"text": "Reach. Blocker (2)"`, `"keywords": { "reach": true, "blocker": 2 }`, `"version": 3` |
| `scavenger_drone.json` | `"text": ""`, no `keywords`, `"version": 4` | `"text": "Reach"`, `"keywords": { "reach": true }`, `"version": 5` |

## Deliverables

1. **The cap.** Each seat gets at most `state.round` Chaos squads a round, counted over every unit card revealed that round, in reveal order. A unit card gives each seat of its `chaosTargets`, in seat order, the smaller of its Chaos factor and what that seat has left. Its `targets`, in `RevealedChaos` and in `chaos.revealed`, list only the seats it spawned a squad for: a card that spawns none is still revealed, with `targets: []`. Work out the counts before emitting `chaos.revealed`. Fix the `RevealedChaos.squads` comment: its squads in spawn order, a seat's together, the seats in `targets` order.
2. **Reach** on the two cards, as in Interfaces.
3. **Tests** in `chaos/reveal.test.ts`, and next to whatever else changes:
   - Round 1: one squad in front of each target.
   - Round 3, a unit card then an extra unit card with the same targets: the extra spawns nothing, and its `targets` and its event's `targets` are empty.
   - Round 3, a rule card then an extra unit card: 3 squads in front of each target.
   - Round 3, Lost Sentinel (the leader) then an extra Rat Swarm (everyone): the leader gets 3 Sentinels and no rats, every other seat 3 rat squads.
   - Round 8 (tier 2, factor 4) with two extra unit cards: 4, 4 and 0 squads in front of the same seat.
   - Round 11 (tier 3, factor 2) with five extra unit cards: 11 squads, the last card giving 1.
   - A property test: for any round from 1 to 20 and any mix of up to five extra cards, no seat gets more than the round number of squads, and each card's `targets` are exactly the seats it spawned squads for.
   - Reach: a Scavenger Drone hits a flying unit, and a Lost Sentinel taunts one.
4. **The golden game.** If sim-cli's golden streams change, rewrite them with `UPDATE_GOLDEN=1 pnpm --filter @chaosgrid/sim-cli test` and say why in one line (tools/sim-cli/README.md › Tests). The golden game's own card copies in `tools/sim-cli/test/fixtures/golden/cards/` stay as they are.
5. **Numbers in the PR**, for `pnpm sim --seed 1 --games 1 --log <file>` before and after: the rounds played, the wall time, and per round the Chaos squads in front of each seat.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check perf` green
- [ ] `crew check soak` green
- [ ] `pnpm cards:validate` green
- [ ] The property test of deliverable 3 passes, and the PR gives the numbers of deliverable 5

## Out of scope

- The preview's Chaos seats (`round/rebuild.ts`): T-215, in this wave.
- The Chaos factor, the tiers, what brings Extra Chaos and every other Chaos card: D76 changes only the cap and these two cards.
- The bots, which read the Chaos from the snapshot, and the web, whose round banner shows `targets` as they come.
- RULES.md, CORE.md and DECISIONS.md: they already say all of this (D76).
- The full soak: the lead runs it on `main` after this wave (D75).

## Notes

- Lead defaults (D76): the cap counts squads, not units, so a Raider Pack squad of 10 is one. A seat with part of its cap left gets that part (round 3 with 2 squads in front of it: the next card gives 1). Within a card the squads keep today's order: seat by seat in seat order, a seat's squads together.
- In tier 1, where the factor is the round number, an extra unit card spawns only in front of the seats the round's own card spawned nothing for. That's intended.
- The planner soak's win bar is in the full tier, which the lead runs after this wave, and it passes on seed 1 with a thin margin (33 > 29, since T-210): the cap may tip it. Don't tune the planner for it here; the lead plans that fix if it comes.
