---
id: T-040
title: Spells and the discard pile
milestone: M3
depends_on: [T-039]
branch: agent/T-040-spells-discard-pile
model: sonnet
effort: high
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/cards/**
  - packages/core/src/**
  - packages/core/test/**
  - packages/core/README.md
  - packages/bots/src/**
  - packages/bots/test/**
  - packages/bots/README.md
  - packages/db/src/**
  - packages/db/test/**
  - tools/sim-cli/src/**
  - tools/sim-cli/test/**
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Non-unit permanents and spells
  - docs/RULES.md#Zone mechanics
  - packages/cards/README.md#Sorceries
  - packages/cards/README.md#Spells
  - docs/PROTOCOL.md#Versioning
---

# T-040 — Spells and the discard pile

## Goal

Two renames, everywhere (D24). The `sorcery` card type becomes `spell`, and the graveyard becomes the discard pile. Two cards also get new names, because they share a word with a new rules name: Mirror Ward with the Ward keyword (T-051) and Void Maw with the void zone (T-049). Rules, card data, protocol, code, tests and docs use the new names. The game doesn't change: the same plans and seed give the same game as before, apart from the renamed fields.

## Interfaces

What exists (copied from the code):

```ts
// packages/protocol/src/card.ts:8
export const CardType = z.enum(['unit', 'leader', 'sorcery', 'trap', 'artifact', 'enchantment', 'resource', 'chaos']);
// packages/protocol/src/plan.ts:79
export const CastSorceryAction = z.strictObject({ action: z.literal('castSorcery'), card: CardInstanceId, target: Target.optional() });
// packages/protocol/src/snapshot.ts:75 and :98
graveyardCount: Count,
type: z.literal('sorcery'), // the hand entry of a sorcery
// packages/core/src/state/state.ts:44, a zone name
'graveyard',
// packages/cards/src/ids.ts:20, the data folder per type
sorcery: 'sorceries',
// packages/protocol/src/version.ts:6
export const PROTOCOL_VERSION = 4;
```

What this task changes:

```ts
CardType: 'spell' replaces 'sorcery'          // ids 'spell.<slug>', folder data/spells/
CastSpellAction { action: 'castSpell', ... }  // replaces CastSorceryAction
discardPileCount: Count                       // replaces graveyardCount
'discardPile'                                 // core zone, replaces 'graveyard'
export const PROTOCOL_VERSION = 5;
```

## Deliverables

1. **Spell type.** `CardType` lists `spell` instead of `sorcery`. Card ids become `spell.<slug>` and the folder becomes `packages/cards/data/spells/` (`git mv`, so history follows). The `spell` field that holds a spell's class (`utility`, `defensive`, `offensive`) keeps its name. A card file with `"type": "sorcery"` fails validation with a message that points to `spell`, the way `ritual` does now (`packages/cards/src/schema.ts:284`).
2. **Every reference follows.** Starter decks, deck fixtures, golden cards in `tools/sim-cli/test/fixtures/golden/`, Chaos and trap cards that name a sorcery, bot fixtures, protocol fixtures and the DB test fixtures all use the new ids. `CastSorceryAction` becomes `CastSpellAction` (`castSpell`), and every type, function, variable, test name and comment that says sorcery says spell. Where a comment needs to tell a spell card apart from a spell cast by an ability, say "spell card".
3. **Discard pile.** The core zone `graveyard` becomes `discardPile`, the snapshot's `graveyardCount` becomes `discardPileCount`, and every name, event doc comment and message follows. The `discard` plan action (from the hand) keeps its name.
4. **Card text.** The `text` of every card that says sorcery, sorceries or graveyard uses the new words (Mirror Snare and Fog of War, at least). Five texts also take RULES.md's sample wording: Spike Pit ("An enemy unit steps on the trap (1x1 area): It takes 5 damage"), Flare Mine ("From second 20 of the round, an enemy unit enters the trap area: Deal 2 to every enemy inside the trap area"), Scorch Line ("Deal 4 to everything in one row of one enemy grid"), Fog of War ("No defensive or offensive spells this round, from cards or abilities (utility spells still allowed). Trample splash also hits friendly units and permanents") and Raider Pack ("Goes only for the units of the players it was sent against; once none of them has a unit left, for their artifacts, enchantments and revealed traps"). Bump nothing else in the cards.
5. **Card renames** (RULES.md › Sample cards, › Sample Chaos deck and Emblems).
   - Mirror Ward (`trap.mirror_ward`) becomes Mirror Snare (`trap.mirror_snare`), and Void Maw (`chaos.void_maw`) becomes Abyss Maw (`chaos.abyss_maw`). `git mv` both files, and change their `id` and `name`. Their stats, text and abilities stay the same.
   - The script `mirror_ward` becomes `mirror_snare`: its file in `packages/core/src/effects/scripts/`, its registry key, its tests and the card's `script`.
   - Every deck, fixture, golden card, test, README and docs/PROTOCOL.md line that names either card follows (`grep -rniE 'mirror.?ward|void.?maw'`).
6. **Protocol.** Bump `PROTOCOL_VERSION`. docs/PROTOCOL.md uses the new names, with a line for version 5 in › Versioning.
7. **Docs.** packages/cards/README.md: the "Sorceries" section becomes "## Spells (`spell`)", and the DSL's "### Spells" section (spell classes) becomes "### Spell classes", so later cards can point at it. packages/core/README.md and packages/bots/README.md follow.
8. **DB.** `pnpm db:seed` on an existing DB adds the `spell.*` rows and the two renamed cards, and marks the old `sorcery.*`, `trap.mirror_ward` and `chaos.void_maw` rows retired (D10). That is the expected result: add a test that seeds the old ids, reseeds the new ones, and checks it.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm cards:validate` passes, and a `"type": "sorcery"` fixture fails with the hint
- [ ] `grep -rniE 'sorcer|graveyard' packages tools docs/PROTOCOL.md --include='*.ts' --include='*.json' --include='*.md' | grep -v node_modules` prints only what records the old names: the `sorcery` hint with its fixture and test, the retired-row test, the protocol tests that check the old wire names are rejected (`event.test.ts`), and the history lines in PROTOCOL.md › Versioning. A comment or test name that still says sorcery or graveyard isn't one of them: rename it
- [ ] `grep -rniE 'mirror.?ward|void.?maw' packages tools docs/PROTOCOL.md --include='*.ts' --include='*.json' --include='*.md' | grep -v node_modules` prints only the retired-row test
- [ ] The golden files change only where a name changed (`git diff --stat` on the golden fixtures, explained in the PR)

## Out of scope

- The Ember pip and Earth: T-041
- docs/RULES.md and the other planning docs: already updated

## Notes

- Default: the class field stays `spell` (a `spell` card has a `spell` class). If it reads badly in code, ask `lead` before renaming it to `spellClass`.
- Run the rename in small commits, one package at a time (protocol, cards, core, bots, db, sim-cli), so each step stays green and easy to review.
