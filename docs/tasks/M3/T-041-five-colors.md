---
id: T-041
title: Five colors
milestone: M3
depends_on: [T-040]
branch: agent/T-041-five-colors
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
  - docs/PLAN.md#M3
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Resources and attaching
  - packages/cards/README.md#Cost
  - packages/cards/README.md#Deck colors
  - docs/PROTOCOL.md#Cards
---

# T-041 — Five colors

## Goal

The game gets D21's five colors: Ember `R`, Tide `T`, Earth `E`, Dark `D` and Light `L`. Ember's pip moves from `E` to `R` in every card, fixture and test, and `E` becomes Earth. Costs, card colors, resource pips, deck colors and the protocol all accept the five letters, and each new color gets a basic resource. Core and the bots treat colors generically, so they get tests and no logic changes.

## Interfaces

What exists (copied from the code):

```ts
// packages/cards/src/cost.ts:7. Cost parsing and color checks derive from it.
export const COLORS = ['E', 'T'] as const;
export type Color = (typeof COLORS)[number];
// packages/cards/src/deck/check.ts:72
const COLOR_NAMES: Record<Color, string> = { E: 'Ember', T: 'Tide' };
// packages/protocol/src/card.ts:30. Separate from cards' COLORS: protocol imports nothing.
export const Color = z.enum(['E', 'T']);
// packages/protocol/src/card.ts:37, the pips of a cost in snapshots
export const Cost = z.strictObject({ generic: z.int().min(0), colors: z.strictObject({ E: z.int().min(0), T: z.int().min(0) }) });
// packages/core/src/view/cards.ts:27-30, costOf: the snapshot's cost
return { generic, colors: { E: colors.E, T: colors.T } };
// packages/core/src/state/testing.ts:38 and :136, test helpers with Ember pips
cost: 'E', colors: ['E'], gives: ['E'],
// packages/core/src/zones/pay.ts reads COLORS, packages/bots/src/pool.ts reads Color.options.
```

What this task adds:

```ts
export const COLORS = ['R', 'T', 'E', 'D', 'L'] as const; // cards
export const Color = z.enum(['R', 'T', 'E', 'D', 'L']); // protocol
Cost.colors: { R, T, E, D, L }                          // one count per color
const COLOR_NAMES = { R: 'Ember', T: 'Tide', E: 'Earth', D: 'Dark', L: 'Light' };
export const PROTOCOL_VERSION = /* T-040's + 1 */;
```

## Deliverables

1. **Ember becomes `R`.** Do this first, as its own commit, before `E` means anything else. Every Ember pip becomes `R`: costs, resource `colors` and `gives`, filters (`"color": "E"`, Vask's included), starter decks, golden cards, fixtures, test helpers and test expectations. To find them, `grep -rlE '"[0-9X]*[ET]*E[ET]*"' packages/cards` for the card files, and `grep -rlE "['\"][0-9X]*[ET]*E[ET]*['\"]" packages tools --include='*.ts'` for the code. Both also hit strings that aren't pips, so check each hit. Cards keep their `set` and `version`; version bumps start in M5.
2. **Five colors.** `COLORS`, `COLOR_NAMES` and the protocol's `Color` list the five colors in D21's order, and the protocol's `Cost.colors` has a count for each. Bump `PROTOCOL_VERSION`, since `Color` is in card payloads.
3. **Three basic resources,** shaped like `resource.volcano`: `resource.grove` (Grove, gives `E`), `resource.crypt` (Crypt, gives `D`) and `resource.sanctum` (Sanctum, gives `L`), each `set: "base"`, `cost: "0"`, `text: ""`.
4. **Tests:**
   - cards: costs with each pip (`2R`, `2E`, `1DL`, `RREDL`), an unknown letter (`G`) rejected, `cardColors` and the `offColor` deck problem with the new colors, and the color names in its message
   - core `pay.test.ts`: paying `E`, `D` and `L` pips, a dual pool card paying either pip, and `any`
   - bots `pool.test.ts`: the same, through `payment`
   - protocol: `Color` accepts the five letters and rejects others
   - db: if a deck or cards test lists colors, extend it
5. **Docs:** packages/cards/README.md › Cost, › Deck colors and the `colors` row in › Resources list the five colors and their basic resources, with Ember as `R`. docs/PROTOCOL.md › Cards shows the new `Color`, and › Versioning gets a line for this version.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm cards:validate` passes with the three new resources
- [ ] The only card file with an `E` pip is `resource.grove`: no Ember card was missed
- [ ] The golden files change only by the pip letter (`git diff --word-diff` on them, summed up in the PR)
- [ ] `grep -rn "'R', 'T'\]" packages/*/src --include='*.ts' | grep -v test` prints nothing that lists the colors by hand outside `COLORS` and `Color`

## Out of scope

- Card colors, Colorless and the Leader's allowance: T-043
- Cards of the new colors: T-054, T-057, T-058 and T-059
- Starter decks for the new colors: T-061

## Notes

- Names, from D21 and PLAN.md: Ember, Tide, Earth, Dark, Light; the basic resources Grove, Crypt and Sanctum. If the README or a test needs a name not given here, pick one and list it in the PR.
- `E` was Ember until this task. Do the `E` → `R` pass with a script you can rerun (a `sed` over the listed files is fine) and check the result with the tests before adding Earth, so no Ember pip is left behind as an Earth one.
