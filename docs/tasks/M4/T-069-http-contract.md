---
id: T-069
title: HTTP contract package
milestone: M4
depends_on: []
branch: agent/T-069-http-contract
model: opus
effort: medium
scope:
  - packages/http/**
context:
  - docs/tasks/M4/README.md#What M4 adds
  - docs/tasks/M4/README.md#Accounts
  - docs/tasks/M4/README.md#HTTP API
  - docs/DECISIONS.md#Import boundaries
  - packages/cards/README.md#Deck rules
---

# T-069 — HTTP contract package

## Goal

`apps/api` and `apps/web` are built by different tasks at the same time, so the shape of every request and response has to be fixed first, in one place both can import (D28). After this task, `@chaosgrid/http` holds Zod schemas for every body in [M4/README.md](README.md) › HTTP API, the error codes and the route paths, and its README documents them.

## Interfaces

What exists (copied from the code on 2026-10-28):

```ts
// @chaosgrid/cards
export type Card = z.infer<typeof CardSchema>; // CardSchema: z.discriminatedUnion('type', [...])
export interface Deck { leader: string; main: readonly string[]; resources: readonly string[] }
export type DeckPile = keyof Deck;
export const DECK_PROBLEM_CODES = ['mainDeckSize', 'resourceDeckSize', 'tooManyCopies', 'wrongType',
  'leaderInMain', 'unknownCard', 'retiredCard', 'offColor'] as const;
export interface DeckProblem { code: DeckProblemCode; pile: DeckPile; cards: string[]; message: string }

// @chaosgrid/db (for reference: the API maps these rows to the bodies below)
// DeckRow: { id, owner, name, description: string | null, leader, starterId: string | null,
//   createdAt, updatedAt } (ISO strings); SavedDeck = DeckRow minus leader, plus { deck, problems, retired }
```

What this task adds (`packages/http/src/`):

```ts
export const ERROR_CODES = ['invalidInput', 'notLoggedIn', 'badCredentials', 'usernameTaken',
  'notFound', 'starterDeck', 'unknownCard', 'internal'] as const;
export type ErrorCode = (typeof ERROR_CODES)[number];
export const ApiErrorBody: z.ZodType<{ error: { code: ErrorCode; message: string } }>;

export const Username; // z.string(): trimmed, lowercased, then /^[a-z0-9_]{3,20}$/
export const Password; // z.string().min(8).max(128)
export const SignupRequest; // { username: Username, password: Password }
export const LoginRequest;  // { username: z.string().trim().toLowerCase(), password: z.string() }
export const MeResponse;    // { player: { id: number, username: string } }, no role (D40)

export const CardsResponse; // { cards: Card[] (CardSchema), retired: string[] }

export const DECK_NAME_MAX = 60;
export const DeckBody;      // { leader: string, main: string[], resources: string[] }
export const DeckProblemBody; // DeckProblem as a schema, code from DECK_PROBLEM_CODES
export const DeckSummary;   // { id: string, name: string, description: string | null, leader: string,
                            //   starter: boolean, legal: boolean, updatedAt: string }
export const DeckDetail;    // { id: string, name: string, description: string | null, starter: boolean,
                            //   starterId: string | null, deck: DeckBody,
                            //   problems: DeckProblemBody[], retired: string[], updatedAt: string }
export const DeckListResponse; // { decks: DeckSummary[] }
export const SaveDeckRequest;  // { name: 1 to DECK_NAME_MAX chars trimmed, description?: ≤ 500 chars | null,
                               //   starterId?: string | null, deck: DeckBody }

export const ROUTES: {
  signup: '/api/auth/signup'; login: '/api/auth/login'; logout: '/api/auth/logout';
  me: '/api/auth/me'; cards: '/api/cards'; decks: '/api/decks';
  deck: (id: string) => string; // `/api/decks/${encodeURIComponent(id)}`
};
// Each schema also exports its type under the same name (z.infer), as packages/protocol does.
```

## Deliverables

1. **The package.** `packages/http` (`@chaosgrid/http`, private), laid out like `packages/protocol`: `exports` points at `./src/index.ts`, scripts `typecheck` and `test`, dependencies `@chaosgrid/cards` (`workspace:*`) and `zod` (`catalog:`).
2. **Schemas.** Everything above, one file per area (`errors.ts`, `auth.ts`, `cards.ts`, `decks.ts`, `routes.ts`), all strict objects (`z.strictObject`), each with a one-line comment saying which route uses it.
3. **README.** What the package is (D28), the route table and the error table from [M4/README.md](README.md) › HTTP API with the schema names, and the rule that a body change is a contract change (CLAUDE.md, hard rule 7).
4. **Tests:**
   - `Username`: `' Ana_1 '` parses to `'ana_1'`; 2 and 21 characters, a space inside, `-` and `é` fail.
   - `Password`: 7 and 129 characters fail, 8 and 128 pass.
   - `LoginRequest`: `' Ana '` parses to `'ana'`, and a 2-character username or a 7-character password parses too.
   - `SaveDeckRequest`: an empty name fails, a name of `DECK_NAME_MAX` characters passes and one more fails, extra keys fail, a missing `starterId` parses.
   - `DeckDetail` parses a body built from a real `checkDeck` result, so `DeckProblemBody` matches `DeckProblem`. A type-level test (`expectTypeOf`) checks that `DeckProblem` is assignable to `DeckProblemBody`'s type and back.
   - `CardsResponse` parses every card from the sample cards (`loadCards` from `@chaosgrid/cards/node`, in the test only).
   - `ROUTES.deck('starter.ember aggro')` encodes the space.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/http test` passes

## Out of scope

- The ESLint zone for `packages/http`: T-068 adds it. Until then the package lints under the default rules, so import only `@chaosgrid/cards` and `zod`.
- The routes themselves (T-071 to T-073) and the web client (T-068).

## Notes

- Decision (lead, 2026-10-22): D28. `packages/protocol` is the game's contract (commands, events, snapshots). The HTTP bodies are a separate contract with a separate version story, so they get their own package rather than a corner of `protocol`.
- Default: `LoginRequest` checks neither rule. Its username is only trimmed and lowercased, and its password is any string, so a login with a short username or password answers `badCredentials`, not `invalidInput`, and says nothing about the rules.
- `internal` is the code of a 500: anything the API didn't expect, which it logs (T-071).
- `MeResponse` has no role: in M4 the `superadmin` role grants nothing, so the web never needs it (D40).
- `DECK_NAME_MAX` is exported so the web cuts and checks deck names with the API's limit (T-076, T-077).
- `SaveDeckRequest` stays a `z.strictObject`, never a union or an effect (`.transform`, `.pipe`): T-077 reads `SaveDeckRequest.shape.name`.
- Default: `CardsResponse.cards` uses `CardSchema` as it is. The web gets the full card data, the same JSON as `packages/cards/data`.
- Default: no version field in the bodies. The web and the API ship together.
