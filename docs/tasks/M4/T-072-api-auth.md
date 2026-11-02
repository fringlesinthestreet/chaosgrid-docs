---
id: T-072
title: API sign-up, login and sessions
milestone: M4
depends_on: [T-071]
branch: agent/T-072-api-auth
model: sonnet
effort: high
scope:
  - apps/api/**
context:
  - docs/APPS.md#Accounts
  - docs/APPS.md#HTTP API
  - packages/db/README.md#In code
---

# T-072 — API sign-up, login and sessions

## Goal

M4 has local accounts (D40, which keeps D27's rules). After this task the API signs players up, logs them in and out, and knows who is calling: a session cookie maps to a player, and every later route that needs login asks one helper for the player id. It also gives player `0`, the superadmin `admin` (T-070), its password from `CHAOSGRID_ADMIN_PASSWORD` each time it starts, and keeps the admin locked while that's unset, so no password is ever committed.

## Interfaces

What exists (copied from the code on 2026-10-28, plus T-069 to T-071):

```ts
// @chaosgrid/db (T-070)
export function createAccount(db, { username, passwordHash }, options?: { now?: Date }): AccountRow; // AccountError('usernameTaken')
// a sign-up gets the next id from 1 and the role 'player'; 'admin' is taken
export function findAccount(db, username): AccountRow | undefined;
export function createSession(db, { tokenHash, playerId, expiresAt }, options?): SessionRow;
export function findSession(db, tokenHash, options?: { now?: Date }): { session; account } | undefined;
export function deleteSession(db, tokenHash): boolean;
export const LOCKED_PASSWORD_HASH = '!'; // the admin's hash until a password is set; no hash equals it
export function setPasswordHash(db, playerId, passwordHash): boolean; // false when the player has no account
// openDb makes player 0's account { username: 'admin', passwordHash: LOCKED_PASSWORD_HASH,
//   role: 'superadmin' } when it's missing, and never changes it afterwards (D40)
// @chaosgrid/http (T-069): SignupRequest, LoginRequest, MeResponse (no role), ROUTES
// apps/api (T-071): buildApp({ db, now? }), ApiFailure(code, message), parseInput(schema, value)
// main.ts (T-071): openDb(), seedOnStart, buildApp, listen
```

What this task adds (`apps/api/src/auth/`):

```ts
// password.ts
/** `scrypt$16384$8$1$<salt>$<hash>`: a 16-byte random salt and a 64-byte key, both base64url. */
export function hashPassword(password: string): Promise<string>;
/** Recomputes with the stored parameters and compares with timingSafeEqual. */
export function verifyPassword(password: string, stored: string): Promise<boolean>;

// session.ts
export const SESSION_COOKIE = 'cg_session';
export const SESSION_DAYS = 30;
export function newToken(): string;              // 32 random bytes, base64url
export function hashToken(token: string): string; // SHA-256, hex

// player.ts
export interface Caller { id: number; username: string } // no role (D40)
/** The player behind the request's cookie, or ApiFailure('notLoggedIn'). */
export function requirePlayer(request: FastifyRequest): Caller;

// admin.ts
/** Sets the admin's password, or locks the admin when `password` is undefined or empty (D40). */
export function setAdminPassword(db: Db, password: string | undefined): Promise<void>;
// main.ts calls it with process.env.CHAOSGRID_ADMIN_PASSWORD after seedOnStart, before the listen
```

## Deliverables

1. **Password hashing** (`node:crypto`'s `scrypt` and `timingSafeEqual`), in the format above. `verifyPassword` returns false for a stored string it can't parse.
2. **Sessions.** `newToken` and `hashToken`. A new session expires `SESSION_DAYS` after `now`. The cookie: `HttpOnly`, `SameSite=Lax`, `Path=/`, `Max-Age` 30 days, not `Secure`. The DB stores only the hash.
3. **Routes** (`routes/auth.ts`, the paths from `ROUTES`):
   - `POST /api/auth/signup`: parse `SignupRequest`; hash; `createAccount`; `usernameTaken` becomes 409. Then create a session, set the cookie and answer 201 `MeResponse`.
   - `POST /api/auth/login`: parse `LoginRequest`. An unknown username and a wrong password both answer 401 `badCredentials`, and both run one scrypt (against a fixed dummy hash when the username is unknown), so the time doesn't tell them apart. The locked admin counts as unknown: when the stored hash is `LOCKED_PASSWORD_HASH`, check against the dummy hash and answer 401 `badCredentials`. Then a new session, the cookie, and 200 `MeResponse`.
   - `POST /api/auth/logout`: deletes the cookie's session if there is one, clears the cookie, 204. It works without a session too.
   - `GET /api/auth/me`: `requirePlayer`, then 200 `MeResponse`.
4. **`requirePlayer`.** Reads the cookie, `hashToken`, `findSession` with the app's `now`. No cookie, an unknown token and an expired session all throw `ApiFailure('notLoggedIn')`. Decorate the request or pass the db through the app's context, whichever keeps the deck routes (T-073) a one-line call.
5. **The admin's password** (`admin.ts`, D40). `setAdminPassword` with a non-empty password calls `setPasswordHash(db, 0, await hashPassword(password))`; with `undefined` or `''` it calls `setPasswordHash(db, 0, LOCKED_PASSWORD_HASH)`. `main.ts` calls it at every start and logs only whether the admin is set or locked, never the password.
6. **README.** The auth section: the cookie, the hash format, which routes need login, and the admin: `CHAOSGRID_ADMIN_PASSWORD` sets its password at each start, and it's locked while that's unset (D40). Add the variable to the README's env vars.
7. **Tests** (`inject`, an in-memory DB, a pinned `now`):
   - every 2xx body in these tests parses with its `@chaosgrid/http` schema (`MeResponse`)
   - sign-up answers 201 with `MeResponse` and a `Set-Cookie` with every attribute above; `me` with that cookie answers the same player
   - the first sign-up gets id 1
   - `me` without a cookie, and with a made-up token, answers 401 `notLoggedIn`
   - signing up `'Ana'` after `'ana'` answers 409 `usernameTaken`, and so does signing up `'admin'`
   - a 7-character password on sign-up answers 400 `invalidInput`; on login, 401 `badCredentials`
   - a 2-character username on sign-up answers 400 `invalidInput`; on login, 401 `badCredentials`
   - after `setAdminPassword(db, <a test password>)`, `admin` logs in with it, and `me` answers `{ id: 0, username: 'admin' }`
   - after `setAdminPassword(db, undefined)` and after `setAdminPassword(db, '')`, even following a call with a password, the stored hash is `LOCKED_PASSWORD_HASH`, and a login as `admin` answers 401 `badCredentials` with the same body as an unknown username
   - login with a wrong password and with an unknown username both answer 401 `badCredentials`, with the same body
   - after logout, the old cookie answers 401, and the response clears the cookie
   - with `now` moved 30 days on, the session answers 401
   - the stored password hash matches the format and isn't the password; the `sessions` table never holds the token
   - `verifyPassword` is true for the right password, false for a wrong one and for `'garbage'`

## Acceptance

- [ ] `crew check` green
- [ ] With the API on port 5072: `curl -si -X POST -H 'content-type: application/json' -d '{"username":"ana","password":"12345678"}' 127.0.0.1:5072/api/auth/signup` answers 201 with a `cg_session` cookie
- [ ] Started with `CHAOSGRID_ADMIN_PASSWORD` set to a value of your choice, a login as `admin` with that value answers 200 and `me` answers id `0`; restarted without it, the same login answers 401 `badCredentials`

## Out of scope

- Email, password reset, rate limits, CSRF tokens (D40, as D27: local accounts and nothing sends mail; `SameSite=Lax` and the JSON content type are enough for a local app).
- What the `superadmin` role allows: nothing in M4 (D40), so `Caller` and `MeResponse` don't carry it.
- Changing the admin's password from the web: only `CHAOSGRID_ADMIN_PASSWORD` sets it.
- Deleting expired sessions.
- The web's login pages (T-074).

## Notes

- Decision (lead, 2026-10-22): D27. Local accounts in M4; M6 decides what changes when the server is shared.
- Decision (human, 2026-10-28): D40, which supersedes D27 and keeps its rules. Player `0` is the account `admin`, role `superadmin`, which the DB makes (T-070). Its password is set from `CHAOSGRID_ADMIN_PASSWORD` each time the API starts, and it's locked while that's unset.
- Default: an unset or empty `CHAOSGRID_ADMIN_PASSWORD` sets the hash back to `LOCKED_PASSWORD_HASH`, so a password from an earlier start doesn't linger ("locked while that's unset").
- Default: any non-empty value is the admin's password as it is, even one `Password` would refuse: the human picks it on their own machine. Never write one into a file the repo tracks; the tests use a made-up value.
- Default: logging in while logged in makes a second session; the old cookie is replaced and its row stays until it expires.
- Default: the scrypt parameters are stored in the hash, so they can change later without breaking old accounts.
- Use `scrypt`'s async form: a sign-up shouldn't block the event loop for the other requests.
