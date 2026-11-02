---
id: T-096
title: Break core's import cycles
milestone: M3
depends_on: [T-053]
branch: agent/T-096-core-import-cycles
model: sonnet
effort: medium
scope:
  - packages/core/src/**
  - packages/core/README.md
context:
  - docs/DECISIONS.md#Decision log
  - packages/core/README.md#Module map
  - packages/core/README.md#Tests
---

# T-096 — Break core's import cycles

## Goal

Two groups of modules in `packages/core/src/effects/` import each other in a circle. Lint and the tests pass, because every import in them is used only inside functions. But ESM evaluates a cycle in an order that depends on which module loads first. A top-level use (a constant built from an import, a `const` table of handlers) would see `undefined`, and the next card task to add one would hit it. The human chose to fix it now (D35): break both cycles without changing behaviour, and add a test that fails on any new cycle.

## Interfaces

What exists (copied from the code on 2026-10-26; check it again after T-053):

```ts
// Cycle 1: targets → ward → keywords → modifiers / stats → targets
// effects/targets.ts:30     import { makeWardTest } from './ward';  // unitTargets(…, ward = true); statics pass ward = false
// effects/ward.ts:3         import { effectiveKeywords, staticKeywordChanges } from './keywords';
// effects/keywords.ts:8,10  import { covers, isActive } from './modifiers'; import { makeStatsOf, staticAbilities, staticCovers, … } from './stats';
// effects/modifiers.ts:12   import { matchesFilter, onSide } from './targets';
// effects/stats.ts:19-27    import { groupOf, isGroupTarget, matchesFilter, onSide, scopeTest, unitTargets, type Targeting } from './targets';
// effects/areaTargets.ts:11 import { groupOf, matchesFilter, onSide, scopeTestCells, type Targeting } from './targets'; (not in the cycle)

// Cycle 2: triggers → registry → handlers → triggers
// effects/triggers.ts:9,12  import { justRevived } from './handlers/revive'; import { handlerFor, type EffectHandler } from './registry';
//                           runNow() calls handlerFor(ability.effect) at once, so fire() runs handlers
// effects/registry.ts:8,18  import { drawHandler } from './handlers/draw'; import { reviveHandler } from './handlers/revive';
//                           EFFECT_HANDLERS is a top-level const table of every handler
// effects/handlers/draw.ts:2  import { drawFor } from '../draws';
// effects/draws.ts:6          import { fire } from './triggers';  // fire(ctx, 'onDraw', { card })
// effects/handlers/revive.ts:16-17 import { makeStatsOf } from '../stats'; import { fire } from '../triggers';
//                           fire(ctx, 'onPlay' …), fire(ctx, 'onEnter' …); justRevived(state, unit) at :214
// effects/ctx.ts:20         export interface EffectsCtx extends Ctx { readonly toWorld?: ToWorld }

// packages/core/src/modules.test.ts: reads the folders with node:fs (existsSync, fileURLToPath)
```

D35 (docs/DECISIONS.md): `packages/core` has no import cycles. Only value imports count: `import type`, and an import whose names are all `type`, are free. A test reads the sources and fails, naming the cycle.

## Deliverables

1. **Cycle 1.** Default: move the pure predicates that don't need Ward (`onSide`, `matchesFilter`, `groupOf`, `isGroupTarget`, `settleFilter`, `scopeTest`, `scopeTestCells` and their helpers) to a new leaf module, for example `effects/filters.ts`, that imports neither `ward.ts` nor `keywords.ts`. `modifiers.ts`, `stats.ts` and `areaTargets.ts` import them from there. `stats.ts` collects its static targets with a collector that never asks about Ward (statics ignore Ward already: `ward = false`), so it doesn't import `targets.ts` at all. `targets.ts` keeps what needs Ward and may re-export the moved names, so callers outside `effects/` don't change.
2. **Cycle 2.** Default:
   - `justRevived` moves to a leaf module (for example `effects/revived.ts`) that `triggers.ts` and `handlers/revive.ts` both import.
   - Handlers and `draws.ts` stop importing `triggers.ts`. The module that runs abilities hands them a way to fire triggers instead, for example a `fire` field on `EffectsCtx` that `triggers.ts` fills before it calls a handler, or an argument. Pick the smallest change and say in the PR which one.
   - If a different cut is smaller, take it and say why.
3. **The guard**, `packages/core/src/imports.test.ts`:
   - Read every non-test `.ts` file under `packages/core/src` with `node:fs`, as `modules.test.ts` does.
   - Build the graph of relative value imports and re-exports (`import … from './x'`, `export … from './x'`). Skip `import type`, `export type`, and an import whose names are all `type`. Resolve `./x` to `x.ts` or `x/index.ts`.
   - Fail when the graph has a cycle, and name the files on it in order (`effects/a.ts → effects/b.ts → effects/a.ts`).
   - A second test runs the cycle finder on a tiny made-up graph with one cycle and one without, so the guard can't pass by finding nothing.
4. **Docs.** `packages/core/README.md` › Module map: one line saying core has no import cycles (D35), that `imports.test.ts` checks it, and where the predicates now live.

## Acceptance

- [ ] `scripts/check.sh` is green.
- [ ] `scripts/check.sh soak` is green.
- [ ] `pnpm --filter @chaosgrid/core exec vitest run imports` passes, and fails when you add `import { fire } from './triggers'` back to `effects/draws.ts` (try it, then undo it).
- [ ] `git diff --stat main...HEAD -- tools/sim-cli/test/golden` prints nothing: no behaviour changed.

## Out of scope

- Any change to what core does: events, state and goldens stay the same.
- Package exports (`packages/core/src/index.ts`'s public names). They stay as they are.
- Cycles outside `packages/core`, and a lint rule for cycles (the test is the guard).

## Notes

- From the merged M3 tasks' open questions (2026-10-26): "effects/targets.ts and effects/ward.ts/keywords.ts form an ESM import cycle (function-level use only)." The lead found the second cycle while writing this card.
- Decision (human, 2026-10-26): fix it now rather than leave a note (D35). It runs right after T-053, and T-064 waits for it, because both change `packages/core/src/**`.
- A cycle the guard finds after T-053's rebase counts too: break it the same way, or ask `lead` if it can't be broken without a worse split.
