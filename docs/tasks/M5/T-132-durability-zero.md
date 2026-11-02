---
id: T-132
title: Durability 0 and discard-pile cards
milestone: M5
depends_on: [T-112, T-131]
branch: agent/T-132-durability-zero
model: sonnet
effort: high
scope:
  - packages/core/src/round/cleanup.ts
  - packages/core/src/round/cleanup.test.ts
  - packages/cards/data/**
  - packages/cards/test/sets/discard-pile.test.ts
context:
  - docs/RULES.md#Round structure
  - docs/RULES.md#Units
  - packages/cards/README.md#Units
  - packages/cards/README.md#Triggers
  - packages/cards/README.md#`dump`
---

# T-132 — Durability 0 and discard-pile cards

## Goal

D48: "A unit card whose Durability is 0 at Cleanup goes to the discard pile, even if its squad survived." Today a card at 0 stays until its whole squad dies, so Durability 0 works like 1. After this PR, Cleanup's wear step retires every squad at 0, and a new set, `discard_pile`, adds the first cards printed with Durability 0: five cheap units that fill the discard pile every round, and two payoffs that revive them during the fight. The existing revive cards (Gravedigger, Restless Dead, Bone Ferryman, Restless Grave, the Dark Leaders) work with them unchanged. The balance baseline (T-139) reports how they do.

## Interfaces

What exists (copied from the code on 2026-10-29). T-112 rewrites Cleanup's hand-limit step into the Discard step: re-read `cleanup.ts` when you start.

```ts
// packages/core/src/round/cleanup.ts
// :24-44 the header lists the steps; step 4: "squads wiped out lose 1 Durability, and go to the
//   discard pile at 0 (or at once when Consumed)".
function retire(ctx: Ctx, squad: Squad): void;  // :99-108: the card to the discard pile, squad.retired,
//   its units deleted, resetMovement. Attached cards follow in restorePermanents (:155-188):
//   permanent.destroyed if still standing, then permanent.retired. Attached resources return later.
function wearWipedSquads(ctx: Ctx): void {      // :133-146
  const { state } = ctx;
  for (const squad of gridSquads(state)) {
    if (unitsOf(state, squad).some((unit) => unit.alive)) continue;
    if (squadCard(state, squad).keywords.consumed === true) {
      retire(ctx, squad);
      continue;
    }
    if (squad.durability === null) continue;
    squad.durability = Math.max(0, squad.durability - 1);
    ctx.emit({ type: 'squad.durabilityChanged', squad: squad.id, durability: squad.durability });
    if (squad.durability === 0) retire(ctx, squad);
  }
}
// cleanup() (:304-333) runs, in order: the scoring (survival first), onRoundEnd abilities ("If
//   survives round", Kettle's Durability heal), …, cleanupChaos, …, retireSacrificed, restorePrizes,
//   wearWipedSquads, restorePermanents, respawnUnits, returnResources, the Discard step (T-112),
//   countRoundsOnGrid, checkWinners.

// Durability elsewhere in core (unchanged here):
// round/context.ts:37 gridSquads(state): the grid's squads (no Chaos, no tokens), by id.
// plan/squads.ts:21 printedDurability(card): null for Chaos, else card.durability ?? null. No
//   Leader prints one; tokens (effects/tokens.ts:61) and Chaos get null too.
// plan/level.ts:58 a level-up sets durability back to printedDurability(card).
// effects/handlers/revive.ts: a revived card is a fresh squad, level 1, printed Durability.
// effects/health.ts:188-190 a Durability heal never goes above the printed value.
// core README › The state › Shared entities, the "Permanent and token events" bullet: "every Durability change one event".

// packages/core/test/fixtures/round/board.ts
export function boardState(options?: MakeStateOptions): GameState; // :35: the real cards, the round
//   test cards and options.cards; the phase is cleanup
export function place(state, card, seat, cell, options?: { rotated?; level?; durability?: number | null }); // :54
export function kill(unit: Unit): void;                             // :78
export function runCleanup(state): { events: readonly GameEvent[]; winners: Seat[] }; // :84
// cleanup.test.ts › "Cleanup: respawn and Durability" (:104-252) is the model: :127 retires a squad at
//   0 with an attached card and a resource, :238 Kettle.

// packages/cards: a unit's `durability` is a nonNegativeInt (schema.ts:250), so 0 validates today.
//   packages/cards/test/sets/dark.test.ts pins set `dark` at exactly 30 main-deck cards and 1 Leader:
//   new cards go in a new set. Set tests read loadCards() from '../../src/node/index'.
// Patterns to copy: units/gravedigger.json (an onDeath revive), units/bone_archer.json (Ranged, a
//   projectile), units/shade_stalker.json (Flying), units/blaze_runner.json (Ignores Blockers),
//   enchantments/charnel_engine.json (a free-standing Dark enchantment), artifacts/tide_clock.json
//   (an `every` ability, "(rests after use)"), chaos/the_culling.json (an `at` ability).
```

What this task adds:

```ts
// cleanup.ts: wearWipedSquads becomes
/** Wears out the grid's squads: a wiped one loses 1 Durability (a Consumed one retires at once), and
 *  any squad at 0 retires, whether its units survived or not (D48). */
function wearSquads(ctx: Ctx): void;
```

And seven card files (below), with a set test.

## Deliverables

1. **D48 in the wear step.** A squad whose Durability is 0 after the wear retires, whether its units survived or not.
   - A wiped squad above 0 loses 1 and reports `squad.durabilityChanged`, as today.
   - A wiped squad already at 0 doesn't report a change, since nothing changed. It just retires.
   - Rename the function to `wearSquads`, and update its doc comment and step 4 of the header.
   - The order of Cleanup's steps doesn't change.
2. **Core tests** in `cleanup.test.ts`, in the "respawn and Durability" block. Use a unit card printed with Durability 0, defined in the test with `CardSchema.parse` and passed to `boardState({ cards })`, so the tests don't depend on the card files:
   - a surviving squad at 0 retires: `squad.retired` and no `squad.durabilityChanged`. Its card is in the discard pile, its units are gone, and none of them is healed or respawned;
   - a wiped squad at 0 retires the same way;
   - a retiring survivor's attached card follows it (`permanent.destroyed`, then `permanent.retired`), and its attached resource is back in the pool;
   - the survivor's seat still scores the survival point, and its "If survives round" ability fires, before it retires;
   - a surviving squad at Durability 1 keeps its 1 and stays, and a Leader stays;
   - a surviving Kettle's Durability heal leaves a card printed with 0 at 0, so it still retires.

   Every existing test keeps passing unchanged.
3. **The cards**, each in its own new file, set `discard_pile`, version 1. The units have `"levelUnlock": { "roundsOnGrid": 2 }`, as Gravedigger does: a card that retires at every Cleanup never meets it.

   | Card (file) | Cost | Body | Durability | Text, and the ability |
   | --- | --- | --- | --- | --- |
   | Bone Thrall (`units/bone_thrall.json`) | D | 2 × 4 HP, 2 attack, attack speed 1, speed 1, Melee, size [2, 2] | 0 | "" |
   | Carrion Moth (`units/carrion_moth.json`) | 1D | 2 × 3 HP, 2 attack, 1, speed 2, Melee, [2, 2], Flying | 0 | "Flying" |
   | Pallid Archer (`units/pallid_archer.json`) | 1D | 3 × 3 HP, 3 attack, 0.5, speed 1, Ranged, arrow speed 14, [2, 2] | 0 | "Ranged" |
   | Dread Conscript (`units/dread_conscript.json`) | 1D | 1 × 8 HP, 2 attack, 1, speed 1, Melee, [2, 2] | 0 | "If survives round: draw a card": `condition` `survived`, `onRoundEnd`, `draw`, `owner`, 1 |
   | Cinder Wisp (`units/cinder_wisp.json`) | R | 4 × 2 HP, 2 attack, 1, speed 2, Melee, [2, 2], Ignores Blockers | 0 | "Ignores Blockers" |
   | Gravewheel (`enchantments/gravewheel.json`) | 3D | free-standing, area [2, 2] | 3 | "Every 10 seconds: revive the unit card that entered your discard pile last (rests after use)": `every` 10, `revive`, `lastDiscardPileUnit` |
   | Pale Summoner (`units/pale_summoner.json`) | 3D | 1 × 8 HP, 3 attack, 1, speed 1, Melee, [2, 2] | 3 | "At second 5: revive the unit card with 4 HP or less that entered your discard pile last": `at` 5, `revive`, `lastDiscardPileUnit`, filter `hpAtMost` 4 |

   The ids are `unit.<file name>` and `enchantment.gravewheel`. Each unit keeps `charge: 0`.
4. **The set test**, `packages/cards/test/sets/discard-pile.test.ts`, in `dark.test.ts`'s style:
   - the set has 5 units at Durability 0 and 2 payoffs;
   - each unit at 0 costs 2 or less (`costTotal`);
   - the units stay in the pool's range: total HP (HP × squad) and damage per second (attack × attack speed × squad) at most 8 for a cost of 1, and at most 12 for a cost of 2;
   - colors: every card is Dark (`usageColors`) except Cinder Wisp, which is Ember;
   - both payoffs revive;
   - no card uses a script.
5. **A quick look for the handoff.** Run `pnpm sim --games 20 --seed 1 --target 30 --decks generated --json .data/t132.json`. Put the new cards' per-card counts and the run's `errors:` line in your PR body. Tune nothing from it.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm test:soak` passes
- [ ] `pnpm cards:validate` passes
- [ ] `pnpm --filter @chaosgrid/core test cleanup` and `pnpm --filter @chaosgrid/cards test discard-pile` pass
- [ ] `git diff --name-only --diff-filter=MDR main...HEAD -- packages/cards/data` prints nothing: cards are only added
- [ ] `pnpm sim --games 20 --seed 1 --target 30 --decks generated --check` exits 0

## Out of scope

- Starter decks (`packages/cards/decks/`) and every existing card.
- New DSL terms. A payoff that counts the discard pile needs one: send lead a `request` instead.
- How bots value Durability (T-133, T-135), and any tuning (from T-139's findings).
- RULES.md, DECISIONS.md, the protocol and the cards README. D48 is already in RULES.md, and the README's `durability` row needs no change.

## Notes

- **Who has no Durability.** Leaders, tokens and Chaos have `null`, so the wear step skips them, as today.
- **Leveling and Extra life.**
  - A level-up resets Durability to the printed value, which is 0 for these cards. They can't level anyway: they retire at their first Cleanup.
  - Extra life saves a unit, not a card at 0: a squad that survives on Extra life still retires. The survivor test covers it.
- **Default: the rule covers what the wear step walks**, the grid's unit squads. Free-standing permanents keep their own path (`restorePermanents`), and none prints 0.
- **What's wiped.** A grid emptied only by retirements isn't wiped. `cleanupChaos` runs before the wear step and looks at the fight, so no extra Chaos is queued.
- **No protocol change.** `squad.retired` already means the card went to the discard pile at Durability 0. The web's model removes a retired squad's units (apps/web/src/match/model/apply.ts:258-263), living or not.
- **The payoffs fire during Simulate, on purpose.**
  - Don't use `onEnter` or `onPlay` for a `lastDiscardPileUnit` revive. A cast fires them during Plan (plan/squads.ts:103), and the revived card takes the free cells nearest the front middle. A later cast of the same plan that aimed there would be rejected, and the soaks allow no rejected action.
  - Don't write an `onRoundEnd` revive either. Cleanup's first step fires it, before the wear step, so it can't see this round's retirements.
  - An `every` ability on a free-standing permanent fires once a round (RULES.md › Non-unit permanents). An `at` ability on a unit fires once a round for each living unit of its squad (core effects/triggers.ts › fireTimed), so Pale Summoner prints a squad of 1.
  - Only The Culling uses `at` today. If the schema or core refuses it on a unit, make Pale Summoner's ability `onDeath` ("On death: revive …", as Gravedigger's), and say so in your PR body. Never `every` on a unit: that fires every 10 seconds, not once a round.
- **Names.** No new name may contain another card's name, or be contained in one. The web tests click a button by `new RegExp(card.name)` and expect exactly one. The e2e searches "Vask", "Hired Spear" and "Kindle". Check with `grep -rh '"name"' packages/cards/data`.
- **What changes.**
  - The goldens play frozen cards (`tools/sim-cli/test/fixtures/golden/cards`), and no squad in them can be at 0 and alive at Cleanup. They must not change. If one fails, the core change is wrong; never regenerate it.
  - Generated decks draw from the whole pool, so every generated-deck game (the soaks, `game.test.ts`, `snapshot-positions.test.ts`) plays differently. They assert invariants: if one fails, report the numbers to lead; don't loosen it.
  - The starter decks, the starter fixtures and the web's recorded logs play no Durability 0 card, so they don't change.
  - Tests that count the pool (`cards.test.tsx`'s "N of M") count at run time.
- Only new files in `packages/cards/data/`: the acceptance check refuses a changed or deleted one.
