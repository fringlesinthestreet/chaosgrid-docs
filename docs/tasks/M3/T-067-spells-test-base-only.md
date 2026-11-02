---
id: T-067
title: Spell class test covers base set only
milestone: M3
depends_on: [T-042]
branch: agent/T-067-spells-test-base-only
model: sonnet
effort: low
scope:
  - packages/cards/src/spells.test.ts
context:
  - packages/cards/README.md#Spells
---

# T-067 — Spell class test covers base set only

## Goal

The test "give every spell and Rest ability a class that fits its text" loads every card and compares their classes with a hard-coded map of all spell ids. So each content task that adds a spell (T-054 to T-060) breaks it, and none of them may edit it. After this task, the test checks only the cards with `set === 'base'`, so a new set can add spells without touching this file.

## Interfaces

What exists (copied from the code on 2026-10-22):

```ts
// packages/cards/src/spells.test.ts:268, the only test in the file that loads the real cards
describe('the sample cards', () => {
  const cards = loadCards(); // every card in packages/cards/data, from every set
  it('give every spell and Rest ability a class that fits its text', () => {
    // classes[card.id] = card.spell for each spell, ability.spell for each onRest ability,
    // then expect(classes).toEqual({ ...18 ids: 3 resources and 15 spells })
  });
});
// Card.set: a slug string (packages/cards/src/schema.ts:51). The sample cards use 'base'.
// The content tasks use 'earth', 'ember_tide', 'colorless', 'dark', 'light', 'duals' and 'mechanics'.
```

## Deliverables

1. **The filter.** The test collects classes only from cards whose `set` is `'base'`. Its map keeps every base spell and Rest ability with its class, unchanged: that map is the check that each base card's class fits its text.
2. **The name and a comment.** Rename the test to say it covers the base set, for example "give every base spell and Rest ability a class that fits its text". Add a one-line comment above it: other sets check their own spells in `packages/cards/test/sets/<set>.test.ts`.

## Acceptance

- [ ] `crew check` green
- [ ] With the Earth set: in your worktree, run `git checkout agent/T-054-earth-set -- packages/cards/data`, then `pnpm --filter @chaosgrid/cards test src/spells.test.ts` passes. Then run `git restore --source=HEAD --staged --worktree packages/cards/data`, and check that `git status --short packages/cards/data` prints nothing: those files aren't in your scope, so never commit them.

## Out of scope

- The schema tests above it (lines 1 to 266). They check spell classes on any card, through `CardSchema` and `AbilitySchema`, and stay as they are.
- Checking the classes of other sets' spells: each content task does that in its own `packages/cards/test/sets/<set>.test.ts`.
- The Earth cards themselves (T-054).

## Notes

- From T-054's request (2026-10-22): the hard-coded map broke T-054's gates, and every content task would hit the same failure.
- Default: filter on `card.set === 'base'`, not on a list of the other sets, so a future set needs no change here.
- A stated exception to planning rule 1: T-043 (wave 4, in flight) has `packages/cards/**` in its scope, which holds this file. Keep the diff inside the last `describe`. If T-043 changes a base spell's class, its hunk is in the map, and whichever task merges second rebases.
- Rules tasks that add or change a base spell or Rest ability (T-043 to T-064) keep updating the map, as they do today.
