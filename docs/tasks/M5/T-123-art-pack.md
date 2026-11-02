---
id: T-123
title: Art pack and local art server
milestone: M5
depends_on: [T-119]
branch: agent/T-123-art-pack
model: sonnet
effort: high
scope:
  - apps/web/art-pack/**
  - apps/web/package.json
  - apps/web/tsconfig.json
  - apps/web/vitest.config.ts
  - apps/web/README.md
  - eslint.config.js
context:
  - docs/ART.md#Keys
  - docs/ART.md#Roles
  - docs/ART.md#Sizes
  - docs/ART.md#Animations
  - docs/ART.md#Per card kind
  - docs/ART.md#Manifest
  - docs/ART.md#Art pack
  - apps/web/README.md#Art
  - apps/web/README.md#Tests
---

# T-123 — Art pack and local art server

## Goal

`pnpm --filter @chaosgrid/web art:pack <in> <out> [--serve <port>]` checks a folder of PNGs against ART.md's rules and writes what the bucket serves: each file under its content hash, and a version 2 `manifest.json` (D45). An animation delivered as one PNG per frame, the way Fable exports them, is stitched into the strip the manifest lists. With `--serve`, it then serves `<out>` on this machine, so a local game with `VITE_CHAOSGRID_ART_URL` set to it shows the art. Whoever makes the art can check it and see it in the game before anything is uploaded. Nothing is uploaded.

## Interfaces

What exists (copied from the code on 2026-10-29):

```ts
// From T-119, so re-read it: apps/web/src/art/manifest-schema.ts, which imports only zod and
//   @chaosgrid/protocol. art/index.ts's header names it as the one art file the pack imports directly.
export const ANIMATIONS = ['idle', 'walk', 'attack', 'hurt', 'die', 'enter', 'ability', 'cast',
  'fly', 'impact', 'play'] as const;
export type AnimationName = (typeof ANIMATIONS)[number];
export const ANIMATION_DEFAULTS: Record<AnimationName, { frames: number; ms: number; loop: boolean }>;
export const UI_ART_KEYS, PROJECTILE_ART_KEYS, FX_ART_KEYS; // the fixed key lists
export function baseAnimation(key: string): AnimationName;  // fly, play, cast for spell.* and resource.*, else idle
export const CELL_PX = 16, PORTRAIT_PX = 32, ICON_PX = 8, MAX_ART_PX = 80; // D46
export const ATTACK_MAX_MS = 600, WINDUP_MAX_MS = 400, MIN_FRAME_MS = 16;
export interface ArtStrip { file: string; frames: number; ms: number; hit?: number }
export interface ArtEntry { sprite?: Partial<Record<AnimationName, ArtStrip>>; portrait?: string; icon?: string }
export function parseArtManifest(json: unknown): { art: Map<string, ArtEntry>; warnings: string[] };

// packages/cards: @chaosgrid/cards, and @chaosgrid/cards/node for Node code
export type Card = z.infer<typeof CardSchema>; // schema.ts:438, discriminated on `type` (:408-409)
// An artifact or an enchantment is mode 'attached', with no area (:315-318), or 'freeStanding', with
//   area: [w, h] (:320). A trap is always free-standing (:325). A Chaos card's kind is one of
//   CHAOS_KINDS = ['units', 'rule', 'emblem', 'nothing'] (:371).
export function loadCards(dir = DEFAULT_CARDS_DIR): Card[]; // node/load.ts:120: packages/cards/data
//   (:15); throws a CardLoadError (:105) naming each bad file and field.

// tools/sim-cli/src/command.ts:202-205: simCommand(args, { out, env, cwd }) returns the exit code, and
//   resolves the user's paths against `options.cwd ?? env.INIT_CWD ?? process.cwd()`, since pnpm runs
//   a package's script in the package's folder. packages/db/src/commands.ts:61 does the same.

// eslint.config.js
const WEB = ['protocol', 'cards', 'http']; // :19
{ dir: 'apps/web', except: ['apps/web/src/**'], workspace: WEB }, // config files, run by Node (:43)
// That zone isn't `browser`, so Node built-ins pass, but its workspace list has no 'cards/node', and
//   the check matches whole names (:75), so `@chaosgrid/cards/node` fails there today, tests included:
//   devZone (:61-66) adds it only to browser zones. apps/api's zone lists it (:40). The web rules
//   (:198-243) cover only apps/web/src/**.

// apps/web
// package.json scripts (:5-11): dev, build, typecheck ("tsc --noEmit && tsc --noEmit -p
//   tsconfig.src.json"), test ("vitest run"), test:e2e. tsx, @types/node and vitest are devDependencies.
// tsconfig.json: its comment (:3-5) says it adds Node types for tests, e2e and config, and that
//   ESLint reads it; "types": ["node", "vite/client"] (:11); "include": ["src", "test", "e2e", "*.config.ts"] (:13).
// vitest.config.ts: environment './test/jsdom-environment.ts', include ['src/**/*.test.{ts,tsx}',
//   'e2e/**/*.test.ts'], setupFiles ['test/setup.ts']; its comment (:4) still says "Unit tests only".
// e2e/ports.test.ts:1 `// @vitest-environment node`: the precedent for Node tests in this package.
```

What this task adds:

```ts
// apps/web/package.json
"art:pack": "tsx art-pack/cli.ts"
// devDependencies: "pngjs": "7.0.0" and "@types/pngjs": "6.0.5", exact versions with no range. The
//   catalog in pnpm-workspace.yaml is a root file (planning rule 4), so T-124 pins intl-messageformat
//   the same way. If pnpm install can't find a version, use the latest release its error names.
// tsconfig.json: "art-pack" in include, and its comment names it. vitest.config.ts:
//   'art-pack/**/*.test.ts' in include, and its comment says which tests run where.
// eslint.config.js:43
{ dir: 'apps/web', except: ['apps/web/src/**'], workspace: [...WEB, 'cards/node'] }, // config files, e2e/ and art-pack/, run by Node

// apps/web/art-pack/: a shape to start from, which the worker may change. It imports
//   '../src/art/manifest-schema' (inside apps/web, so noRelativeCrossPackage allows it),
//   @chaosgrid/cards, @chaosgrid/cards/node, Node built-ins and pngjs, for the numbered frames only:
import { PNG } from 'pngjs';
PNG.sync.read(buffer); // { width, height, data: Buffer }: 8-bit RGBA, width × height × 4, whatever the
//   file's colour type; throws on a PNG that doesn't decode
new PNG({ width, height }); // a blank RGBA image
PNG.bitblt(src, dst, srcX, srcY, width, height, dstX, dstY); // copies a rectangle of pixels
PNG.sync.write(png); // a Buffer: 8-bit RGBA, deflated by Node's zlib
export type PackKind =
  | { kind: 'unit' | 'emblem' | 'cast' | 'none' }
  | { kind: 'permanent'; basePx: number };
/** A card's kind for the pack (deliverable 1). */
export function artKindOf(card: Card): PackKind;
export interface ArtProblem { path: string; message: string } // path is relative to <in>
/** Reads and checks `inDir`, with `kinds` mapping each card id to its kind. Writes nothing. */
export function checkArt(inDir: string, kinds: ReadonlyMap<string, PackKind>): { entries; problems: ArtProblem[] };
//   entries: each key's files, with frames, ms and hit filled in; a numbered-frame animation lists its files in order
/** checkArt, then writes `outDir` only when there's no problem. */
export function packArt(inDir: string, outDir: string, kinds: ReadonlyMap<string, PackKind>): ArtProblem[];
/** Serves `dir` on 127.0.0.1 (deliverable 5). Port 0 picks a free port. */
export function serveArt(dir: string, port: number): Promise<Server>;
// cli.ts: like simCommand, a command that takes the args and { out, env, cwd } and returns the exit
//   code, so tests run it without a process. It builds `kinds` from loadCards() with artKindOf.
```

## Deliverables

1. **Kinds.** Each key gets a base animation, a base frame and the animations it may have (ART.md › Sizes and › Per card kind). `artKindOf` gives a card's kind from its `type`, `mode`, `area` and Chaos `kind`:

   | Keys | Base animation and frame | Animations it may have |
   | --- | --- | --- |
   | `unit`: units, Leaders, Chaos cards of kind `units` | idle, exactly 16×16 | idle, walk, attack, hurt, die, enter, ability |
   | `permanent`: traps, free-standing artifacts and enchantments | idle, exactly a square of CELL_PX × the area's shorter side, at most MAX_ART_PX: 2×2 and 2×3 give 32×32 | idle, enter, hurt, die, ability |
   | `emblem`: Chaos cards of kind `emblem`, and `ui.emblem` | idle, exactly 16×16 | idle, enter, hurt, die |
   | `cast`: spells and resources | cast, a square from 16×16 to 80×80 | cast |
   | `none`: attached artifacts and enchantments, Chaos `rule` and `nothing` cards, `ui.fear`, `ui.shield`, `ui.extraLife`, `ui.token` | no sprite | none |
   | `ui.cardBack` | idle, exactly 16×16 | idle, enter |
   | `ui.prize` | idle, exactly 32×32 | idle, enter, hurt, die |
   | `projectile.*` | fly, exactly 8×8 | fly, impact |
   | `fx.*` | play, exactly 16×16 | play |

   Every key may also have a portrait and an icon. The base animation always matches `baseAnimation(key)`.
2. **Checks.** `checkArt` finds every problem before the pack fails:
   - **Layout:** `<in>` holds one folder per key, `<in>/<key>/`, with each animation as either a `<animation>.png` strip or numbered frames `<animation>1.png` to `<animation>N.png` (a positive whole number with no leading zero), plus `portrait.png`, `icon.png` and an optional `art.json`. Any other file or folder is a problem, and so are a file at `<in>`'s root, a key folder with no PNG, and an animation in both forms.
   - **Key:** it's in UI_ART_KEYS, PROJECTILE_ART_KEYS or FX_ART_KEYS, or it's a card id in `kinds`: a card in packages/cards/data.
   - **PNG:** the file starts with the PNG signature (`89 50 4E 47 0D 0A 1A 0A`), then an `IHDR` chunk (bytes 12–15). Its width is bytes 16–19 and its height bytes 20–23, big-endian. That's all the pack reads of a strip, a portrait or an icon. A numbered frame is decoded with `PNG.sync.read`, and one that doesn't decode is a problem naming the file.
   - **Animations:** an animation's name, the file name before `.png` or the frame number, is one the key may have (deliverable 1). A key with any animation has its base animation.
   - **Frames:** in a strip, the frame count divides the width, and a frame is the width ÷ the frame count, by the full height. Numbered frames run from 1 with no gap, and every frame has frame 1's width and height; a gap or a frame of another size is a problem naming the file. An `art.json` `frames` that isn't the file count is a problem.
   - **Sizes:** the base animation's frame is the base frame. Every other animation's frame is at least the base frame and at most twice it, in each direction. A portrait is exactly 32×32 and an icon 8×8.
   - **art.json:** a JSON object keyed by animations the key has. Each value is an object with an optional `frames`, a whole number ≥ 1, an optional `ms`, a whole number ≥ MIN_FRAME_MS, and, only on `attack`, an optional `hit`, a whole number from 0 to frames − 1. Anything else is a problem.
   - **Caps:** with the defaults filled in, `attack`'s frames × ms is at most ATTACK_MAX_MS and its hit × ms at most WINDUP_MAX_MS.
   - **Output:** each problem prints as `<path relative to <in>>: <message>`, sorted, then a line with their count, and the command exits 1 having written nothing.
3. **Defaults,** for what `art.json` leaves out (ART.md › Animations):
   - `frames`: for numbered frames, their count. For a strip, the width ÷ the height, so square frames; when the width isn't a multiple of the height, that's a problem asking for `frames`.
   - `ms`: `ANIMATION_DEFAULTS[animation].ms`.
   - `hit`: frames ÷ 2, rounded down.
4. **Output.** `packArt` writes, only after a clean check:
   - Each strip, portrait and icon is copied byte for byte to `<out>/<sha256>.png`, the 64 lowercase hex digits of its bytes, so files with the same bytes share one name. Numbered frames are stitched left to right, frame 1 leftmost, into one 8-bit RGBA strip encoded with `PNG.sync.write` and written under the hash of those bytes.
   - `<out>/manifest.json` is `{ "version": 2, "art": … }`. Keys are sorted as strings, roles go in the order sprite, portrait, icon, and a sprite's animations in `ANIMATIONS` order. Each strip lists `file`, `frames` and `ms`, and `attack` also `hit`. The JSON has 2-space indents and a trailing newline, so the same input always gives the same bytes. A stitched strip is deflated by Node's zlib, so its bytes, and its name, are the same on one Node version.
   - `<out>` is created when it's missing and never cleared. manifest.json is replaced.
   - The command prints one summary line: the keys, strips, portraits and icons packed, how many strips were stitched from frames, and the files written.
   - `<in>` and `<out>` are resolved like simCommand's paths. A missing `<in>`, an `<out>` inside `<in>` or the same as it, an unknown option or a bad port is a usage error: a usage line and exit 1. A `CardLoadError` prints its message and exits 1.
5. **`--serve <port>`.** After a clean pack, `serveArt` serves `<out>` with `node:http` on 127.0.0.1:
   - It answers GET and HEAD, and 405 to anything else.
   - It serves `/manifest.json`, and `/<64 hex digits>.png` when that file is in `<out>`, ignoring a query string. Anything else is a 404, with no listing, so `..` and other names never reach the file system.
   - Each answer has its Content-Type (`application/json` or `image/png`) and `Access-Control-Allow-Origin: *`.
   - The command prints the line to set, `VITE_CHAOSGRID_ART_URL=http://127.0.0.1:<port>`, and runs until Ctrl-C. A port in use is an error that names it, with exit 1.
6. **Docs.**
   - apps/web/README.md's Art section: how to pack and serve art, with the command, `--serve`, and where to set `VITE_CHAOSGRID_ART_URL` for `pnpm dev`, with a pointer to ART.md › Art pack for the rules.
   - The README's Tests section: `art-pack/*.test.ts` are Vitest tests that run in Node.
   - The vitest.config.ts and tsconfig.json comments.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test art-pack` passes, with tests for:
  - [ ] each check in deliverable 2, failing and passing
  - [ ] each kind's base frame: a unit's 16×16, a 2×3 permanent's 32×32 and a 5×5 one's 80×80, a cast at 16, at 80 and too big at 96, the prize's 32×32 and a projectile's 8×8
  - [ ] other frames: one below the base, one at twice it, one over twice it
  - [ ] a width the frame count doesn't divide, and a strip that isn't square frames with no `frames`
  - [ ] numbered frames: two 2×2 frames with distinct pixels stitched into a 4×2 strip that `PNG.sync.read` reads back as frame 1 then frame 2; a gap in the numbering, `idle0.png`, `idle01.png`, a frame of another size, an animation in both forms, an `art.json` `frames` that isn't the count, and a frame that doesn't decode
  - [ ] both caps, at the cap and one ms over
  - [ ] art.json: each field, bad values, `hit` on another animation, an animation with no strip, an unknown field, and JSON that doesn't parse
  - [ ] the defaults
  - [ ] the output: two packs of the same input give the same bytes, a stitched animation included, identical files share one name, nothing is written when there's a problem, and `parseArtManifest` reads the manifest with no warnings
  - [ ] the command: a usage error, the sorted problems and their count, and the summary line
  - [ ] serve: a PNG and manifest.json with their Content-Type and the CORS header, HEAD, 405, and 404 for an unknown name, a hash that isn't in `<out>` and a path with `..`
- [ ] `artKindOf` gives a kind to every card loadCards() returns, and the tests check one card of each kind
- [ ] `grep -E "dir: 'apps/web', except" eslint.config.js` shows `'cards/node'`

## Out of scope

- Uploading, the bucket's provider and its cache headers (D39's "revisit when").
- Real art, and the prompt that asks Fable for it.
- Resizing or optimising images, and re-encoding a strip, a portrait or an icon: those are copied byte for byte. Only numbered frames are decoded, and only to stitch them.
- A watch mode.
- The art module (T-119) and the battlefield (T-120 to T-122).

## Notes

- Default: `walk` and `ability` are allowed on every card of the kind. ART.md › Per card kind lists them only for units with Speed above 0 or a triggered ability, but the pack reads neither, and an unused strip costs nothing.
- Default: every key may have a portrait and an icon, `projectile.*` and `fx.*` keys included.
- Default: `<out>` is never cleared, so files from earlier packs stay. The bucket keeps old files too, so an old manifest keeps working.
- Default: serve binds 127.0.0.1 only.
- Default: `hit` is written on every `attack`, even when it's the default.
- Default: names that start with "." (`.DS_Store`) are skipped.
- Default: only the PNG header is read of a strip, a portrait or an icon. A file that's corrupt past it passes, and the browser drops it when it fails to load (ART.md › Fallbacks). A numbered frame is decoded whole, since stitching needs its pixels.
- Default: a cast's side needn't be a multiple of 16.
- Why numbered frames: Fable's export (2026-10-31, the human's gitignored `Art/` folder) follows ART.md except that each animation is `<animation>1.png`, `<animation>2.png`, … with an `art.json` whose `frames` is the file count. Accepting that form saves a re-export, and the manifest still lists strips only, so T-119's art module doesn't change. Seven of its folders are T-132's new cards, which merge before this card.
- Default: a `skins/` folder under a key (D52) is unexpected like any other, until a later card bumps the manifest to version 3.
- One new dependency, for stitching: `pngjs` 7.0.0 and `@types/pngjs` 6.0.5 as devDependencies of apps/web, at exact versions with no range (Interfaces). pngjs is pure JS with no dependencies of its own and decodes every colour type to 8-bit RGBA. Everything else is `node:crypto`, `node:fs`, `node:http` and `node:path`.
- The tests write PNG headers into temp folders for the strip, portrait and icon cases, and small PNGs encoded with `PNG.sync.write` for the frame cases. They start with `// @vitest-environment node` as e2e/ports.test.ts does, serve on port 0, and pass small `kinds` maps, so new cards don't break them. There are no fixture files: apps/web/test/ is outside the scope.
- After this card, apps/web's Node-run files (the config files, e2e/ and art-pack/) may import `@chaosgrid/cards/node`. The import tables in CLAUDE.md › Architecture rules and DECISIONS.md › Import boundaries don't say so yet; the lead updates them when this card merges, so name it in the handoff.
- Send the `..` request with `node:http`'s `request`, since `fetch` resolves `..` before it sends.
