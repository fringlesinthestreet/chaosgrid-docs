---
id: T-119
title: Animated art manifest, sprites and stills
milestone: M5
depends_on: [T-118, T-124]
branch: agent/T-119-art-manifest
model: opus
effort: high
scope:
  - apps/web/src/art/**
  - apps/web/README.md
context:
  - docs/ART.md#Keys
  - docs/ART.md#Roles
  - docs/ART.md#Sizes
  - docs/ART.md#Animations
  - docs/ART.md#Fallbacks
  - docs/ART.md#Manifest
  - apps/web/README.md#Art
  - apps/web/README.md#Rules a change must keep
---

# T-119 — Animated art manifest, sprites and stills

## Goal

Art becomes animated (D45): a key can have sprite strips, a portrait and an icon, listed by a version 2 manifest and drawn at 16 px per cell in whole multiples (D46). This task builds the art folder's half of that:

- the fixed key and animation lists, the sizes and the caps, in a module the art pack (T-123) can import too
- the version 2 loader, which never throws
- sprite textures and `SpriteView`, which T-120 to T-122 animate on the battlefield
- `stillFor`, so `CardArt` and `ArtView` draw crisp stills in any box

The battlefield doesn't animate yet: it keeps drawing stills through `ArtView`. With no manifest, every page looks as it does today.

## Interfaces

What exists (copied from the code on 2026-10-29). T-111 to T-118 don't touch `src/art/`, but they change some callers, so re-read the call sites:

```ts
// apps/web/src/art/index.ts: the only file other folders import. Its header: only this folder
//   knows art URLs (D13, D39).
export { CardArt };                                                                  // CardArt.tsx
export { artVersion, loadArtManifest, markArtFailed, resetArtManifest, subscribeArt }; // manifest.ts
export { ArtView };                                                                  // pixi.ts
export { ART_SIZE, artSize, isUiArtKey, placeholderFor, UI_ART_KEYS };               // placeholders.ts
export { placeholderColor, spriteFor, type SpriteSpec };                             // sprites.ts
// Outside src/art/, only CardArt and ArtView are imported (grep "from '(../)+art'").

// manifest.ts: D39's version 1, a flat map of key → file name
const FileName = z.string().regex(/^(?!.*\.\.)[\w-][\w./-]*$/);                   // :8
const Manifest = z.record(z.string().min(1), FileName);                            // :12
export async function loadArtManifest(baseUrl: string | undefined): Promise<void>; // :29: the only
//   fetch outside src/api/ (eslint.config.js:204). A failed fetch or a bad body keeps the placeholders.
export function ensureArtManifest(): void;               // :46: loads VITE_CHAOSGRID_ART_URL on first use
export function artUrl(key: string): string | undefined; // :52
export function markArtFailed(key: string): void;        // :58
export function subscribeArt(listener: () => void): () => void; // :65
export function artVersion(): number;                    // :71
export function resetArtManifest(): void;                // :76, for tests

// placeholders.ts
export const UI_ART_KEYS = ['ui.cardBack', 'ui.emblem', 'ui.prize', 'ui.fear', 'ui.shield',
  'ui.extraLife', 'ui.token'];                                              // :6
export const ART_SIZE = { unit: 16, large: 32, icon: 8 } as const;           // :18
export function artSize(key: string): number;                                // :158
export function placeholderFor(key: string, color: number): Placeholder;     // :186

// sprites.ts
export interface SpriteSpec { color: number; url?: string }                  // :5
export function spriteFor(key: string): SpriteSpec;                          // :43

// pixi.ts
function textureFor(key: string): Texture | null; // :36: Assets.load once per URL; a failure calls markArtFailed
export class ArtView extends Container {           // :58, label 'art'
  constructor(key: string, size: number = artSize(key));
  get artKey(): string;
  get showsImage(): boolean;
  setKey(key: string): void; // drops the image and refreshes
  refresh(): void;           // the image at size × size once loaded, else the placeholder
}

// CardArt.tsx:12: an <img> or the placeholder, drawn again when the manifest loads
export function CardArt({ cardId, size }: { cardId: string; size: number });

// Boxes in use: CardDetail 96 (T-115 adds 192), CardTile and DeckPanel 48, DecksPage and the lobby 32,
//   ResourceEntry 24, PlanGrid a footprint × its cell − 6 (T-117 and T-118 change PlanGrid).
// scene.ts: ArtView at CELL (16) for units and squads, at the area's shorter side for permanents,
//   at 6 for status icons and the token marker, and at 16 for the shield effect.
// @chaosgrid/protocol exports CardId (card.ts:21) and ProjectileKind (card.ts:101).
```

What this task adds:

```ts
// manifest-schema.ts: imports only zod and @chaosgrid/protocol, so the art pack runs it in Node
export const ANIMATIONS = ['idle', 'walk', 'attack', 'hurt', 'die', 'enter', 'ability', 'cast',
  'fly', 'impact', 'play'] as const;
export type AnimationName = (typeof ANIMATIONS)[number];
/** The defaults ART.md › Animations lists, and whether the animation loops. */
export const ANIMATION_DEFAULTS: Record<AnimationName, { frames: number; ms: number; loop: boolean }>;
export const UI_ART_KEYS;         // moved here; placeholders.ts imports it
export const PROJECTILE_ART_KEYS; // `projectile.${kind}` for each ProjectileKind
export const FX_ART_KEYS;         // the nine fx.* keys
export type ArtKeyKind = 'card' | 'ui' | 'projectile' | 'fx';
/** Which form a key has, or null when it fits none (a card id is any string CardId accepts). */
export function artKeyKind(key: string): ArtKeyKind | null;
/** fly for projectiles, play for fx, cast for spell.* and resource.* ids, idle for the rest. */
export function baseAnimation(key: string): AnimationName;
export const CELL_PX = 16, PORTRAIT_PX = 32, ICON_PX = 8, MAX_ART_PX = 80; // D46
export const ATTACK_MAX_MS = 600, WINDUP_MAX_MS = 400, MIN_FRAME_MS = 16;
export interface ArtStrip { file: string; frames: number; ms: number; hit?: number }
export interface ArtEntry { sprite?: Partial<Record<AnimationName, ArtStrip>>; portrait?: string; icon?: string }
/** Never throws: what's valid, and one warning per part it dropped. */
export function parseArtManifest(json: unknown): { art: Map<string, ArtEntry>; warnings: string[] };

// manifest.ts
/** Whether the loaded manifest lists a sprite for the key; its files may still be loading. */
export function hasSprite(key: string): boolean;

// stills.ts (pure)
export type Still =
  | { role: 'portrait' | 'idle' | 'icon'; url: string; frame: { x: number; width: number; height: number }; scale: number }
  | { role: 'placeholder' };
/** ART.md › Stills: the first role that fits `box` at ×1, at its largest whole multiple. */
export function stillFor(key: string, box: number): Still;

// sprite-clock.ts (pure): the frame and priority rules, so they're tested without Pixi
/** Which animation shows and which frame of it, at `now` (ms), given what was asked to play. */
export function frameAt(state: SpriteClock, now: number): { animation: AnimationName; frame: number };

// pixi.ts
/** A key's sprite in a box, animated. Without a sprite it draws the key's still, like ArtView. */
export class SpriteView extends Container {
  constructor(key: string, box: { width: number; height: number },
    options?: { anchor?: 'bottom' | 'centre' });
  get artKey(): string;
  setKey(key: string): void;
  has(animation: AnimationName): boolean;      // loaded and listed
  /** Starts a one-shot as if it began at `startMs`, now or earlier, so a late start skips frames. False when missing or outranked. */
  play(animation: AnimationName, startMs: number): boolean;
  /** Drops `animation` if it's the one-shot playing; the sprite goes back to its loop. */
  cancel(animation: AnimationName): void;
  setLoop(loop: 'walk' | 'fly' | null): void; // null: idle
  setFacing(facing: 'left' | 'right'): void;  // mirrors the strip
  setHeading(radians: number): void;          // turns fly (projectiles); impact stays upright
  setSpeed(speed: number): void;              // 1, 2 or 4: frames last 1 ÷ speed as long
  hitMs(): number;                            // attack's wind-up: hit × ms ÷ speed, 0 without an attack strip
  durationMs(animation: AnimationName): number; // frames × ms ÷ speed, 0 when missing
  update(now: number): void;                  // picks the frame; the scene calls it every tick
}

// index.ts adds SpriteView, hasSprite, stillFor and manifest-schema.ts's exports; frameAt stays inside.
```

## Deliverables

1. **The fixed lists.** `manifest-schema.ts` holds the keys, the animations and their defaults, the sizes and the caps from ART.md, and nothing that needs a browser. `placeholders.ts` takes `UI_ART_KEYS` from it, and the art keeps the placeholders it has today.
2. **The version 2 loader.** `parseArtManifest` reads `{ "version": 2, "art": { … } }` and drops the smallest invalid part, with one warning each:
   - an entry whose key fits no form
   - a role whose file name is bad
   - an animation with fewer than 1 frame, under 16 ms a frame, a `hit` on anything but `attack` or past the last frame, or over a cap
   - a sprite without its base animation (the key keeps its still)

   `hit` defaults to frames ÷ 2 rounded down. Any other version, D39's flat map included, loads nothing and warns once. `loadArtManifest` uses it and writes the warnings with `console.warn`, once per load. A file that fails to load drops only that file for the session.
3. **Textures.** Each strip loads once per URL, on first draw of its key. A strip whose width its frame count doesn't divide is dropped when it loads, with a warning. Frames are sub-textures of the strip, drawn with nearest-neighbour scaling and `roundPixels`, which pixi.ts already sets for every texture and sprite (:16–17, :93).
4. **Stills.** `stillFor(key, box)` follows ART.md › Stills: the portrait, else idle's first frame, else the icon, the first that fits at ×1, drawn at the largest whole multiple. `CardArt` draws through it (a CSS sprite of the frame, `image-rendering: pixelated`, centred in its `size` box). `ArtView` does too, so the battlefield's stills turn crisp before it animates. Both keep their props, constructor and methods, since their callers are out of scope.
5. **SpriteView.** The class above, with the rules of ART.md › Animations:
   - one-shots return to the loop, except `die`, which holds its last frame until another one-shot plays (a finished one-shot outranks nothing, so a respawn's `enter` plays)
   - the priority order, where a lower one-shot is refused
   - facing by mirroring, heading for `fly`
   - speed scaling
   - `bottom` anchoring for cells (frames bigger than the base grow up and to both sides) and `centre` for the rest
   - at the largest whole multiple of the base frame that fits the box, never below ×1
   - with `prefers-reduced-motion: reduce`, loops hold their first frame

   A key with no sprite draws its still and `play()` returns false, so the caller shows the fallback. The rules live in `sprite-clock.ts`, and the class only draws what it says.
6. **Docs.** `index.ts`'s header names manifest-schema.ts as the one file the art pack imports directly. apps/web/README.md's Art section describes version 2 and points at ART.md.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test art` passes, with tests for:
  - [ ] `parseArtManifest`: a valid manifest, each drop rule, version 1 and junk
  - [ ] `stillFor` at the boxes in use: 16, 24, 32, 48, 96, 192
  - [ ] `frameAt`: loops, a one-shot back to its loop, `die` holding its last frame, priority, speed 2 and 4, a start in the past (skipping frames), a cancelled one-shot
- [ ] `grep -c -E "from 'pixi.js'|from 'react'|document|window" apps/web/src/art/manifest-schema.ts` prints 0
- [ ] With `VITE_CHAOSGRID_ART_URL` unset, the existing art tests pass unchanged, and `pnpm test:e2e` passes (nothing looks different)

## Out of scope

- Animating the battlefield: T-120 to T-122. Its scene keeps `ArtView` here.
- The art pack (T-123), and any real art.
- Resizing the 48, 24 and PlanGrid boxes to whole multiples (ART.md › Stills says why it waits).

## Notes

- Default: `SpriteView` draws only the art. The battlefield keeps drawing owner frames, bars and icons itself, as today.
- The scene's status icons and token marker are 6 px boxes, smaller than an 8 px icon, so they keep their placeholders even once art exists. T-120 grows them to 8. With no art, nothing changes.
- Default: a key's files load together, the first time it's drawn. A role counts as missing until its file has loaded (ART.md › Fallbacks).
- Default: `stillFor` crops a frame out of the strip, so the DOM fetches the strip itself, which the browser caches by content hash.
- Default: the manifest's warnings are only `console.warn`: there's no error page for bad art.
- T-124 is a dependency only because both cards edit `apps/web/README.md`: T-124 adds the Folders row and `## Text`, this card rewrites `## Art`. D50 doesn't apply here: the module shows the player no text.
- The model is opus because the module has a strict contract and other cards build on it: T-120, T-121, T-122 and T-123.
