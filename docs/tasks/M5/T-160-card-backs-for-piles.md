---
id: T-160
title: Card backs for piles
milestone: M5
depends_on: [T-152, T-156]
branch: agent/T-160-card-backs-for-piles
model: sonnet
effort: high
scope:
  - apps/web/src/art/**
  - apps/web/art-pack/**
  - apps/web/README.md
context:
  - docs/ART.md#Roles
  - docs/ART.md#Stills
  - docs/ART.md#Fallbacks
  - docs/ART.md#Manifest
  - docs/ART.md#Art pack
  - apps/web/README.md#Art (D39, D45)
  - apps/web/README.md#Tests
---

# T-160 — Card backs for piles

## Goal

The human drew three card backs, 16×22, 32×44 and 64×88 px, so the main deck and the resource deck can show as "piles of reversed cards" (playtest, 2026-11-04). D59 makes them `ui.cardBack`'s fourth role, `back`. After this task the art pack takes the three files, the manifest lists them, and the web draws a back in any box, in the DOM and in Pixi, with a card-shaped placeholder while the files are missing. T-161 draws the piles behind each grid with it.

## Interfaces

What exists (copied on 2026-11-04):

```ts
// apps/web/src/art/manifest-schema.ts: no React, Pixi or DOM, since the art pack imports it.
export interface ArtEntry { sprite?: Partial<Record<AnimationName, ArtStrip>>; portrait?: string; icon?: string }
export const UI_ART_KEYS: readonly [..., 'ui.cardBack', ...];
export function parseArtManifest(json: unknown): { ... };   // drops bad entries with a console.warn, never throws

// apps/web/src/art/stills.ts
export type Still =
  | { role: 'portrait' | 'idle' | 'icon'; url: string; frame: { x: number; width: number; height: number }; scale: number }
  | { role: 'placeholder' };
export function stillFor(key: string, box: number): Still;   // a square box

// apps/web/src/art/CardArt.tsx: CardArt({ cardId, size }), a size px square, aria-hidden, with
// data-art={cardId} and data-still={still.role}; it draws again on subscribeArt.
// apps/web/src/art/pixi.ts: class ArtView extends Container { constructor(key, size = artSize(key)); refresh(): void }
// apps/web/src/art/placeholders.ts: interface Placeholder { size: number; rects: readonly PlaceholderRect[] },
// square, where PlaceholderRect = [x, y, width, height, color].
// apps/web/src/art/manifest.ts: loadArt(key) loads a key's files once; loadedImage(url); markArtFailed(url).

// apps/web/art-pack/kinds.ts: specFor(key, kinds): KeySpec | null, where 'ui.cardBack' is
// { name: 'the card back', animations: ['idle', 'enter'], ... }.
// apps/web/art-pack/check.ts (checkArt) and pack.ts (packArt, which writes only when there's no problem).
```

What this task adds, for T-161 and later pages:

```ts
// manifest-schema.ts
export const BACK_SIZES = {
  small: { width: 16, height: 22 },
  medium: { width: 32, height: 44 },
  large: { width: 64, height: 88 },
} as const;
export type BackSize = keyof typeof BACK_SIZES;
// ArtEntry gains back?: Partial<Record<BackSize, string>>, on 'ui.cardBack' only.

// stills.ts: Still's role union gains 'back'.
export function backFor(width: number, height: number): Still;   // 'back' or 'placeholder'

// CardBack.tsx
export function CardBack({ width, height }: { width: number; height: number }): JSX.Element;

// pixi.ts
export class BackView extends Container { constructor(width: number, height: number); refresh(): void }
```

## Deliverables

1. **The manifest's `back`** (ART.md › Manifest): on `ui.cardBack`, a map of `small`, `medium` and `large` to file names, each optional. `parseArtManifest` keeps it there. It drops `back` on any other key, and a size name it doesn't know, each with a `console.warn`. The manifest stays version 2.
2. **Loading:** `loadArt('ui.cardBack')` loads the backs with the key's other files. A back whose image isn't exactly its size once loaded is dropped for the session, as a file that fails to load is (ART.md › Fallbacks).
3. **`backFor(width, height)`** (ART.md › Stills): of the backs that have loaded, the one that draws largest in the box at its largest whole multiple; when two draw the same size, the larger back. The result is a `Still` with the role `'back'`, whose frame is the whole image. When no back fits or none has loaded, `{ role: 'placeholder' }`. With all three loaded:

   | Box | Result |
   | --- | --- |
   | 112×154 (the small face) | small ×7 |
   | 192×264 (the medium face) | large ×3 |
   | 320×440 (the large face) | large ×5 |
   | 32×44 | medium ×1 |
   | 20×30 | small ×1 |
   | 8×11 | placeholder |

   With only the large back loaded, 112×154 gives large ×1.
4. **The placeholder back**, in `placeholders.ts`: a card shape, the largest whole multiple of 8×11 that fits the box, centred, filled with `ui.cardBack`'s placeholder colors and outlined 1 px. A box under 8×11 draws nothing.
5. **`CardBack({ width, height })`**, the DOM back, drawn as `CardArt` draws a still: a `width`×`height` box with the back centred at its multiple and `image-rendering: pixelated`, else the placeholder back. It carries `data-art="ui.cardBack"` and `data-still` (`back` or `placeholder`), is `aria-hidden` because a pile's count is its text, and draws again when the manifest or a file loads.
6. **`BackView(width, height)`**, the Pixi back, as `ArtView`: `backFor`'s still centred in the box, else the placeholder back, and `refresh()` picks again once a file has loaded.
7. **Exports** from `art/index.ts`: `BACK_SIZES`, `BackSize`, `backFor`, `CardBack` and `BackView`.
8. **The art pack** (ART.md › Art pack): `ui.cardBack/` may hold `back-small.png`, `back-medium.png` and `back-large.png`. A back that isn't exactly its size is a problem that names the file, its size and the size expected. In any other key's folder those names are problems, as unknown files are today. The pack copies each back as `<sha256>.png` and lists it under the entry's `back`.
9. **The web README** › Art (D39, D45):
   - The manifest's shape gains `"back"?`, and a sentence says piles draw `CardBack` or `BackView` through `backFor`.
   - The art pack paragraph names the three back files.
   - The local art paragraph leads with T-156's `pnpm dev`, which packs `Art/` and serves it under `/art/` (`CHAOSGRID_ART_DIR` points elsewhere; problems print and the game uses placeholders). `--serve` with `VITE_CHAOSGRID_ART_URL` stays for packed art served elsewhere.
10. **Tests:**
    - `manifest-schema.test.ts`: `back` on `ui.cardBack` parses. It's dropped with a warning on another key, and so is a size name it doesn't know.
    - `art.test.tsx`: `backFor`'s table above, with the images stubbed as loaded, as the still tests do. A back of the wrong size is dropped. `CardBack` with no manifest renders the placeholder (`data-still="placeholder"`), and with the backs loaded the 112×154 box draws the small back at 112×154.
    - `check.test.ts` and `pack.test.ts`, with PNGs from `test-support.ts`: the three backs pack and the manifest lists them under `back`; a 16×16 `back-small.png` is a problem; a `back-small.png` in a unit's folder is a problem; a second run writes the same bytes.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test src/art art-pack` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Drawing the piles, their counts and what a click on one shows: T-161.
- Face-down cards: the battlefield's face-down permanent and any face-down card in the DOM keep `ui.cardBack`'s portrait and sprite (D59).
- The human's files: the main checkout's `Art/reverse/` holds the three backs under other names. The human moves them into `Art/ui.cardBack/` once this merges. Don't read or change `Art/`: it's outside the worktree and git-ignored.

## Notes

- Defaults: the backs load with the key's other files, so a page that draws a pile loads `ui.cardBack` once, through `loadArt`, as `CardArt` does.
- `BackView` and `CardBack` take a box, not a size name, so the caller decides the box: a face's box for a pile in the DOM, a few cells for one on the battlefield.
