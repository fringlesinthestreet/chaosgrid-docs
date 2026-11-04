---
id: T-165
title: State icon keys and the charge color
milestone: M5
depends_on: [T-160]
branch: agent/T-165-state-icon-keys-and-the-charge-color
model: sonnet
effort: low
scope:
  - apps/web/src/art/**
  - apps/web/art-pack/**
  - apps/web/src/theme/palette.ts
  - apps/web/src/theme/palette.test.ts
context:
  - docs/ART.md#Keys
  - docs/ART.md#Sizes
  - docs/ART.md#Fallbacks
---

# T-165 — State icon keys and the charge color

## Goal

The human wants a squad's state easy to read at a glance (playtest, 2026-11-04): icons for Flying, Reach, Blocker and rested, its level, a sign when it can level up, its Durability, and a warning on the squads that retire at this Cleanup. ART.md now lists seven state icons and the badge row they form (› Sizes, the "State badges" bullet). This task adds the keys, their placeholders and the color of the Charge glow, so T-166 (PlanGrid) and T-162 (the battlefield) can draw them at the same time.

## Interfaces

What exists (copied on 2026-11-04):

```ts
// apps/web/src/art/manifest-schema.ts
export const UI_ART_KEYS = ['ui.cardBack', 'ui.emblem', 'ui.prize', 'ui.fear', 'ui.shield', 'ui.extraLife', 'ui.token'] as const;
export const ICON_PX = 8;
// apps/web/art-pack/kinds.ts › specFor: a UI key without a FIXED_SPECS entry is NO_SPRITE, so the
// pack takes its icon.png and portrait.png and no animation.
// apps/web/src/art/placeholders.ts: a UI key's placeholder is a pixel map, for example
//   'ui.shield': { rows: ['########', '#bbbbbb#', ...8 rows of 8], colors: { '#': 0x1c2b4a, b: 0x7fb2e5, w: 0xffffff } }
// apps/web/src/theme/palette.ts: COLORS { 'seat-0'..'seat-3', chaos, warning: 0xe07b2e, muted, bg, panel,
// border, text, error, and T-152's card colors }; PALETTE (Pixi) and CSS_VARIABLES (--cg-*) come from it.
```

The new keys, in ART.md's order: `ui.flying`, `ui.reach`, `ui.blocker`, `ui.rested`, `ui.levelUp`, `ui.durability`, `ui.retiring`.

## Deliverables

1. **The keys** in `UI_ART_KEYS`, each icon-only like `ui.shield`: the pack takes an 8×8 `icon.png` and a portrait for them, and no sprite.
2. **Placeholders:** an 8×8 pixel map for each, in the style of the existing ones, legible at ×1 and apart from each other and from `ui.shield`, `ui.fear` and `ui.extraLife`:
   - `ui.flying`: a wing.
   - `ui.reach`: an arrow pointing up.
   - `ui.blocker`: a wall.
   - `ui.rested`: a "z".
   - `ui.levelUp`: two chevrons, "^^".
   - `ui.durability`: a small heart or pip with room for a digit beside it.
   - `ui.retiring`: an hourglass, in `warning` orange.
3. **The color token** `charge` in `COLORS`, which reaches the DOM as `--cg-charge` and Pixi as `PALETTE.charge`. It keeps 3:1 against `bg`, and stays apart from the four seat colors, `warning` and `chaos`.
4. **Tests:**
   - `manifest-schema.test.ts`: a manifest entry with an icon parses for each new key.
   - The placeholders test: every new key has a map of 8 rows of 8.
   - `palette.test.ts`: `charge`'s contrast, as it checks the others.
   - `check.test.ts`: a folder `ui.retiring/` with an 8×8 `icon.png` packs with no problem.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test src/art art-pack palette` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Drawing the badges: T-166 in PlanGrid, T-162 on the battlefield.
- Real art for the icons: the human draws them later; the pack already takes them.

## Notes

- Defaults: the shapes above. The worker may pick others that read better at 8 px, and the PR shows each map.
