---
id: T-102
title: Cost total and off-color helpers in packages/cards
milestone: M4
depends_on: []
branch: agent/T-102-card-helpers
model: sonnet
effort: low
scope:
  - packages/cards/src/cost.ts
  - packages/cards/src/cost.test.ts
  - packages/cards/src/colors.ts
  - packages/cards/src/colors.test.ts
  - packages/cards/src/deck/check.ts
  - packages/cards/README.md
  - packages/core/src/scoring/points.ts
  - packages/db/src/seed.ts
context:
  - packages/cards/README.md#Cost
  - packages/cards/README.md#Card colors
---

# T-102 — Cost total and off-color helpers in packages/cards

## Goal

The web needs two card rules that only core, db and the deck check know today: what a cost adds up to (the card browser and the deck editor sort by it, T-075 and T-077) and which of a card's colors its Leader doesn't allow (the deck editor marks those cards, T-077). The web may not write rules of its own (D29), and two copies of the cost sum already exist (core's `costValue`, db's `costNumeric`). After this task, `@chaosgrid/cards` exports `costTotal` and `offColors`, the deck check reads `offColors`, and core and db read `costTotal`. Every rule lives once, in `packages/cards`, which the web may import.

## Interfaces

What exists (copied from the code on 2026-10-28):

```ts
// packages/cards/src/cost.ts
export const COLORS = ['R', 'T', 'E', 'D', 'L'] as const;
export type Color = (typeof COLORS)[number];
export function parseCost(cost: string): Cost; // { generic, colors: Record<Color, number> }

// packages/cards/src/colors.ts
export function usageColors(card: Card): Color[]; // set 1, in COLORS order
export function cardColor(card: Card): Color[]; // set 2
export function colorAllowance(leader: Card): Color[]; // set 3: the Leader's usage colors

// packages/cards/src/deck/check.ts:143-155, inside checkDeck
const leaderColors = leader?.type === 'leader' ? colorAllowance(leader) : undefined;
const checkColors = (pile: DeckPile, card: Card) => {
  if (!leaderColors) return;
  const colors = usageColors(card);
  const outside = colors.filter((color) => !leaderColors.includes(color));
  if (outside.length === 0) return;
  add('offColor', pile, [card.id], `${describe(card.id)} is ${colorNames(colors)}: …`);
};

// packages/core/src/scoring/points.ts:44-48
/** What a cost string adds up to: its generic number plus one per colored pip ("2RR" is 4). */
export function costValue(cost: string): number; // generic + every pip, via parseCost
// read by points.ts:83 (unit kill points) and points.test.ts

// packages/db/src/seed.ts:122-130
/** The `cost_numeric` column: the generic number plus every colored pip, from parseCost(). … */
export function costNumeric(cost: string): number; // the same sum
// read by seed.ts:170 and seed.test.ts
```

What this task adds:

```ts
// packages/cards/src/cost.ts (src/index.ts already re-exports the file)
/** What a cost adds up to: its generic number plus one per colored pip. "2RR" is 4, "0" is 0. */
export function costTotal(cost: string): number;

// packages/cards/src/colors.ts
/**
 * The colors of `card` its Leader doesn't allow: its usage colors outside the Leader's color
 * allowance, in COLORS order. Empty when the card fits (RULES.md › Card colors).
 */
export function offColors(card: Card, leader: Card): Color[];
```

## Deliverables

1. **`costTotal`** in `cost.ts`, from `parseCost`.
2. **`offColors`** in `colors.ts`: `usageColors(card)` minus `colorAllowance(leader)`.
3. **The deck check.** `checkColors` in `deck/check.ts` gets the outside colors from `offColors(card, leader)`; its messages and issue order don't change.
4. **Core and db.** `costValue` (core) and `costNumeric` (db) each become one call to `costTotal`, keeping their names and comments, so their callers and tests don't change.
5. **README.**
   - › Cost: one sentence after the table: `costTotal()` is what a cost adds up to ("2RR" is 4); core's kill points, db's `cost_numeric` and the web's cost sort read it.
   - › Card colors: one sentence after the first table: `offColors(card, leader)` is a card's usage colors the Leader doesn't allow, which the deck check and the web's deck editor read.
6. **Tests.**
   - `cost.test.ts`: `costTotal` is 0 for `"0"`, 1 for `"R"`, 3 for `"3"`, 2 for `"1R"`, 4 for `"2RR"` and `"2TR"`, 5 for `"RREDL"`, and 13 for `"12R"`.
   - `colors.test.ts`: against Vask (`3RR`, allows Ember), `offColors` is `['T']` for Barnacle Plate (`2TR`), `[]` for Spike Pit (`1`), Prism and a Chaos card, and `['E']` for a `1R` unit with an ability costing `E`. Against a Leader costing `2` with an ability `RTL` it is `[]` for Barnacle Plate.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm test:soak` passes (`points.ts` is core)
- [ ] `deck/check.test.ts`, core's `points.test.ts` and db's `seed.test.ts` pass unchanged
- [ ] `git diff --stat main -- packages/core packages/db` shows only `points.ts` and `seed.ts`

## Out of scope

- Any rule change: the totals and the off-color results are what the code computes today.
- Renaming or removing `costValue` and `costNumeric`.
- The web's sort and deck editor: T-075 and T-077 call these helpers.

## Notes

- Default: a card with no usage colors fits any Leader, so `offColors` is `[]` for it, the same as the deck check today.
- `offColors` takes any `Card` as `leader`, like `colorAllowance`. The deck check still decides when a deck has a Leader at all (`leader?.type === 'leader'`).
- Runs in wave 1 beside T-069, T-070, T-079 and T-101: no other M4 card owns `packages/cards`, `scoring/points.ts` or `seed.ts`.
