---
id: T-051
title: Shield, Extra life and Ward
milestone: M3
depends_on: [T-050]
branch: agent/T-051-light-keywords
model: sonnet
effort: high
scope:
  - packages/protocol/src/**
  - packages/protocol/test/**
  - docs/PROTOCOL.md
  - packages/cards/src/**
  - packages/cards/test/fixtures/**
  - packages/cards/README.md
  - packages/core/src/**
  - packages/core/test/**
  - packages/core/README.md
  - packages/bots/src/**
  - packages/bots/test/**
context:
  - docs/PLAN.md#M3
  - docs/RULES.md#Units
  - docs/RULES.md#Balance knobs
  - packages/cards/README.md#Keywords
  - docs/PROTOCOL.md#Board
---

# T-051 — Shield, Extra life and Ward

## Goal

Light's three keywords (RULES.md › Units › Keywords): Shield (N) prevents the first N damage each round, Extra life (N) saves a unit from its first N deaths each round, and Ward stops enemy spells and abilities from choosing a unit. Cards can print them and grant them, core applies them, the protocol shows them, and the bots respect Ward.

## Interfaces

What exists (copied from the code):

```ts
// packages/cards/src/values.ts:69-80: KeywordsSchema { blocker, trample (parameters), reach, flying,
// static, ignoresBlockers, seeksEmblems, consumed (flags) }; KEYWORDS is its keys.
// packages/protocol/src/card.ts:57 Keyword = z.enum([... the same eight names]).
// packages/core/src/effects/keywords.ts:18 EffectiveKeywords { blocker: number | null; … }
// packages/core/src/effects/health.ts:73 dealDamage(...), :170 kill(...), :209 resolveDeaths(ctx).
// packages/protocol/src/event.ts:231 UnitDamagedEvent { unit, source, amount, hp }.
// packages/protocol/src/snapshot.ts:156 SquadSnapshot { …, level, durability, … }.
// grantKeyword (dsl.ts:250) can grant any keyword in KEYWORDS.
```

What this task adds:

```ts
// cards: KeywordsSchema gains shield (parameter), extraLife (parameter), ward (flag)
// protocol: Keyword gains 'shield', 'extraLife', 'ward'
UnitShieldedEvent { type: 'unit.shielded'; unit: UnitId; prevented: Hp; shieldLeft: Hp } // before its unit.damaged, if any damage got through
UnitSavedEvent { type: 'unit.saved'; unit: UnitId; livesLeft: Count } // Extra life used: back to full HP, where it stands
// EffectiveKeywords gains shield: number | null, extraLife: number | null, ward: boolean
PROTOCOL_VERSION + 1
```

## Deliverables

1. Cards: the keywords in `KeywordsSchema` (Shield and Extra life take a number or expression, like Blocker), `grantKeyword` takes them, validator tests, and packages/cards/README.md › Keywords.
2. Core:
   - **Shield** is per unit (each unit of a squad has its own) and refills at the start of every round. Damage from any source goes to the Shield first.
   - **Extra life**: when a unit with lives left would die, it stays at full HP instead. That isn't a death: no On death, no kill points, no durability lost, no `unit.died`. The count refills at the start of every round (RULES.md › Balance knobs).
   - **Ward**: an enemy spell or ability can't pick the unit for `chosenEnemyUnit` (a plan that tries is rejected) or `nearestEnemy` (it takes the nearest unit without Ward). Group targets, areas, traps, attacks and triggers aimed at `attackTarget`, `killer` or `triggeringUnit` still reach it. The unit's own side can still choose it.
   - **Banish and sacrifice get past both** (RULES.md › Zone mechanics): a Shield doesn't stop them, and Extra life doesn't save a sacrificed unit. Use the removal cause T-049 left.
   - Granted keywords stack the way Blocker's do today; a test says how.
   - Core tests for each rule in this list, in `shield.test.ts`, `extra-life.test.ts` and `ward.test.ts`, so the acceptance filter finds them.
3. Protocol: the keyword names, the events, the version bump, tests, and docs/PROTOCOL.md › Board and › Versioning.
4. Bots: target picking skips Warded enemy squads, with a test.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/core test -- shield extra-life ward` passes
- [ ] `pnpm cards:validate` passes

## Out of scope

- Light's cards: T-058
- Showing Shield left in the snapshot: events carry it, and the M4 UI can ask for more

## Notes

- Default: a unit that Extra life saves keeps its debuffs and buffs, and its attack timer restarts.
- Default: Kill effects (`kill`) count as a death that Extra life prevents. List it in the PR. Banish and sacrifice are a rule, not a default: nothing prevents them.
- The trap that was Mirror Ward is Mirror Snare since T-040, so "Ward" names only the keyword.
