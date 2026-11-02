---
id: T-070
title: DB accounts, sessions and the card list
milestone: M4
depends_on: []
branch: agent/T-070-db-accounts
model: sonnet
effort: high
scope:
  - packages/db/src/schema.ts
  - packages/db/src/open.ts
  - packages/db/src/open.test.ts
  - packages/db/src/index.ts
  - packages/db/src/commands.ts
  - packages/db/src/accounts.ts
  - packages/db/src/accounts.test.ts
  - packages/db/src/cards.ts
  - packages/db/src/cards.test.ts
  - packages/db/src/commands.test.ts
  - packages/db/migrations/**
  - packages/db/README.md
context:
  - docs/tasks/M4/README.md#Accounts
  - packages/db/README.md#Tables (schema v2)
  - packages/db/README.md#Changing the schema
  - packages/db/README.md#Decks
---

# T-070 — DB accounts, sessions and the card list

## Goal

M4 adds local accounts (D40, which keeps D27's rules). The DB has a `players` table and owner columns from day one (D12), but nothing that stores a login. After this task, migration `0002_accounts` adds `accounts` and `sessions`, and `@chaosgrid/db` has the functions `apps/api` needs for sign-up, login and sessions, plus `listCards` for the card browser and `seedAll` for the API's start. Player `0` becomes the account `admin`, the superadmin, which the DB creates when it opens. It keeps every deck player `0` owns; sign-ups get ids from 1 and take no decks.

## Interfaces

What exists (copied from the code on 2026-10-28):

```ts
// packages/db/src/schema.ts
/** Until accounts arrive (M5), every player-owned row belongs to this player (D12). */
export const LOCAL_PLAYER_ID = 0;
export const players = sqliteTable('players', { id: integer PK, name: text, createdAt: text });
export const cards = sqliteTable('cards', { id, type, name, set, version, cost, costNumeric,
  data: json Card, contentHash, retiredAt: text | null, updatedAt });
export const decks = sqliteTable('decks', { id, owner: integer('owner_id') → players.id, name,
  description, leader, starterId, createdAt, updatedAt });
// Timestamps are ISO text, default (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')).

// packages/db/src/decks.ts
export function isStarterDeck(deck: Pick<DeckRow, 'id' | 'starterId'>): boolean; // id === starterId
export function listDecks(db: Db, owner: number): DeckRow[]; // starters included for owner 0

// packages/db/src/open.ts (index.ts exports openDb and schema, not migrateDb)
export const schema = { players, cards, decks, deckCards };
/** Applies the pending migrations, then adds player 0 if it's missing. Safe to repeat. */
export function migrateDb(db: Db): void; // inserts { id: LOCAL_PLAYER_ID, name: 'Local player' },
// onConflictDoNothing. openDb(file) runs it. Migrations: 0000_init, 0001_decks.

// packages/db/src/seed.ts, starters.ts (index.ts exports these, formatCounts and formatStarterCounts)
export interface SeedOptions { now?: Date } // the time to stamp on written rows
export function seedCards(db: Db, cards: readonly Card[], options?: SeedOptions): SeedCounts;
export function seedStarterDecks(db: Db, starters: readonly StarterDeck[], options?: SeedOptions): StarterSeedCounts;

// packages/db/src/commands.ts (the db:seed CLI runs it; index.ts doesn't export it)
/** `pnpm db:seed [--dir <path>] [--decks <path>]`: loads every card under `--dir` … and every
 * starter deck in `--decks` …, then makes the cards table match the cards (seedCards) and the
 * starter decks match the decks (seedStarterDecks), in one transaction. Given only `--dir`, it
 * seeds only the cards … */
export function seedCommand(args: readonly string[], options: CommandOptions & SeedOptions = {}): number;
// Its body: loadCards and loadStarterDecks (a bad file returns 1 before the DB opens), then
// db.transaction(() => { log formatCounts(seedCards(db, cards, { now })) and, with decks,
// formatStarterCounts(seedStarterDecks(db, starters, { now })) }, { behavior: 'immediate' }).
```

What this task adds:

```ts
// schema.ts
export const accounts = sqliteTable('accounts', {
  playerId: integer('player_id').primaryKey().references(() => players.id),
  username: text('username').notNull().unique(), // already lowercased by the API
  passwordHash: text('password_hash').notNull(), // opaque here: the API makes and checks it
  role: text('role', { enum: ['player', 'superadmin'] }).notNull().default('player'), // D40
  createdAt: text('created_at').notNull().default(now),
});
export const sessions = sqliteTable('sessions', {
  tokenHash: text('token_hash').primaryKey(), // SHA-256 hex of the cookie's token
  playerId: integer('player_id').notNull().references(() => players.id),
  createdAt: text('created_at').notNull().default(now),
  expiresAt: text('expires_at').notNull(),
}); // plus an index on player_id
export type AccountRow; export type SessionRow;
/** The admin's hash until the API sets one. No hash equals it, so nobody logs in with it (D40). */
export const LOCKED_PASSWORD_HASH = '!';

// accounts.ts
export const ACCOUNT_ERROR_CODES = ['usernameTaken'] as const;
export class AccountError extends Error { readonly code: AccountErrorCode }
export function createAccount(
  db: Db,
  input: { username: string; passwordHash: string },
  options?: { now?: Date },
): AccountRow; // throws AccountError('usernameTaken')
export function findAccount(db: Db, username: string): AccountRow | undefined;
export function createSession(
  db: Db,
  input: { tokenHash: string; playerId: number; expiresAt: Date },
  options?: { now?: Date },
): SessionRow;
export function findSession(
  db: Db,
  tokenHash: string,
  options?: { now?: Date },
): { session: SessionRow; account: AccountRow } | undefined; // undefined when expired
export function deleteSession(db: Db, tokenHash: string): boolean;
export function setPasswordHash(db: Db, playerId: number, passwordHash: string): boolean;
// false when the player has no account

// cards.ts
export function listCards(db: Db): { cards: Card[]; retired: string[] };
// cards: the non-retired rows' `data`, sorted by id; retired: retired ids, sorted

// commands.ts (index.ts exports these two, still not the commands)
export interface SeedAllCounts { cards: SeedCounts; starters?: StarterSeedCounts }
/** seedCards, then seedStarterDecks when `starters` is given, in one immediate transaction. */
export function seedAll(
  db: Db,
  input: { cards: readonly Card[]; starters?: readonly StarterDeck[] },
  options?: SeedOptions,
): SeedAllCounts; // throws what they throw, and then nothing is written

// open.ts: schema gains accounts and sessions. migrateDb, after the migrations, makes the admin (D40):
//   players { id: 0, name: 'admin' }: inserted, or renamed from a pre-M4 'Local player'
//   accounts { playerId: 0, username: 'admin', passwordHash: LOCKED_PASSWORD_HASH,
//     role: 'superadmin' }: inserted when missing, never changed afterwards
```

## Deliverables

1. **Schema and migration.** Add `accounts` (with `role`) and `sessions` to `schema.ts`, and to the `schema` object in `open.ts` (`{ players, cards, decks, deckCards }` today), so `Db`'s type knows them. Generate `0002_accounts` with `pnpm --filter @chaosgrid/db generate --name accounts`, read the SQL, and commit it with `meta/`. The migration only makes tables; the admin's rows come from `migrateDb` (3).
2. **`createAccount`.** In one transaction:
   - insert a `players` row named after the username, with the next free id. Player `0` always exists, so sign-ups get ids from 1
   - insert the `accounts` row with the role `player`; a username that exists, `admin` included, throws `AccountError('usernameTaken')` and writes nothing
   - move no decks: player `0`'s stay with the admin (D40)
3. **The admin** (D40). `migrateDb`, after the migrations, makes sure player `0` is named `admin` (insert it, or rename a pre-M4 `'Local player'`) and has the account `{ username: 'admin', passwordHash: LOCKED_PASSWORD_HASH, role: 'superadmin' }`, inserted when it's missing. It never changes an existing admin account, so a hash the API set (T-072) survives every open and every `db:seed`. `setPasswordHash` replaces one account's hash and returns whether a row changed.
4. **Sessions.** `findSession` returns undefined for an unknown token and for one whose `expiresAt` is at or before `now`. It doesn't delete expired rows. `deleteSession` returns whether a row was deleted.
5. **`listCards`.** One query over `cards`. A Chaos card is included (the browser shows it); a retired card isn't in `cards`, only in `retired`.
6. **`seedAll`.** In `commands.ts`: `seedCards`, then `seedStarterDecks` when `starters` is given, in one `db.transaction(…, { behavior: 'immediate' })`, and it returns both counts. `seedCommand` calls it and logs the same lines as today. `index.ts` exports `seedAll` and `SeedAllCounts`, so the API seeds on start the way `db:seed` does (T-071).
7. **Docs.**
   - Fix the two stale milestone mentions: `schema.ts`'s `LOCAL_PLAYER_ID` comment says "(M5)" and README.md line 56 says "(M6)". Both become: player `0` is the admin, the superadmin account the DB makes, which owns the starter decks (D40). The README's `decks.owner_id` row ("`0` for now (D12)") becomes: the owning account; `0`, the admin, for a starter deck (D40).
   - README: the two new tables in › Tables (bump it to schema v3), the account rules in one short section (player `0` is the admin, locked until the API sets its password; sign-ups get ids from 1 and take no decks), and the new functions in › In code.
8. **Tests** (`accounts.test.ts`, `cards.test.ts`, `open.test.ts`, on an in-memory DB):
   - the first two sign-ups get ids 1 and 2, each with a `players` row and the role `player`
   - a second `createAccount` with the same username throws `usernameTaken`, and the row counts don't change; on a new DB, so does the username `admin`
   - a sign-up takes no decks: player `0` keeps its starters and its other decks
   - `setPasswordHash` returns `true` for player `0`, whose account then has the new hash, and `false` for a player with no account
   - a session is found before `expiresAt` and not at it; `deleteSession` removes it and returns `false` the second time
   - `listCards` after seeding the sample cards returns them sorted; after a reseed without one card, that card is in `retired` only
   - `open.test.ts`: a new DB has player `0` named `admin` with the account `{ username: 'admin', passwordHash: LOCKED_PASSWORD_HASH, role: 'superadmin' }` (line 53's expectation becomes `admin`); a second `migrateDb` keeps one row of each, and a hash set with `setPasswordHash`; player `0` renamed to `'Local player'` is `admin` again after `migrateDb`; `accounts` and `sessions` join the `describe.each` list of tables whose migrations match the schema

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm db:migrate && pnpm db:seed && pnpm db:seed` work on a fresh DB file (`CHAOSGRID_DB=.data/t070.db`) and on your existing `.data/chaosgrid.db`, whose player `0` becomes `admin` and keeps its decks
- [ ] `src/open.test.ts` passes with the tests above: player `0` is `admin` with its superadmin account, two opens keep one row of each, and the migrations match the schema
- [ ] `src/commands.test.ts` passes (`seedCommand` now runs `seedAll`); its "2 migrations applied" expectations become 3

## Out of scope

- Password hashing, tokens and cookies: `apps/api` makes them (T-072). This package stores opaque strings, and knows one: `LOCKED_PASSWORD_HASH`, which no hash equals.
- Setting the admin's password from `CHAOSGRID_ADMIN_PASSWORD`: the API does it when it starts (T-072).
- What the `superadmin` role allows: nothing in M4 (D40).
- Changing `listDecks`, `getDeck`, `saveDeck` or `deleteDeck`. The API merges the starters into a player's list itself (T-073).
- Deleting expired sessions in bulk. Not needed for a local app.

## Notes

- This task is M4's only migration (planning rule 3), and it can run beside M3 because no M3 task adds a migration.
- T-061 (M3), whose scope had `packages/db/src/**/*.test.ts`, is merged, so this card can change `open.test.ts`. In wave 1, T-102 changes `seed.ts`, so `seedAll` goes in `commands.ts`, which no other card touches.
- Default: the username is unique as stored. The API lowercases it before calling (the `Username` schema, T-069), so this package doesn't lowercase again.
- Default: `players.name` is the username. M6 may add display names.
- Default: `LOCAL_PLAYER_ID` keeps its name, so its callers don't change; its comment says player `0` is the admin.
- Default: `migrateDb` makes the admin, not the migration's SQL, so a DB made before M4 gets it on its next open, as it gets player `0` today.
- Decision (human, 2026-10-28): D40. Player `0` is the account `admin`, role `superadmin`, which the DB creates when it opens; the API sets its password (T-072). It keeps every deck player `0` owns, and a sign-up takes none, which replaces D27's first-account takeover.
