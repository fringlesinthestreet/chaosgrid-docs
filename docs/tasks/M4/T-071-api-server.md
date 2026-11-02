---
id: T-071
title: API server and the card list route
milestone: M4
depends_on: [T-068, T-069, T-070]
branch: agent/T-071-api-server
model: sonnet
effort: high
scope:
  - apps/api/**
context:
  - docs/APPS.md#HTTP API
  - docs/APPS.md#Ports and the e2e DB
  - docs/DECISIONS.md#Import boundaries
  - packages/db/README.md#In code
---

# T-071 — API server and the card list route

## Goal

`apps/api` doesn't exist yet. After this task it's a local Fastify server over `@chaosgrid/db`: it seeds the cards and the starter decks when it starts, as `db:seed` does (`seedAll`, T-070), answers `GET /api/cards`, and turns every failure into the `ApiErrorBody` of [M4/README.md](README.md) › HTTP API. The DB it opens already holds player `0`, the superadmin `admin` (T-070, D40). The auth routes (T-072) and the deck routes (T-073) plug into it, and T-072 sets the admin's password at start.

## Interfaces

What exists (copied from the code on 2026-10-28, plus T-069 and T-070):

```ts
// @chaosgrid/db
export function openDb(file?: string): Db; // default resolveDbPath(): CHAOSGRID_DB, else .data/chaosgrid.db
// openDb also makes player 0, the superadmin `admin`, locked until T-072 sets its password (T-070, D40)
export function seedAll(db: Db, input: { cards: readonly Card[]; starters?: readonly StarterDeck[] },
  options?: SeedOptions): SeedAllCounts; // T-070: seedCards, then seedStarterDecks, in one transaction
export interface SeedAllCounts { cards: SeedCounts; starters?: StarterSeedCounts } // T-070
export function formatCounts(counts: SeedCounts): string; // the summary db:seed prints
export function formatStarterCounts(counts: StarterSeedCounts): string;
export function listCards(db: Db): { cards: Card[]; retired: string[] }; // T-070
// @chaosgrid/cards/node
export const DEFAULT_CARDS_DIR, DEFAULT_DECKS_DIR;
export function loadCards(dir?: string): Card[];
export function loadStarterDecks(dir?: string): StarterDeck[];
// packages/db/src/commands.ts: seedCommand (db:seed, not exported) runs seedAll since T-070

// @chaosgrid/http (T-069)
export const ERROR_CODES; export type ErrorCode; export const ApiErrorBody, CardsResponse, ROUTES;
```

What this task adds (`apps/api/src/`):

```ts
// app.ts
export interface AppOptions {
  db: Db;
  /** The clock for sessions and timestamps. Tests pin it. */
  now?: () => Date;
}
/** The API without listening: routes, the cookie plugin and the error handler. Tests use inject(). */
export function buildApp(options: AppOptions): FastifyInstance;

// errors.ts
/** A failure a route answers on purpose: its status and ApiErrorBody come from the code. */
export class ApiFailure extends Error {
  constructor(code: ErrorCode, message: string);
  readonly code: ErrorCode;
  readonly status: number; // from the table in M4/README.md › HTTP API
}
/** Parses with `schema`, or throws ApiFailure('invalidInput') naming the first issue's path. */
export function parseInput<T>(schema: z.ZodType<T>, value: unknown): T;

// seed.ts
/** Loads packages/cards' cards and starter decks and runs seedAll (T-070), as db:seed does. */
export function seedOnStart(db: Db): SeedAllCounts; // main.ts logs them; a bad file throws

// main.ts: openDb(), seedOnStart, buildApp, listen on 127.0.0.1:CHAOSGRID_API_PORT (default 5000)
// (T-072 adds one step before the listen: the admin's password from CHAOSGRID_ADMIN_PASSWORD)
```

## Deliverables

1. **The package.** `apps/api` (`@chaosgrid/api`, private): dependencies `@chaosgrid/db`, `@chaosgrid/cards`, `@chaosgrid/http` (`workspace:*`), `fastify`, `@fastify/cookie` and `zod` from the catalog. Scripts: `dev` (`tsx watch src/main.ts`), `start` (`tsx src/main.ts`), `typecheck` and `test`.
2. **`buildApp`.**
   - Registers `@fastify/cookie` (T-072 uses it).
   - The error handler answers an `ApiFailure` with its status and `ApiErrorBody`, and Fastify's own body-parse errors (bad JSON, wrong content type) with `invalidInput`. Anything else is logged and answers 500 `internal` with a fixed message; the error's own text goes only to the log.
   - The not-found handler answers 404 `notFound` for every unknown path.
   - Routes are registered from one file per area: `routes/cards.ts` now, `routes/auth.ts` (T-072) and `routes/decks.ts` (T-073) later.
3. **`GET /api/cards`** (`ROUTES.cards`): `listCards(db)` as `CardsResponse`. No login.
4. **Start-up.** `main.ts` opens the DB (`CHAOSGRID_DB` is honoured by `openDb`, which also makes the admin, T-070), runs `seedOnStart`, and listens on `127.0.0.1` only. If seeding fails (an invalid card file), it prints the problems and exits with code 1. The listen address and the seed counts (`formatCounts`, `formatStarterCounts`) go to the log. Keep `main.ts` a short list of steps, so T-072 can add the admin's password before the listen.
5. **README.** How to run it (`pnpm --filter @chaosgrid/api dev`, the env vars `CHAOSGRID_API_PORT` and `CHAOSGRID_DB`; T-072 adds `CHAOSGRID_ADMIN_PASSWORD`), the file layout, and a pointer to `packages/http`'s README for the routes and bodies.
6. **Tests** (Vitest, `buildApp` with `openDb(':memory:')` and `inject`):
   - `GET /api/cards` after `seedOnStart` parses with `CardsResponse` and holds every sample card
   - a route that throws `ApiFailure('notFound', …)` answers 404 and the body parses with `ApiErrorBody` (register a test-only route on the instance)
   - a test-only route that throws a plain `Error('boom')` answers 500; the body parses with `ApiErrorBody`, its code is `internal`, and its message doesn't contain `boom`
   - malformed JSON on a POST answers 400 `invalidInput`
   - an unknown path answers 404 `notFound`
   - `seedOnStart` twice leaves the same row counts, and player `0`, the admin, owns every starter deck

## Acceptance

- [ ] `crew check` green
- [ ] `CHAOSGRID_API_PORT=5071 CHAOSGRID_DB=.data/t071.db pnpm --filter @chaosgrid/api start` starts on an empty DB file, and `curl -s 127.0.0.1:5071/api/cards` returns the cards

## Out of scope

- Auth and sessions, and the admin's password (T-072); deck routes (T-073).
- HTTPS, CORS and rate limits: the API is local and the web reaches it through Vite's proxy (D40).
- A production build. `tsx` runs it, like the other CLIs.

## Notes

- The ESLint zone for `apps/api` exists; T-068 adds `http` to its list.
- Default: no Fastify JSON-schema validation. Every body goes through `parseInput` with the `@chaosgrid/http` schema, so the contract has one source.
- Default: `now` defaults to `() => new Date()`. Pass it down to every db call that takes `{ now }`.
- Default: a 500's message is "Something went wrong on the server." The web shows the message of a code it has no line for (T-074), so that's what the user reads.
- `pnpm dev` (scripts/dev.sh) runs every workspace package's `dev` script, so the API joins it with no change to the script.
