---
id: T-156
title: Local art in pnpm dev
milestone: M5
depends_on: []
branch: agent/T-156-local-art-in-pnpm-dev
model: sonnet
effort: high
scope:
  - apps/web/vite.config.ts
  - apps/web/art-pack/dev.ts
  - apps/web/art-pack/dev.test.ts
  - apps/web/src/match/planning/PlanGrid.tsx
  - apps/web/src/match/planning/PlanGrid.test.tsx
  - README.md
context:
  - docs/ART.md#Stills
  - docs/ART.md#Art pack
  - docs/ART.md#Fallbacks
  - apps/web/README.md#Art (D39, D45)
  - apps/web/README.md#Tests
---

# T-156 — Local art in pnpm dev

## Goal

The human's playtest (2026-11-04): "Sprites are not being used, permanents are still the blocks of color." The lead found two causes:

1. **`pnpm dev` loads no art.** The web draws art only from a manifest at `VITE_CHAOSGRID_ART_URL`, which takes the art pack's `--serve` in a second terminal and the variable set by hand. Without both, every key draws its placeholder: a block in its color.
2. **PlanGrid's box is too small for a unit's art.** During Plan, PlanGrid covers the own grid and draws each card with `CardArt` in a box of its footprint minus 6 px. At the default 16 px per cell, a one-cell unit gets 10 px. Its portrait (32) and idle frame (16) don't fit, and the main checkout's `Art/` has no icon for any unit, Leader, trap or Chaos card, so it draws its placeholder even with art loaded.

After this task, `pnpm dev` in a checkout with an `Art/` folder packs it and serves it from the web's own dev server, with no second terminal and no variable. PlanGrid draws art in the full footprint, so a one-cell unit draws its idle frame at 16 px per cell.

## Interfaces

What exists (copied on 2026-11-04):

```ts
// apps/web/vite.config.ts
const webPort = Number(process.env.CHAOSGRID_WEB_PORT ?? 4000);
const apiPort = Number(process.env.CHAOSGRID_API_PORT ?? 5000);
export default defineConfig({
  plugins: [react()],
  server: { port: webPort, strictPort: true, proxy: { '/api': `http://127.0.0.1:${apiPort}` } },
});

// apps/web/art-pack/pack.ts: checks inDir, then writes outDir only when there's no problem
export function packArt(inDir: string, outDir: string, kinds: ReadonlyMap<string, PackKind>):
  { problems: ArtProblem[]; summary?: PackSummary };
// apps/web/art-pack/kinds.ts: the card kinds come from packages/cards/data (artKindOf, specFor)
// apps/web/art-pack/command.ts: artPackCommand(args, options), the CLI's parsing, packing and --serve
// apps/web/art-pack/serve.ts: serveArt(dir, port), with Access-Control-Allow-Origin: *
// apps/web/art-pack/test-support.ts: the pack tests' PNG builders

// apps/web/src/art/manifest.ts:71-75: the manifest loads once, from the variable
function ensureArtManifest(): void {
  if (started) return;
  void loadArtManifest(import.meta.env.VITE_CHAOSGRID_ART_URL);
}

// apps/web/src/match/planning/PlanGrid.tsx:278-289 (a squad; a permanent at :324 does the same)
<Block key={squad.squad} cell={squad.cell} size={[w, h]} cellPx={cellPx} color={color} label={…} …>
  <CardArt cardId={squad.cardId} size={Math.max(8, Math.min(w, h) * cellPx - 6)} />
  {w * h > 1 && <span style={{ display: 'block' }}>{name} L{squad.level}{squad.leader ? ' ★' : ''}</span>}
</Block>
```

`.data/` is git-ignored, and so is `/Art/`, which exists only in the main checkout. Today the art pack refuses that folder and writes nothing: `reverse: isn't an art key or a card in packages/cards/data`. That's the human's card backs, which T-160 turns into `ui.cardBack`'s `back` role (D59). `docs/ART.md` › Stills now says PlanGrid's box is the full footprint (the lead changed it on 2026-11-04). Vitest runs `art-pack/*.test.ts` in Node, and `vite.config.ts` may import `art-pack/` and `@chaosgrid/cards/node`, since Node runs both.

## Deliverables

1. **`artDevPlugin()`**, a Vite plugin in `art-pack/dev.ts`, which `vite.config.ts` adds. It acts only on the dev server (`apply: 'serve'`), and only when `VITE_CHAOSGRID_ART_URL` is unset and the art folder exists. The folder is `CHAOSGRID_ART_DIR`, by default the repository's `Art/`, so a worktree can point at the main checkout's. Then:
   - at the server's start it packs the folder with `packArt` into `.data/art/` at the repository root, and prints one line: how many keys it packed, and how long that took;
   - it serves `.data/art/` under `/art/`, and the page's manifest URL is that path on the page's own origin (set `VITE_CHAOSGRID_ART_URL`, or `define` it);
   - when the pack finds problems, it prints them as the CLI does, plus one line saying the game uses placeholder art. The server still starts, and nothing is served under `/art/`.
2. **PlanGrid's art box** is the full footprint: `Math.min(w, h) * cellPx` for a squad and for a permanent. The `Block`'s outline and the caption stay readable: draw the outline over the art, or inset it, whichever keeps the art's pixels whole.
3. **The root README** › Run it locally: `pnpm dev` packs and serves `Art/` when the folder exists, with `CHAOSGRID_ART_DIR` to point elsewhere. The settings table gets `CHAOSGRID_ART_DIR`, and `VITE_CHAOSGRID_ART_URL`'s row says that setting it turns the local packing off.
4. **Tests:**
   - `art-pack/dev.test.ts`, with a small folder from `test-support.ts` in a temp dir: the plugin's middleware answers `/art/manifest.json` with a version 2 manifest that lists the folder's keys, and a listed PNG with its bytes. A folder with a problem gives no manifest (404) and a printed problem. With `VITE_CHAOSGRID_ART_URL` set, or with no folder, the plugin does nothing.
   - `match/planning/PlanGrid.test.tsx`: at 16 px per cell, a one-cell squad's art is a 16 px box (`[data-art]`'s width), and a 2×3 one's is 32 px.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test dev PlanGrid art` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `pnpm test:e2e` passes. The worktree has no `Art/`, so the e2e still runs with placeholder art.
- [ ] Once by hand, not committed: `CHAOSGRID_ART_DIR=<a temp folder of a few keys> pnpm --filter @chaosgrid/web dev`, then `/art/manifest.json` answers. The PR gives the pack time for that folder.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The card backs and the `reverse/` folder: T-160 (D59). Until the human moves those files into `ui.cardBack/`, packing the main checkout's `Art/` reports that one problem and the game uses placeholders.
- Repacking while the server runs: restart `pnpm dev` after changing `Art/`.
- Art below 16 px per cell: the battlefield draws markers there by design (D46).
- `apps/web/README.md`'s art pack paragraph: T-160 updates that section, after T-152's edit of the same file.

## Notes

- Default: pack at the server's start rather than on the first request, so a problem prints where the human sees `pnpm dev`'s output. If the full `Art/` takes more than a few seconds, say how long in the PR.
- The pack never clears its output folder, and the same input writes the same files, so packing at every start is safe.
