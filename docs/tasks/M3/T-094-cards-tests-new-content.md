---
id: T-094
title: Cards tests accept new content
milestone: M3
depends_on: [T-053]
branch: agent/T-094-cards-tests-new-content
model: sonnet
effort: low
scope:
  - packages/cards/src/dsl.test.ts
context:
  - packages/cards/README.md#Caster choices
  - docs/tasks/README.md#M3
---

# T-094 — Cards tests accept new content

## Goal

Two checks in `packages/cards/src/dsl.test.ts` compare the card data with an exact list. A content task that adds a card with a new caster choice, or the first card that uses `costChange`, `discard` or `fear`, fails them, but its scope holds only `packages/cards/data/**` and its own set test. T-057 needed this file added to its scope, and T-060 would too. Make both checks one-way, the way the triggers and targets checks already are, so new content passes and a card that breaks a rule still fails.

## Interfaces

What exists (copied from the code on 2026-10-26):

```ts
// packages/cards/src/dsl.test.ts:713, 'use every effect, target and trigger'
const noCard: readonly string[] = ['costChange', 'discard', 'fear'];
expect(new Set(abilities.map((ability) => ability.effect))).toEqual(
  new Set(EFFECTS.filter((effect) => !noCard.includes(effect))),
);
// the triggers and targets checks are one-way already:
expect(TRIGGERS.filter((trigger) => !triggers.has(trigger) && !notYet.includes(trigger))).toEqual([]);

// packages/cards/src/dsl.test.ts:759, 'make at most one caster choice each, in the terms of T-009 plan targets'
// choices(card) joins every choice a card makes ('squad own', 'seat opponent', 'row opponent',
// 'area own WxH', 'squadToCell own') with ', ', then:
expect(Object.fromEntries(withChoices.map((card) => [card.id, choices(card)]))).toEqual({
  'resource.ember_vent': 'squad own', /* … 13 cards in all … */ 'spell.undertow': 'seat opponent',
});
```

T-053 may add choices to `choices` (copy's `copyTarget`) and cards to the map. Start from the file as T-053 left it.

## Deliverables

1. **Effects.** The `noCard` check fails only when an effect outside `noCard` has no card: `EFFECTS.filter((effect) => !used.has(effect) && !noCard.includes(effect))` is `[]`. A card that uses an effect in `noCard` passes. Update the comment above `noCard`: these effects may have no card yet.
2. **Caster choices.**
   - Every card makes at most one caster choice: no card's `choices` holds a `', '`. A failure names the card and its choices.
   - Every card in today's map still makes the choice the map gives it (`toMatchObject`, or a loop). A card that isn't in the map may make any one choice.
   - Keep the `choices` helper, and keep the map as it is after T-053.
3. **Tests that the checks still catch a mistake**: run each check's logic on a small made-up list once in the same file, or say in the PR how you checked by hand that a card with two choices, and a card in the map with a different choice, still fail.

## Acceptance

- [ ] `scripts/check.sh` is green.
- [ ] `pnpm --filter @chaosgrid/cards exec vitest run dsl` passes.
- [ ] `git diff --name-only main...HEAD` prints only `packages/cards/src/dsl.test.ts`.

## Out of scope

- Card data, the schema and the DSL.
- The other checks in the file. They're one-way already, or they check every card (`spawn only unit cards that exist`).

## Notes

- From T-058's open question (2026-10-26): the exact caster-choice map made content tasks edit a file outside their scope. The lead's default: make the checks one-way, so content tasks keep their narrow scope.
- T-060 adds the cards that use `costChange`, `discard` and `fear`, so it waits for this task.
