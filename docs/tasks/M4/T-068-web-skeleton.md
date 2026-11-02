---
id: T-068
title: Web skeleton and M4 root config
milestone: M4
depends_on: [T-069, T-092, T-103]
branch: agent/T-068-web-skeleton
model: opus
effort: medium
scope:
  - apps/web/**
  - eslint.config.js
  - .github/workflows/ci.yml
  - package.json
  - pnpm-workspace.yaml
context:
  - docs/tasks/M4/README.md#What M4 adds
  - docs/tasks/M4/README.md#Web layout and ownership
  - docs/tasks/M4/README.md#Routes
  - docs/tasks/M4/README.md#Ports and the e2e DB
  - docs/DECISIONS.md#Import boundaries
---

# T-068 — Web skeleton and M4 root config

## Goal

`apps/web` doesn't exist yet, and the root config doesn't know about M4's apps and package. After this task, `apps/web` is a Vite + React app with every M4 route showing a placeholder page, a typed API client and its test fixture, a theme, placeholder art (D39) and a Playwright smoke test. The root config is ready for every later M4 task: the catalog pins all of M4's dependencies, ESLint knows `@chaosgrid/http`, the web zones and the web's own import rules, and CI runs the browser tests. No later M4 task needs a root file.

## Interfaces

What exists (copied from the code on 2026-10-28):

```js
// eslint.config.js:18-35, one zone per package; `workspace` lists the @chaosgrid/* imports allowed,
// and `externals`, if set, the only npm packages (core, protocol and cards have ['zod'])
const WEB = ['protocol', 'cards', 'bots'];
{ dir: 'packages/db', workspace: ['cards', 'cards/node'] },
{ dir: 'apps/api', workspace: ['db', 'cards', 'cards/node', 'protocol'] },
{ dir: 'apps/web', except: ['apps/web/src/**'], workspace: WEB }, // config files, run by Node
{ dir: 'apps/web/src', except: ['apps/web/src/host/**'], workspace: WEB, browser: true },
{ dir: 'apps/web/src/host', workspace: [...WEB, 'core'], browser: true },
// DEV_FILES = ['**/*.test.*', 'test/**', '*.config.*'] run in Node with their zone's workspace list
```

```yaml
# pnpm-workspace.yaml: packages/*, apps/*, tools/*; catalog:
'@types/node': 22.20.5, tsx: 4.23.15, typescript: 6.0.3, vite: 8.3.4, vitest: 5.0.5, zod: 4.6.7
# root package.json scripts: lint, format, format:check, typecheck (pnpm -r --if-present),
# test (pnpm -r --if-present, then test:perf one package at a time), test:perf, test:soak,
# cards:validate, db:seed, sim, dev (bash scripts/dev.sh)   (test tiers: D31, T-092)
# .github/workflows/ci.yml: job `checks` (install --frozen-lockfile, Lint, Format, Typecheck,
# Test, Validate cards, Seed DB twice) and job `soak` (install, pnpm test:soak; timeout-minutes 45, T-103)
# scripts/dev.sh runs the `dev` script of every workspace package that has one
```

```ts
// @chaosgrid/http (T-069): ApiErrorBody = { error: { code: ErrorCode, message: string } }, ERROR_CODES,
// ROUTES (ROUTES.deck(id) encodes the id) and the response schemas MeResponse, CardsResponse,
// DeckListResponse and DeckDetail. Logout and DELETE /api/decks/:id answer 204 with no body (M4 README).
```

What this task adds:

```ts
// apps/web/src/api/client.ts (src/api/index.ts re-exports it)
export class ApiError extends Error {
  readonly status: number;                          // 0 when the request never got an answer
  readonly code: ErrorCode | 'network' | 'unexpected';
  // message: "Can't reach the server." (network), "Unexpected answer from the server." (unexpected),
  // else the error body's message
}
type Method = 'GET' | 'POST' | 'PUT' | 'DELETE';
/** Parses a 2xx body with `schema`: a body that fails it is `unexpected`. */
export function request<T>(method: Method, path: string, options: { body?: unknown; schema: z.ZodType<T> }): Promise<T>;
/** For the routes that answer 204 (logout, deleting a deck): any other 2xx is `unexpected`. */
export function request(method: Method, path: string, options?: { body?: unknown }): Promise<void>;
// Both: any other status throws ApiError with the error body's code and message; an error body
// that isn't JSON or isn't an ApiErrorBody is `unexpected`.

// apps/web/src/art/ (index.ts; D13, D39)
export interface SpriteSpec { color: string; url?: string } // url: real art, once T-082's manifest lists the key
/** `key` is a card id or a `ui.<name>` key (the card back, the Emblem, …). The placeholder color comes from its hash. */
export function spriteFor(key: string): SpriteSpec;
/** A card's art in the DOM, a `size` px square: the image at `url`, else a square in `color`. */
export function CardArt(props: { cardId: string; size: number }): JSX.Element;

// apps/web/src/theme/ (index.ts): Button, Panel, ErrorText, the CSS custom properties, the class cg-dimmed
/** The palette as numbers, for Pixi. The CSS custom properties (--cg-seat-0 … --cg-muted) hold the same colors. */
export const PALETTE: { seat: readonly [number, number, number, number]; chaos: number; warning: number; muted: number; … };

// apps/web/test/fixtures/api.ts (tests only)
export interface StubAnswer { status: number; body?: unknown }
export interface StubCall { method: string; path: string; body: unknown }
/** Stubs `fetch`. A key is `${method} ${path}` built from ROUTES (`GET ${ROUTES.cards}`); a request no key matches fails the test, naming it. */
export function stubApi(routes: Record<string, StubAnswer | ((body: unknown) => StubAnswer)>): { calls: StubCall[] };
// Body builders, each parsed with its @chaosgrid/http schema before it's returned:
// errorBody(code, message?), meBody(player), cardsBody(cards, retired?), deckListBody(decks), deckBody(deck).
// cardsBody takes the cards from the test, which can load them with @chaosgrid/cards/node.
```

## Deliverables

1. **Catalog.** Add every M4 dependency to the pnpm catalog with an exact version: the latest stable release that works with vite 8.3 and TypeScript 6.0. That is `react`, `react-dom`, `react-router`, `pixi.js`, `@vitejs/plugin-react`, `jsdom`, `@testing-library/react`, `@testing-library/user-event`, `@playwright/test`, `eslint-plugin-react-hooks`, `@types/react`, `@types/react-dom`, `fastify` and `@fastify/cookie`. Note in the PR any you couldn't pin, and why.
2. **ESLint.**
   - Add a zone for `packages/http`: workspace `['cards']`, externals `['zod']`, browser.
   - `WEB` becomes `['protocol', 'cards', 'http']`, and `'http'` joins `apps/api`'s list.
   - `@chaosgrid/bots` only in two zones: `apps/web/src/lobby` (`[...WEB, 'bots']`: the lobby lists the bots, T-084) and `apps/web/src/host` (`[...WEB, 'bots', 'core']`: only the host creates bots, T-080). The `apps/web/src` zone excepts both.
   - In `apps/web/src/**`, `no-restricted-globals` for `fetch` and `XMLHttpRequest`, except in `src/api/**`, `src/art/manifest.ts` (the art manifest, T-082) and tests.
   - In `apps/web/src/**` outside `src/host/**`, `src/match/session.ts` and tests, imports from the host folder are type imports only, so the session is the only code that starts a game. Use `@typescript-eslint/no-restricted-imports` with `allowTypeImports`: a second `no-restricted-imports` setting would replace the zone's.
   - Externals for the two Node zones, so neither picks up an npm package by accident: `packages/db` gets `['better-sqlite3', 'drizzle-orm', 'drizzle-kit']` (what it imports today) and `apps/api` gets `['fastify', '@fastify/cookie', 'zod']` (T-071's dependencies).
   - Turn on `eslint-plugin-react-hooks`' recommended rules for `apps/web/src/**/*.tsx`.
3. **Root scripts and CI.**
   - Root `package.json`: `"test:e2e": "pnpm --filter @chaosgrid/web run test:e2e"`.
   - CI, in the `checks` job: after Test, a step that runs `pnpm exec playwright install --with-deps chromium`, then a step "Browser tests" that runs `pnpm test:e2e`.
4. **The app.** `apps/web` (`@chaosgrid/web`, private):
   - Dependencies: `@chaosgrid/protocol`, `@chaosgrid/cards`, `@chaosgrid/bots`, `@chaosgrid/core` and `@chaosgrid/http` (`workspace:*`), plus `zod` (`catalog:`, for the client's schemas) and the catalog entries above.
   - Scripts: `dev` (`vite`), `build` (`vite build`), `typecheck`, `test` (`vitest run`) and `test:e2e` (`playwright test`).
   - `vite.config.ts`: the server port is `CHAOSGRID_WEB_PORT` (default 4000) with `strictPort`, and `/api` proxies to `http://127.0.0.1:${CHAOSGRID_API_PORT ?? 5000}`.
   - `vitest.config.ts`: jsdom, `src/**/*.test.{ts,tsx}` only, so Vitest never picks up `e2e/`.
   - `index.html` has the title "ChaosGrid".
   - `src/vite-env.d.ts` declares `VITE_CHAOSGRID_ART_URL?: string`, the base URL of the real art, which T-082 reads (D39). Nothing in the repo sets it.
5. **The folders.** Create every folder from the layout in [M4/README.md](README.md) › Web layout and ownership, each with its placeholder `index.tsx` and the names listed there. A placeholder page shows its name in a heading. `src/host/index.ts` exports nothing yet. `src/api/`, `src/art/` and `src/theme/` export their names from an `index.ts`, and other folders import only that.
6. **Router and layout** (`src/app/`):
   - React Router with the routes in › Routes. Every page except `/login`, `/signup` and `/replay` sits inside `RequireLogin`, and the whole app inside `AuthProvider`.
   - A layout with a nav bar (Cards, Decks, Play, Replay) and `AccountMenu` on the right.
   - An error boundary that shows the error's message and a link back to `/decks`.
7. **Theme** (`src/theme/`): the palette, a pixel font (a free one, committed, with its license file next to it), base CSS, and `Button`, `Panel` and `ErrorText` components that later tasks reuse. Keep it small.
   - The palette is one list: `PALETTE` (numbers, for Pixi) and the CSS custom properties come from it, so the two can't differ. Later tasks use `--cg-seat-0` to `--cg-seat-3`, `--cg-chaos`, `--cg-warning` and `--cg-muted`.
   - The class `cg-dimmed`, for what a later task dims (an illegal deck in the lobby, for one).
8. **Art** (`src/art/`, D13, D39): `spriteFor(key)` returns the key's placeholder, a color from its hash and no `url`; T-082 adds the manifest loader that fills `url`. `CardArt` draws a card's art in the DOM, and every page draws card art only through it.
9. **API client** (`src/api/`): `request()` and `ApiError` as above. It sends JSON with `credentials: 'same-origin'`.
10. **API fixture** (`test/fixtures/api.ts`): `stubApi` and the body builders above, a builder for every response schema in `@chaosgrid/http`. Every web test that stubs the API uses them, so a stub can't drift from the contract.
11. **Tests:**
    - unit: `request()` against a stubbed `fetch`: a 200 parsed by its schema; a 204 from the form without a schema; an error body becoming `ApiError` with its status, code and message; a failed fetch becoming `network` with status 0; and as `unexpected`, a 200 that fails its schema, a non-JSON error and an error body that isn't an `ApiErrorBody`. Each `ApiError` has the message above.
    - unit: `stubApi` answers by key, records each call and fails on a request no key matches; a builder given a body its schema rejects throws
    - unit: `spriteFor` gives a key the same color every time and no `url`; `CardArt` draws a `size` px square in that color
    - unit: the router renders each placeholder at its path
    - `e2e/smoke.spec.ts`: open `/replay` (no login needed): the document title is "ChaosGrid" and the console logs no errors
    - `playwright.config.ts`: Chromium only, the web server from the web package's own `dev` script on the port in › Ports and the e2e DB, `reuseExistingServer: false`

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm test:e2e` passes
- [ ] `CHAOSGRID_WEB_PORT=4068 pnpm --filter @chaosgrid/web dev` serves the app on port 4068, and `/decks` shows the Decks placeholder
- [ ] `pnpm --filter @chaosgrid/web build` succeeds
- [ ] By hand, not committed: `pnpm lint` flags a file in `src/cards/` that calls `fetch`, one that imports `@chaosgrid/bots` and one that imports a value from `../host`, and passes a type import from `../host`

## Out of scope

- Every real page: T-074 to T-089 replace the placeholders.
- `apps/api` and its dependencies' wiring (T-071), and the API server in Playwright (T-074).
- `packages/http` itself (T-069).
- Real art, the art manifest and its loader (T-082, D39).

## Notes

- This task holds every root file M4 needs (planning rule 4). If you find another root change a later M4 task will need, make it here and list it in the PR.
- Default: no CSS framework and no component library. Plain CSS modules or one CSS file per folder.
- Default: `request()` doesn't retry and doesn't redirect on 401. `RequireLogin` (T-074) handles login.
- Default: `CardArt` is decorative (`aria-hidden`); wherever it shows, the card's name shows too.
- Why `stubApi` is here: every feature's tests stub the same routes, so one fixture keeps them in step with `@chaosgrid/http`.
- Placeholders are the folder owners' to replace. Keep them a few lines long.
- T-103 changes ci.yml first: the soak job's `timeout-minutes` goes from 20 to 45. Rebase on it and keep its time limits.
