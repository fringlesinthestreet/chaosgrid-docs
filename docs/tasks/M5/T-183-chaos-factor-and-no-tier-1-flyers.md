---
id: T-183
title: Chaos factor and no tier-1 flyers
milestone: M5
depends_on: []
branch: agent/T-183-chaos-factor-and-no-tier-1-flyers
model: sonnet
effort: high
scope:
  - packages/core/src/chaos/**
  - packages/core/src/round/begin.test.ts
  - packages/core/src/view/snapshot.test.ts
  - packages/core/test/fixtures/chaos/**
  - packages/core/test/fixtures/view/**
  - packages/cards/data/chaos/**
  - packages/cards/src/schema.ts
  - packages/cards/src/schema.test.ts
  - tools/sim-cli/test/**
  - packages/core/src/round/round.test.ts
context:
  - docs/RULES.md#Chaos deck and Emblems
  - docs/DECISIONS.md#Decision log
  - docs/CORE.md#Defaults for open rules questions
  - packages/cards/README.md#Chaos (`chaos`)
---

# T-183 — Chaos factor and no tier-1 flyers

## Goal

D65: Reveal draws one Chaos card a round, plus the Extra Chaos cards, and a Chaos unit card spawns its squad as many times as the Chaos factor (tier 1: the round number; tier 2: the round number − 4; tier 3: 2). The pressure stays what the old draws gave; the variety drops to one card, so Chaos is a factor and the game doesn't turn into PvE (the human's playtest, 2026-11-05). No tier-1 Chaos unit flies.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// packages/core/src/chaos/deck.ts
export const TIER_3_DRAWS = 2;                                        // :16
export function chaosTier(config: GameConfig, round: number): ChaosTier // :19, from config.chaosTierStarts
/** :24-:31: tier 1 the round number; tier 2 the round number − 4, counted from the tier's first round
 *  so a lobby's own tier starts keep the first tier-2 round at 2; tier 3 TIER_3_DRAWS */
export function chaosDrawCount(config: GameConfig, round: number): number { // :32
  if (!Number.isInteger(round) || round < 1) throw new Error(`no round ${round}`);
  switch (chaosTier(config, round)) {
    case 1: return round;
    case 2: return round - config.chaosTierStarts[1] + 2;
    case 3: return TIER_3_DRAWS;
  }
}
export function drawChaosCard(state: GameState, tier: ChaosTier): CardInstanceId | null // :127

// packages/core/src/chaos/reveal.ts
// :14-:21 revealChaosCard's doc: `units`: one squad in front of each seat it targets (`chaosTargets`), in seat order
export function revealChaosCard(ctx: EffectsCtx, card: CardInstanceId, extra = false): RevealedChaos // :22
//   :48 if (def.kind === 'units') { for (const seat of entry.targets) entry.squads.push(spawnChaosSquad(ctx, card, seat).id); }
//   :50 else if (def.kind === 'emblem') entry.permanents.push(placeEmblem(ctx, card).id);
export function revealChaos(ctx: EffectsCtx): RevealedChaos[] {      // :62
  // …
  const normal = chaosDrawCount(state.config, state.round);          // :69
  const total = normal + state.chaos.extra;
  state.chaos.extra = 0;
  for (let i = 0; i < total; i++) {
    const card = drawChaosCard(state, tier);
    if (card === null) break;
    revealed.push(revealChaosCard(ctx, card, i >= normal));
  }
}

// packages/core/src/chaos/spawn.ts:32 — one squad, `spawnedFor: [seat]`, on spawnCells(state, seat, def.squad)
export function spawnChaosSquad(ctx: EffectsCtx, card: CardInstanceId, seat: Seat): Squad
// packages/core/src/arena/spawn.ts:26 spawnCells: "Free means no living unit or Emblem is on it", so a
// second squad spawned on the same edge takes the next free cells by itself.
// packages/core/src/chaos/cleanup.ts:54 extraChaosDue(state): the Extra Chaos queued for the next Reveal
// packages/core/src/state/config.ts:54 chaosTierStarts: [1, 6, 11] by default

// packages/cards/data/chaos/scavenger_drone.json (tier 1, the only tier-1 flyer):
{ "id": "chaos.scavenger_drone", "version": 3, "text": "Flying", "tier": 1, "kind": "units", "amount": 6,
  "spawn": "everyone", "points": 1, "stats": { "hp": 4, "attack": 1, "attackSpeed": 1, "speed": 4, "range": "ranged" },
  "projectile": { "kind": "bolt", "speed": 40 }, "size": [1, 2], "squad": 2, "keywords": { "flying": true } }
// packages/cards/data/chaos/rat_swarm.json has "text": "" and no keywords: the shape of a plain Chaos unit.
```

Outside `chaos/`, `round/begin.test.ts`, `view/snapshot.test.ts` and `test/fixtures/view/games.ts` reveal Chaos and may count on the old draws. The rules text (RULES.md › Chaos deck and Emblems, the sample tier intros and Scavenger Drone's row) and CORE.md's "Chaos per round" default are updated already.

## Deliverables

1. **The Chaos factor.** `chaosDrawCount` becomes `chaosFactor(config, round)`, with the same numbers and the same lobby rule for tier 2, and `TIER_3_DRAWS` becomes `TIER_3_FACTOR`. No new config knob: the factor follows `chaosTierStarts` as the draw count did.
2. **One card a round.** `revealChaos` draws 1 card from the round's tier, then `state.chaos.extra` more (Extra Chaos, unchanged), and reveals each. A tier with no cards left draws fewer, as today.
3. **A unit card spawns its squad factor times.** For each seat it targets, a `units` card spawns `chaosFactor` squads with `spawnChaosSquad`, one after another, so each takes the next free cells of the edge. Each copy is a squad of its own (its own id, `spawnedFor: [seat]`), and `RevealedChaos.squads` lists them all. An extra card spawns with the same factor. Emblem, rule and `nothing` cards act once. `chaos.revealed` stays one event per card: no protocol change.
4. **No tier-1 flyer.** `scavenger_drone.json` loses `keywords.flying`, its text becomes `""` like Rat Swarm's, and its `version` goes to 4. The Chaos card schema refuses a tier-1 `units` card with `keywords.flying`: "a tier-1 Chaos unit can't fly (D65): Flying starts in tier 2", with a test in `schema.test.ts`.
5. **Tests in core:**
   - `chaosFactor` for each tier, and with a lobby's own `chaosTierStarts`;
   - `revealChaos` reveals 1 card, plus one per Extra Chaos;
   - a units card sent against the point leader spawns factor squads in front of that seat, on distinct cells;
   - an "everyone" card spawns factor squads in front of each seat;
   - an extra card spawns factor squads too;
   - an Emblem card places one Emblem, and a rule card turns on once, at any factor.
6. **The golden game.** The Chaos stream of sim-cli's golden game changes: regenerate it the way `tools/sim-cli/test/golden.test.ts` says, and say why in the PR.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/core test chaos begin snapshot` passes.
- [ ] `pnpm cards:validate` passes.
- [ ] `pnpm test` passes.
- [ ] `pnpm test:soak` passes.
- [ ] On main and on the branch, `pnpm sim --games 20 --seed 1 --bots planner,greedy,turtle,random` runs; both reports go in the PR, with the median rounds per game.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Extra Chaos adding to the factor instead of drawing a card: D65's revisit, after the soak.
- Retuning Chaos cards beyond Scavenger Drone.
- The web: the round banner names each revealed card once, and the battlefield draws however many squads spawn.
- RULES.md: the lead updated the rules and Scavenger Drone's row.

## Notes

- Lead default: Scavenger Drone keeps its stats and loses Flying. If the soak shows tier 1 too soft without it, say so in the PR instead of tuning.
- The points don't change: each Chaos squad's units score their printed points, as when several cards spawned.
- `spawnCells` fills an edge from its middle outward and spills to the nearest free cells outside it, so a large factor fits.
- `begin.ts` and `view/board.ts` call or read the reveal; only their tests are in the scope. If one of them needs a code change, stop and say which.
