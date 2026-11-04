---
id: T-175
title: Commas in color lists
milestone: M5
depends_on: []
branch: agent/T-175-commas-in-color-lists
model: haiku
effort: low
scope:
  - apps/web/src/cards/names.ts
  - apps/web/src/cards/names.test.ts
context:
  - apps/web/README.md#Text (D50)
  - apps/web/README.md#Tests
---

# T-175 — Commas in color lists

## Goal

From T-152's review (2026-11-04): `cardColorNames` joins a card's color names with spaces, so the card browser's Table view shows a two-color card as "Ember Dark", which reads like one color. After this task it reads "Ember, Dark".

## Interfaces

What exists (copied on 2026-11-04):

```ts
// apps/web/src/cards/names.ts:21
export function cardColorNames(card: Card): string {
  const colors = cardColor(card);
  if (colors.length === 0) return colorName('colorless');
  return new Intl.ListFormat(locale(), { type: 'unit', style: 'narrow' }).format(
    colors.map(colorName),
  );
}
// apps/web/src/cards/CardTable.tsx:50 <td>{cardColorNames(card)}</td>, its only caller.
```

## Deliverables

1. **`cardColorNames` lists with commas:** `Intl.ListFormat`'s `{ type: 'unit', style: 'short' }`, which gives "Ember, Dark" in English.
2. **`names.test.ts`**, new: a two-color card reads "Ember, Dark", a one-color card its color's name, and a colorless card the colorless name.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test names` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Other lists, and the card face, which doesn't use `cardColorNames`.

## Notes

- Take the expected names from `en/cards.json`, whatever the colors are called there.
