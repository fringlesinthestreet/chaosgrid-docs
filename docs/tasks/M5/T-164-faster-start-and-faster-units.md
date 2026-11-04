---
id: T-164
title: Faster start and faster units
milestone: M5
depends_on: [T-157]
branch: agent/T-164-faster-start-and-faster-units
model: sonnet
effort: high
scope:
  - packages/core/src/**
  - packages/core/README.md
  - packages/cards/data/**
  - packages/cards/src/**
  - packages/bots/src/**/*.test.ts
  - tools/sim-cli/test/**
  - docs/RULES.md
  - apps/web/src/host/host.test.ts
context:
  - docs/RULES.md#Components and setup
  - docs/RULES.md#Sample cards
  - packages/cards/README.md#Stats
  - tools/sim-cli/README.md#Usage
  - tools/sim-cli/README.md#JSON report
---

# T-164 — Faster start and faster units

## Goal

Two rules from the human's playtest (2026-11-04), merged as D60 and D61 in the code repo's DECISIONS.md:

- **D60, players start with no resources.** The setup draws 5 cards and no resources, so round 1 has the 2 resources its Plan draws. Today it has 4: 2 from the setup, 2 from the Plan.
- **D61, units move twice as fast.** Every printed Speed doubles, Chaos units' and tokens' included, and so does every Speed number in card text. Projectile speeds stay. The human saw units walk a long time before they fought, so abilities that act "every N seconds" fired many times first.

After this task core plays both rules, the card files and RULES.md's sample tables print the new Speeds, and the PR shows what the balance report says before and after.

## Interfaces

What exists (copied on 2026-11-04):

```ts
// packages/core/src/state/config.ts:33-36: resourcesPerRound: count.default(2), startingResources: count.default(2)
// packages/core/src/zones/setup.ts:81: drawResources(state, seat, state.config.startingResources)
// packages/core/README.md:264, the config table: | `startingCards`, `startingResources` | 5, 2 | the opening draw |

// packages/cards/src/schema.ts:179: a unit's stats.speed is z.number().nonnegative(), with no cap.
// packages/cards/src/schema.ts:152-156: PROJECTILE_SPEED = { min: 5, max: 30 }, "well above the fastest unit (Speed 2)".
// Card files: "stats": { "hp", "attack", "attackSpeed", "speed", "range", ... } in units/, leaders/ and
// chaos/; "projectile": { "kind", "speed" } is a projectile's, which stays. Every card has "version": 1,
// and packages/cards/README.md says to bump it whenever a card changes.
// Today's unit Speeds: 0 (9 cards), 0.5 (6), 1 (91), 1.5 (2), 2 (20). Text that names Speed includes
// "If charged: Your Ember units have 0.5+{level}*0.5 Speed": grep `text` and `abilities` for "Speed"
// and "speed" to find the rest, tokens' stats included.
```

RULES.md already says both rules (setup step 1, the Speed row of the stats table, and the "Starting resources" row in › Balance knobs and open questions). Its sample tables (› Sample cards, › Sample Chaos deck and Emblems) still print the old Speeds in their `Spd` column and text.

## Deliverables

1. **D60:** `startingResources` defaults to 0, and core's README table says 0.
2. **D61 in the cards:** every unit's, Leader's and Chaos unit's `stats.speed` doubles, and so do the Speed numbers in `text` and `abilities`, such as grants, sets and slows, and tokens' stats. `text` and `abilities` stay in step. Every card that changes bumps its `version` to 2. Projectile speeds don't change.
3. **RULES.md's sample tables** print the new Speeds: the `Spd` column and any Speed number in their text, for every card the data changed.
4. **Projectiles still catch their targets:** the schema comment's "Speed 2" becomes 4. Check `PROJECTILE_SPEED.min` against the fastest Speed a unit can reach, granted Speed at level 9 included. If a unit can outrun the slowest projectile, raise that projectile's speed or say in the PR what follows.
5. **Tests:**
   - core: a game's setup leaves every pool empty, and round 1's Plan draws 2 resources. A test that set up resources through the default sets `startingResources` itself, as T-157's "setup's resources are played" test should.
   - cards: no unit, Leader or Chaos unit has a Speed above 4.
   - Fix every test that pinned the old numbers: core's timing tests with real cards, the bots' tests, and sim-cli's tests and goldens. A golden is regenerated, never edited by hand, and the PR says which.
6. **The numbers:** before and after the change, run the same `pnpm sim` tournament on the starter decks (tools/sim-cli/README.md › Usage) with the JSON report. Put a short table in the PR: first contact (median, p10, p90), the median round count, and how rounds end (`timeUp`, `lastStanding`, `chaosWon`).

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm cards:validate` passes.
- [ ] `pnpm test` passes.
- [ ] `pnpm test:soak` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Timers of "every N seconds" abilities: they keep counting from tick 0. If faster units aren't enough, the lead cards a change to when those timers start.
- The battlefield's size and the round timer (RULES.md › Balance knobs and open questions): they stay.
- The web: nothing in `apps/web` should depend on these numbers. If a web test does, ask the lead to widen the scope instead of skipping it.

## Notes

- Defaults: Speed 0 stays 0 (static). A Speed written as a formula doubles each term, so "0.5+{level}*0.5" becomes "1+{level}".
- `startingResources` stays a setting, so a test or a lobby can still start with resources.
- This task changes what every game does, so it runs while no other card touches core, the cards or the sim-cli tests.
