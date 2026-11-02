---
id: T-001
title: Workspace scaffold
milestone: M0
depends_on: []
branch: agent/T-001-workspace-scaffold
scope:
  - package.json
  - pnpm-lock.yaml
  - pnpm-workspace.yaml
  - tsconfig.base.json
  - tsconfig.json
  - eslint.config.*
  - .prettierrc*
  - .prettierignore
  - .editorconfig
  - .nvmrc
  - .npmrc
  - .gitignore
  - .github/workflows/ci.yml
---

# T-001 — Workspace scaffold

## Goal

Create the empty monorepo that every other task builds on. This task writes root config only, no packages. Set things up so later tasks never have to edit a root file and only add folders under `packages/`, `apps/` and `tools/`. That is what lets them run in parallel.

## Read first

- docs/DECISIONS.md: D2, D8, D9 and Import boundaries
- docs/PLAN.md: Repository layout
- CLAUDE.md: Conventions

## Deliverables

1. Root `package.json`: private, `"type": "module"`, `packageManager` set to the installed pnpm (`pnpm --version`), `engines.node` `>=22`. Add these root scripts. Each must exit 0 while its target package doesn't exist yet (use `--if-present` and filters):

   | Script | Runs |
   | --- | --- |
   | `lint` | ESLint over the whole repo |
   | `format`, `format:check` | Prettier |
   | `typecheck` | the `typecheck` script of every workspace package that has one |
   | `test` | the `test` script of every workspace package that has one |
   | `cards:validate` | `validate` in `@chaosgrid/cards` |
   | `db:migrate` | `migrate` in `@chaosgrid/db` |
   | `db:seed` | `seed` in `@chaosgrid/db` |

2. `pnpm-workspace.yaml`: `packages/*`, `apps/*`, `tools/*`, plus a `catalog:` pinning the shared dependencies (`typescript`, `vitest`, `zod`, `tsx`, `@types/node`). Packages reference them as `"catalog:"`, so parallel tasks can't pick different versions.
3. `tsconfig.base.json` with `strict`, `noUncheckedIndexedAccess`, ESM (`module: ESNext`, `moduleResolution: Bundler`), `verbatimModuleSyntax`, `isolatedModules`, `noEmit`, `skipLibCheck`, and target ES2022 or later. Every package extends it. Add a root `tsconfig.json` only if typed linting of root files needs one.
4. ESLint flat config: typescript-eslint with typed linting, Prettier compatibility, and the import boundaries from DECISIONS.md. Write the boundaries now for every planned package: `packages/{core,protocol,cards,db,bots}`, `apps/web` (including the `src/host/` exception), `apps/api` and `tools/sim-cli`. Use `no-restricted-imports` per `files` glob. That includes rule 6: no Node built-ins in `core`, `protocol`, `cards` or `bots`, with the one exception of `packages/cards/src/node/**`. Also forbid `Math.random` in `packages/core/**` (D8). Ignore `node_modules`, `dist`, `coverage`, `.data` and `.claude/worktrees`.
5. Prettier config and ignore file. Ignore `pnpm-lock.yaml`, `.data` and `.claude/worktrees`.
6. `.nvmrc` containing `22`, plus `.editorconfig`. Add `.npmrc` only if needed.
7. `.gitignore` already exists. Extend it if your tools need more entries.
8. CI: `.github/workflows/ci.yml` already calls every root script with `pnpm run --if-present`. Remove its `detect` job, which only exists so CI passes before `package.json` does, and make sure the workflow passes with your files.

## Acceptance

- [ ] On a clean clone, `pnpm install --frozen-lockfile` works, and `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm format:check`, `pnpm cards:validate` and `pnpm db:seed` all exit 0 (there's nothing for them to do yet).
- [ ] The boundary rules actually catch violations. Check this in a scratch package that you don't commit:
  - `packages/core/src/x.ts` importing `react` or `node:fs`, or calling `Math.random()`, fails `pnpm lint`.
  - `packages/cards/src/x.ts` importing `node:fs` fails, and `packages/cards/src/node/x.ts` importing it passes.
  - `apps/web/src/ui/x.ts` importing `@chaosgrid/core` fails.
  - `apps/web/src/host/x.ts` importing `@chaosgrid/core` passes.

  Paste the commands and their output into the PR body.
- [ ] Nothing outside scope changed.

## Out of scope

- Any package under `packages/`, `apps/` or `tools/` (T-002, T-003, T-007 and later).
- Playwright (M3).
- CLAUDE.md and docs. If a convention there doesn't work in practice, send lead a `question`.

## Notes

- Make the internal-package pattern from CLAUDE.md work: no build step, `exports` pointing at `./src/index.ts`, `typecheck` = `tsc --noEmit`, `test` = `vitest run`, CLIs run with `tsx`. Every later task relies on it. Describe the final setup in the PR body.
- Check that `pnpm -r` with no packages and `pnpm --filter` with no match both exit 0, and say in the PR body how you checked.
