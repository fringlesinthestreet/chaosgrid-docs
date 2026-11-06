---
id: T-211
title: Art for the Fleeting badge
milestone: M5
depends_on: [T-194]
branch: agent/T-211-art-for-the-fleeting-badge
model: sonnet
effort: medium
scope:
  - apps/web/art-pack/**
context:
  - docs/ART.md#Sizes
  - apps/web/README.md
---

# T-211 — Art for the Fleeting badge

## Goal

T-194 renamed the art key `ui.retiring` to `ui.fleeting` and dropped `ui.durability`, but only the placeholder rows changed. Make the art pack carry `ui.fleeting` and no gone keys, so the real art shows the badge.

## Interfaces

The art pack is built by `apps/web/art-pack/` from the export in the main checkout's `Art/`. The keys and sizes are in docs/ART.md. `ui.fleeting` is an 8×8 icon.

## Deliverables

1. Check whether `Art/` has a frame for `ui.fleeting`, `ui.retiring` or `ui.durability`, and what the pack builder does with each.
2. If the builder only needs a file or a name mapping, add or rename it so the pack validates and packs with `ui.fleeting`.
3. If an image is missing, don't invent one: say in the PR which file the human has to draw, and leave the placeholder.

## Acceptance

- [ ] `crew check` green
- [ ] The art pack's own check (`apps/web/art-pack/check.ts`) passes and names no gone key

## Out of scope

- Drawing new art.
- Any change under `apps/web/src/`.

## Notes

`Art/` is ignored by git, so read it from the main checkout.
