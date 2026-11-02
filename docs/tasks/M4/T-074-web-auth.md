---
id: T-074
title: Web login, sign-up and the session
milestone: M4
depends_on: [T-068, T-069, T-072]
branch: agent/T-074-web-auth
model: sonnet
effort: high
scope:
  - apps/web/src/auth/**
  - apps/web/e2e/support/**
  - apps/web/e2e/auth.spec.ts
  - apps/web/playwright.config.ts
  - apps/web/src/app/app.test.tsx
  - apps/web/e2e/smoke.spec.ts
context:
  - docs/tasks/M4/README.md#Accounts
  - docs/tasks/M4/README.md#HTTP API
  - docs/tasks/M4/README.md#Web layout and ownership
  - docs/tasks/M4/README.md#Routes
  - docs/tasks/M4/README.md#Ports and the e2e DB
---

# T-074 — Web login, sign-up and the session

## Goal

Every M4 page but the replay viewer needs a logged-in player (D40). After this task the web has working login and sign-up pages, knows who is logged in, sends a visitor without a session to `/login` and back, and shows the username with a Log out button in the nav bar. Playwright runs the real API, so every later browser test can sign up a fresh player.

## Interfaces

What exists (T-068, T-069, T-072):

```ts
// apps/web/src/api/client.ts (T-068)
export class ApiError extends Error { status: number; code: ErrorCode | 'network' | 'unexpected' }
// message: "Can't reach the server." (network), "Unexpected answer from the server." (unexpected),
// else the error body's message
export function request<T>(method, path, options: { body?: unknown; schema: z.ZodType<T> }): Promise<T>;
export function request(method, path, options?: { body?: unknown }): Promise<void>; // a 204 answer
// apps/web/src/auth/index.tsx (T-068 placeholders): AuthProvider, RequireLogin, AccountMenu,
// LoginPage, SignupPage. The router and the layout already use these names.
// apps/web/test/fixtures/api.ts (T-068): stubApi(routes) stubs fetch, keyed by
// `${method} ${ROUTES.x}`, and records the calls

// @chaosgrid/http (T-069)
export const Username, Password, SignupRequest, LoginRequest, MeResponse, ROUTES;
// API (T-072): signup 201 / login 200 → MeResponse + cg_session cookie; logout 204; me 200 or 401
```

What this task adds:

```ts
// apps/web/src/auth/api.ts
export function signup(body: SignupRequest): Promise<MeResponse['player']>;
export function login(body: LoginRequest): Promise<MeResponse['player']>;
export function logout(): Promise<void>;
export function getMe(): Promise<MeResponse['player'] | null>; // null on 401 notLoggedIn

// apps/web/src/auth/
export type AuthState =
  | { status: 'loading' }
  | { status: 'guest' }
  | { status: 'player'; player: MeResponse['player'] }; // { id, username }: no role (D40)
export function useAuth(): AuthState & {
  login(body: LoginRequest): Promise<void>;
  signup(body: SignupRequest): Promise<void>;
  logout(): Promise<void>;
};

// apps/web/e2e/support/
/** Signs up a new player with a unique username through the page, and returns it. */
export function signUp(page: Page): Promise<{ username: string; password: string }>;
```

## Deliverables

1. **`auth/api.ts`** on `request()` and `ROUTES`, each body parsed with its `@chaosgrid/http` schema.
2. **`AuthProvider`** asks `getMe` once on mount and holds the `AuthState`. `login` and `signup` set it from the answer; `logout` calls the API, then sets `guest` even if the call failed.
3. **`RequireLogin`.** While `loading`, a short "Loading…" line. A `guest` goes to `/login?next=<path and query>`. A player sees the page.
4. **`LoginPage` and `SignupPage`** (`Panel`, `Button`, `ErrorText` from `src/theme/`):
   - Sign-up checks the fields with `Username` and `Password` before it calls the API, and shows the first problem under its field. Login only checks that both fields are filled.
   - API errors show as one line: `badCredentials` "Wrong username or password.", `usernameTaken` "That username is taken.", anything else `error.message` (the client words `network` and `unexpected`).
   - On success: go to `next` when it's a path on this site (starts with `/` but not `//`), else `/decks`.
   - A player who opens either page goes to `/decks`. Each page links to the other.
5. **`AccountMenu`:** the username and a Log out button. Logging out goes to `/login`.
6. **Playwright** (`playwright.config.ts`, `e2e/support/`):
   - a second `webServer`: the API, `pnpm --filter @chaosgrid/api start`, with `CHAOSGRID_API_PORT` (default `5999`) and `CHAOSGRID_DB=:memory:`, ready when its `ROUTES.cards` URL answers; the web server gets the same `CHAOSGRID_API_PORT`
   - `signUp(page)`: a username like `e2e_<8 random hex>`, so tests never collide
7. **Tests:**
   - unit (with `stubApi`): `RequireLogin` sends a guest to `/login?next=%2Fcards%3Fq%3D1` from `/cards?q=1`; login with a valid `next` lands there, and with `next=//evil.example` lands on `/decks`; sign-up with `'ab'` shows the username problem and makes no request; a 401 `badCredentials` shows its line; `AccountMenu` shows the username and logs out
   - `e2e/auth.spec.ts`: sign up, land on `/decks`, reload and still be logged in; log out, land on `/login`; log in again; a wrong password shows "Wrong username or password."; opening `/cards` logged out goes to `/login`, and logging in returns to `/cards`; signing up the same username twice shows "That username is taken."

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm test:e2e` passes (smoke and auth)
- [ ] With the API on 5074 and the web on 4074, signing up in a browser lands on `/decks` with the username in the nav bar

## Out of scope

- The pages behind login (T-075 to T-088): they keep their placeholders here.
- "Remember me", password change, account deletion (D40).
- Anything for the `superadmin` role: the web never sees it (D40).

## Notes

- Default: `getMe` is the only source of truth for the session: the web never reads the cookie (it's `HttpOnly`).
- The seeded `admin` (player `0`, D40) logs in through the same page once the API has `CHAOSGRID_ADMIN_PASSWORD`; nothing on the web treats it differently.
- Default: the e2e API uses an in-memory DB (`CHAOSGRID_DB=:memory:`; `openDb` supports it). Each run starts empty and seeded, with no file to delete, and Playwright stops the server at the end.
- The `next` check is the only open-redirect guard; keep it in one function with its own test.
