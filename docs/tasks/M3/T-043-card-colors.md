---
id: T-043
title: Card colors and color allowance
milestone: M3
depends_on: [T-042]
branch: agent/T-043-card-colors
model: sonnet
effort: high
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/cards/**
  - packages/core/src/**
  - packages/core/test/**
  - packages/bots/src/**
  - packages/bots/test/**
  - packages/db/src/**
  - packages/db/test/**
  - tools/sim-cli/src/**
  - tools/sim-cli/test/**
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Card colors
  - packages/cards/README.md#Deck colors
  - packages/cards/README.md#Scopes and filters
  - docs/PROTOCOL.md#Snapshot
---

# T-043 — Card colors and color allowance

## Goal

A card has three color sets (D23, RULES.md › Card colors).

- **Usage cost:** the pips its casting cost and its Plan abilities (each `onUse` ability's `cost`, T-042) need.
- **Card color:** the colors of its casting cost, unless it says Colorless.
- **Color allowance** (Leaders only): the colors that are allowed into its decks.

Today a single `cardColors` serves as all three. This task splits them, puts the deck check on usage cost against the allowance, and makes effects check card color. It also adds the cost changes RULES describes ("blue spells cost 1 more").

## Interfaces

What exists (copied from the code):

```ts
// packages/cards/src/deck/check.ts:80. The deck check's only color rule.
/** The colors a card needs its Leader to have. A resource's are its `colors`, … Any other card's are the colored pips of its cost … A Leader's own colors are its cost's pips too. */
export function cardColors(card: Card): Color[]
// packages/core/src/effects/sources.ts:317. What a `color` filter reads.
/** A card's colors: the colors of its cost's pips. Chaos cards cost "0", so they have none. */
export function cardColors(card: Card): readonly Color[]
// packages/cards/src/dsl.ts:113
export const FilterSchema = strict({ color: oneOrMore(z.enum(COLORS)).optional(), range: …, hpAtMost: …, excludeSelf: …, survived: … })
// packages/core/src/effects/players.ts:135. The model for a changed cost: generic only, colored pips never change.
export function levelUpCost(state: GameState, squad: Squad): Cost
```

What this task adds:

```ts
// packages/cards (exported, so core, bots and db share one definition)
colorless?: true                                  // card field; not on resources or Chaos
export function usageColors(card: Card): Color[]   // pips of cost ∪ pips of every onUse ability's cost
export function cardColor(card: Card): Color[]     // [] if colorless; resources: their colors; Chaos: []
export function colorAllowance(leader: Card): Color[] // = usageColors(leader)
effect('costChange', { target: PlayerTarget, amount: SignedAmount, cards: { type?, color? }, costs?: ('cast' | 'ability' | 'levelUp')[] })
// costs: which costs it changes; default ['cast']
PLAYER_TARGETS: + 'opponents'

// protocol
HandCard, SquadSnapshot, PermanentSnapshot, LeaderCard: colors: Color[] // card color
HandCard.cost                                              // after cost changes
export const PROTOCOL_VERSION = /* T-042's + 1 */;
```

## Deliverables

1. **The three sets** in packages/cards, each in `COLORS` order, with doc comments that quote RULES.md › Card colors. Both `cardColors` functions go away: the deck check uses `usageColors` and `colorAllowance`, and core's `color` filter uses `cardColor`.
2. **Colorless.** `"colorless": true` is a valid field on units, Leaders, spells, traps, artifacts and enchantments. It isn't valid on resources or Chaos cards, which already have fixed colors. Validation rejects it on a card whose cost has no colored pips, since that card is already colorless.
3. **Deck check.** A main-deck card fits when its `usageColors` are within the Leader's `colorAllowance`. A resource fits when its `colors` are, so Prism and other colorless resources fit any deck. The `offColor` problem names the colors that are missing. A Leader whose cost is `2` and whose ability costs `RTL` allows Ember, Tide and Light: add it as a fixture and test it.
4. **Card color in play.**
   - A permanent's color, and the color of a spell card, is `cardColor`.
   - A spell cast by an ability (a Plan ability, a resource's Rest ability, a trap) has the color of the card the ability is on.
   - `color` filters check card color, so a colorless unit never matches one.
5. **Cost changes.**
   - `costChange` is a `static` effect that changes the generic part of the costs named in `costs` (by default casting costs only) for the cards that match `cards`, for the players in `target` (`owner`, `opponents` or `allPlayers`).
   - It never takes a cost below its colored pips. It counts the permanents on the grid when Plan starts, so something cast during the Plan changes costs from the next round on. It changes Plan ability costs (`ability`) and level-up costs (`levelUp`) only when `costs` names them (RULES.md › Cost changes).
   - Several changes add up. The snapshots show each cost after them (a hand card's cost, and a Plan ability's in `uses`), and paying uses that cost.
6. **Protocol.** Snapshots carry each card's `colors` (card color), so the UI never recomputes them. Bump `PROTOCOL_VERSION`.
7. **Tests:**
   - cards: each set, for a dual card, a Colorless card, a resource, Prism, a Chaos card and a Leader with an ability cost
   - deck: on-color, off-color by ability cost, and Colorless cards
   - core:
     - a red-units filter skips a Colorless unit
     - a Plan ability's spell takes the color of its card
     - a cost change for blue spells: up, down, floored at the colored pips, and summed
     - by default a cost change leaves Plan ability and level-up costs alone; with `costs: ['ability', 'levelUp']` it changes them
     - a cost change cast mid-Plan only counts from the next round
   - bots: the greedy bot reads the changed cost from the snapshot
   - db: a deck stored before this task still loads and checks the same, when no card in it has an ability cost
8. **Docs.** packages/cards/README.md gets:
   - › Deck colors rewritten around the three sets, with the RULES examples
   - a `colorless` row for the card fields
   - `costChange` and `opponents` in the DSL tables
   - a note in › Scopes and filters that `color` is the card color

   docs/PROTOCOL.md: `colors` and the changed `cost` in › Snapshot, and a line in › Versioning.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm cards:validate` and `pnpm cards:validate --decks` (or the CLI's deck flag) pass on every starter deck
- [ ] `grep -rn "cardColors" packages tools --include='*.ts'` prints nothing
- [ ] A golden-style core test: a static "Tide spells cost 1 more" on one player's grid changes only its opponents' Tide spells, from the next round

## Out of scope

- Real Colorless, cost-change and color-matters cards: T-056 and T-060
- Deck-building UI: M4

## Notes

- Default: Chaos cards are colorless and can't be named by `costChange` (they aren't cast).
- A resource's card color is its `colors` field. It equals what it `gives` on every resource but Prism, which gives any color and is colorless (RULES.md › Card colors).
- Default: a dual card matches a `color` filter if any of its colors match, as `oneOrMore` already reads.
- Default: `costChange` has no duration. It holds while its permanent is on the grid, read at the start of Plan. If a card needs "this round only", ask `lead`.
- The DB stores decks, not colors, so the DB change should be no more than the test. If the DB caches colors anywhere, list it in the PR.
