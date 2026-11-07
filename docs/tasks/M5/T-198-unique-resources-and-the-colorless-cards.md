---
id: T-198
title: Unique resources and the colorless cards
milestone: M5
depends_on: [T-189, T-193]
branch: agent/T-198-unique-resources-and-the-colorless-cards
model: sonnet
effort: high
scope:
  - packages/cards/src/**
  - packages/cards/data/**
  - packages/cards/decks/**
  - packages/cards/test/**
  - packages/cards/README.md
  - tools/sim-cli/src/decks.ts
  - tools/sim-cli/src/decks.test.ts
  - apps/web/src/decks/editor/deck.ts
  - apps/web/src/decks/editor/problems.ts
  - apps/web/src/decks/editor/DeckPanel.tsx
  - apps/web/src/decks/editor/*.test.ts
  - apps/web/src/decks/editor/*.test.tsx
  - apps/web/src/i18n/en/deckEditor.json
  - packages/core/src/zones/resources.test.ts
  - packages/core/src/view/hidden.test.ts
  - apps/web/src/host/host.test.ts
  - apps/web/src/match/session.test.ts
  - tools/sim-cli/src/game.test.ts
  - tools/sim-cli/src/command.test.ts
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Components and setup
  - docs/RULES.md#Card colors
  - docs/RULES.md#Sample cards
  - packages/cards/README.md#Resources (`resource`)
---

# T-198 — Unique resources and the colorless cards

## Goal

Two decisions from the human's playtest (2026-11-05). D69: a resource card can be Unique, so a resource deck holds one copy of it; Prism, Harvest Cycle and Old Library become Unique, and each color gets its own Unique Harvest Cycle. D70: a Leader with no colored pip allows only colorless cards, and a plain colorless resource gives one generic mana. After this PR the first colorless Leader and Waystone exist, a colorless deck can be built, and the starter decks, the sim's deck generator and the deck editor follow the new limits.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// packages/cards/src/schema.ts
const uniqueField = { unique: z.literal(true, { error: 'unique is true: leave the field out on a card that is not Unique' }).optional() } // :102
export const ResourceCardSchema = strict({ ...common('resource'),
  /** Color identity, the RULES.md "Type" column ([] = colorless): the card's color and its deck colors. */
  colors: colorList,
  /** What it pays: one pip of one of these colors, of "any" color, or [] = one generic pip. */
  gives: z.union([z.literal('any'), colorList], …) });                 // :359: no `unique` yet
// packages/cards/src/deck/check.ts
export const MAX_COPIES = 4; // :30 "Copies of one card a main deck may hold, a Unique card aside. Resource decks have no limit."
export function isUnique(card: Card): boolean   // :33: `unique: true`, or a Leader
export function maxCopies(card: Card): number   // :38: 1 for a Unique card, MAX_COPIES otherwise
// :167-:195 the main deck's 'tooManyCopies'; :197-:216 the resource deck: its size, resources only, colors; no copy limit
// packages/cards/src/colors.ts:20 usageColors (a resource: its `colors`), :43 colorAllowance(leader) = its usage colors
//   (a Leader without colored pips allows nothing colored: only cards with no usage colors fit, D70)
// packages/cards/data/resources/: prism.json (colors [], gives "any", text ""), harvest_cycle.json (gives [],
//   "Rest: draw a card"), old_library.json (gives [], "No hand size limit"); volcano.json is a basic (one color, no ability)
// The 22 colorless main-deck cards today (no colored pip in any cost, none Unique): hired_spear, iron_sentry, scout_hound,
//   road_archer, relic_hunter, sellsword, shield_bearer, siege_ballista, cold_snap, scavenge, brace, searchlight, whetstone,
//   iron_plating, wanderers_compass, siege_beacon, sharpened_edge, watch_post, pitfall, caltrops, spike_pit, tripwire:
//   88 copies, short of the 100 a main deck needs.
// packages/cards/decks/*.json: "resources": { "resource.volcano": 21, "resource.prism": 4, … }; each starter deck holds
//   2 to 4 Prisms, 2 or 3 Harvest Cycles and (but ember_aggro) 2 Old Libraries
// tools/sim-cli/src/decks.ts:51 generateDeck: main from maxCopies; resources: 20 basics (:31 isBasic: one color, no ability)
//   and 10 `pick(rng, others)`, with repeats; a Leader whose main cards make fewer than 100 copies throws (:63)
// apps/web/src/decks/editor/deck.ts:42 `const room = pile === 'main' ? Math.max(0, maxCopies(card) - held) : count;`
//   problems.ts:33 and DeckPanel.tsx:185 read maxCopies for the main deck only
```

RULES.md is updated already: Components and setup (the resource deck row), Card colors (D70) and the sample resource table (Prism, Harvest Cycle and Old Library Unique; the colored Harvest Cycles and Waystone named).

## Deliverables

1. **Unique resources (D69).** `ResourceCardSchema` takes `uniqueField`. The deck check refuses a second copy of a Unique resource (`tooManyCopies` in the resource pile, "2 copies of Prism: the resource deck takes at most 1 of a Unique card"); `MAX_COPIES`' comment says so. Prism, Harvest Cycle and Old Library get `"unique": true`, their text starts with "Unique" ("Unique", "Unique. Rest: draw a card", "Unique. No hand size limit"), version + 1.
2. **Five colored Harvest Cycles**, one per color: `resource.ember_harvest_cycle`, `tide_`, `earth_`, `dark_` and `light_harvest_cycle` ("Ember Harvest Cycle" …), each Unique, `colors` and `gives` its one color, text "Unique. Rest: draw a card", the same ability as Harvest Cycle.
3. **Waystone (D70):** `resource.waystone`, colors `[]`, gives `[]` (one generic pip), text "", not Unique.
4. **A colorless Leader:** `leader.brass_arbiter`, "Brass Arbiter", cost `3`, a 2x2 squad of 1, stats in line with the 3-cost Leaders, Charge 0 (T-212 removes the stat), one Plan ability with a generic cost: "2: your units get +1 Attack this round". If the DSL can't say it as written, pick the nearest it can and say so in the PR. No colored pip anywhere.
5. **Colorless main-deck cards.** At least four new ones, not Unique, with generic costs only: two units, a spell and an artifact or a trap, each modelled on a colorless card of the same cost (copy its stat line, change one thing). With them the colorless cards make at least 104 copies, so a colorless deck is legal.
6. **Starter decks.** Each keeps one Prism, one Harvest Cycle and one Old Library where it had them, adds its color's Harvest Cycle (one), and fills the rest with its basic resources: still 30, still legal (`starter.test.ts`).
7. **The sim's generator.** Picks each Unique resource at most once; counts Waystone as the basic resource of a Leader with an empty allowance; and builds a legal deck for Brass Arbiter. Tests in `decks.test.ts`.
8. **The deck editor.** Adding a Unique resource stops at one copy (`deck.ts`), and the problems list and the pile's limit show it like a main-deck Unique card. If a copy limit per pile belongs in `@chaosgrid/cards` (one function the check and the editor share), add it there.
9. **Tests.**
   - schema: `unique` on a resource;
   - check: a second Prism is refused, a second Volcano isn't; a colorless Leader takes a colorless card and refuses a red one, takes Waystone and Prism and refuses Volcano;
   - the new cards validate;
   - the editor's limit.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/cards test` passes.
- [ ] `pnpm cards:validate` passes.
- [ ] `pnpm --filter @chaosgrid/sim-cli test decks` passes.
- [ ] `pnpm --filter @chaosgrid/web test editor deck problems` passes.
- [ ] `pnpm test` passes.
- [ ] `pnpm test:soak` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Core: a colorless resource already pays a generic pip (`gives: []`), and T-195 edits core beside you. If paying needs a change, stop and say what.
- A colorless starter deck, and tuning the new cards: the balance pass.
- Art: the art pack gives every card in `packages/cards/data` a kind by itself; new cards draw placeholders.
- RULES.md: the lead's.

## Notes

- Lead default: the colored Harvest Cycles give their color, so they rest either for mana or to draw; the colorless one gives a generic pip, as it does today.
- Lead default: Brass Arbiter's name, cost and ability are a starting point; the numbers are yours, against the 3-cost Leaders, and the PR says which Leader you compared with.
- `pnpm db:seed` picks up the new cards; nothing in `packages/db` changes.
