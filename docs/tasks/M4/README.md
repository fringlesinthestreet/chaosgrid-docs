# M4 — Shared conventions

Every M4 card links here. M4 adds two apps and one package, and builds them in parallel, so the layout, the owners and the shared names are fixed up front. A change to anything on this page goes through the lead (CLAUDE.md, hard rule 7).

## What M4 adds

- `packages/http` (`@chaosgrid/http`, T-069, D28): the HTTP contract between `apps/api` and `apps/web`. Zod schemas for every request and response body, the error codes and the route paths. It imports only `cards` and `zod`, and runs in the browser.
- `apps/api` (`@chaosgrid/api`, T-071 to T-073): a local Fastify server over `db`. Accounts and sessions (D40), the card list, and decks.
- `apps/web` (`@chaosgrid/web`, T-068 and later): Vite + React + PixiJS. Login and sign-up, the card browser, the deck list and editor, the lobby, the match and the replay viewer.
- In `core`: `checkPlan` and a `plan.checked` event (T-078, D29), the round end that settles what's in flight, with a `simulate.ending` event (T-101, D38), and the `emblem.placed`, `prize.placed` and `permanent.healed` events (T-090). In `protocol`: `extendsPlan`, so a seat's plan only grows (T-078, D37). In `cards`: `costTotal` and `offColors` (T-102). In `bots`: the bot registry, moved from sim-cli (T-079).

## Accounts (D40)

- Accounts are local (D40, which keeps D27's rules): a username and a password in SQLite, and a session cookie. There is no password reset and no rate limit. Nothing sends mail: a later flow that needs it (a password reset) starts with a mock.
- **Username:** 3 to 20 characters from `a-z`, `0-9` and `_`. The API lowercases it before it checks it, so `Ana` and `ana` are the same account.
- **Password:** 8 to 128 characters, any characters.
- **Password hash** (apps/api, `node:crypto`): `scrypt$16384$8$1$<salt>$<hash>`, with a 16-byte random salt and a 64-byte key, both base64url. Compare with `timingSafeEqual`.
- **Session:**
  - The cookie is `cg_session`: 32 random bytes in base64url, `HttpOnly`, `SameSite=Lax`, `Path=/`, `Max-Age` 30 days, and not `Secure` (the API serves plain HTTP on 127.0.0.1).
  - The DB stores the token's SHA-256 (hex), never the token.
  - An expired session counts as no session.
- **Player ids:** an account is a `players` row. Sign-ups get ids from 1.
- **The admin:** player `0` is the account `admin`, with the role `superadmin`, which the DB creates when it opens (T-070). Its password is set from `CHAOSGRID_ADMIN_PASSWORD` each time the API starts, and it's locked while that's unset, so no password is ever committed (T-072). A login as the locked admin answers `badCredentials`. In M4 the role grants no extra powers, so `MeResponse` doesn't carry it.
- **Starter decks** stay owned by player `0`, so the admin holds them. Every account sees them, and nobody can change or delete them, the admin too: the seed rewrites them from `packages/cards/decks`. A player plays one as it is, or copies it.
- **Decks made before M4** stay with player `0` too. A sign-up starts with no decks.
- **Seat 0:** in a solo match the human sits in seat 0, and bots fill seats 1 to 3 (D12's rule, kept by D40).

## HTTP API

The API listens on `127.0.0.1`, on `CHAOSGRID_API_PORT` (default `5000`). Bodies are JSON. The web reaches it through the Vite proxy, so the cookie is same-origin.

| Route | Login | Success | Body in → out (`@chaosgrid/http` names) |
| --- | --- | --- | --- |
| `POST /api/auth/signup` | no | 201, sets the cookie | `SignupRequest` → `MeResponse` |
| `POST /api/auth/login` | no | 200, sets the cookie | `LoginRequest` → `MeResponse` |
| `POST /api/auth/logout` | no | 204, clears the cookie | — |
| `GET /api/auth/me` | yes | 200 | → `MeResponse` |
| `GET /api/cards` | no | 200 | → `CardsResponse` |
| `GET /api/decks` | yes | 200 | → `DeckListResponse` |
| `POST /api/decks` | yes | 201 | `SaveDeckRequest` → `DeckDetail` |
| `GET /api/decks/:id` | yes | 200 | → `DeckDetail` |
| `PUT /api/decks/:id` | yes | 200 | `SaveDeckRequest` → `DeckDetail` |
| `DELETE /api/decks/:id` | yes | 204 | — |

Every error answers `ApiErrorBody`, `{ error: { code, message } }`. `message` is for people, `code` is for code:

| `code` | Status | When |
| --- | --- | --- |
| `invalidInput` | 400 | Fastify refuses the body (bad JSON, a content type it doesn't parse, too large), the body fails its schema, or `starterId` names no starter deck |
| `notLoggedIn` | 401 | a route that needs login has no valid session |
| `badCredentials` | 401 | login with an unknown username, a wrong password, or as the locked admin (one code for all three) |
| `usernameTaken` | 409 | sign-up with a username that exists |
| `notFound` | 404 | no route matches (`No route GET /api/x.`), no deck with that id, or a deck another player owns |
| `starterDeck` | 403 | `PUT` or `DELETE` on a starter deck, by anyone, the admin too (D40) |
| `unknownCard` | 400 | a saved deck names a card id the cards table doesn't have |
| `internal` | 500 | anything else (logged) |

Saving never refuses an illegal deck: it stores it and returns its `problems`. A deck is `legal` when it has no problems (a retired card is one). The API checks a deck with `checkDeck` over the same `cards` and `retired` that `GET /api/cards` answers, so its `problems` match the deck editor's (T-073, T-077).

## Web layout and ownership

`apps/web` is built by many tasks at once, so each folder has one owner. T-068 creates every folder below with a placeholder `index.tsx`, so the router compiles from day one. After T-068, a task edits only the folders its card lists.

```
apps/web/
  package.json, index.html, vite.config.ts, vitest.config.ts, tsconfig.json   T-068; T-109 adds the port check to test:e2e and e2e/*.test.ts to Vitest; T-123 adds art:pack, and art-pack/ to tsconfig.json and Vitest; T-124 adds intl-messageformat
  playwright.config.ts   T-068; T-074 adds the API server and the e2e DB; T-109 takes the ports from e2e/ports.ts
  e2e/
    smoke.spec.ts        T-068
    support/             T-074  signUp(page) helper
    auth.spec.ts         T-074
    replay.spec.ts       T-082
    m4.spec.ts           T-089; T-108 checks the round summary; then the playtest cards keep it passing, one after another (T-110, T-113, T-115 to T-118, T-142), then T-136
    ports.ts, preflight.ts, ports.test.ts   T-109  the port check test:e2e runs before Playwright
  art-pack/              T-123  the art pack: checks a folder of PNGs, writes what the bucket serves, serves it on this machine (D45)
  test/fixtures/api.ts   T-068  stubApi and the response builders
  test/fixtures/logs/    T-081  sim-cli event logs, the UI test fixtures; T-110 and T-112 update them to the protocol
  test/fixtures/session.ts   T-085  stubSession, for the panel and overlay tests; T-113 the Chaos pause, T-115 the card view, T-116 the Discard step, T-117 the grid on the battlefield, T-136 the HUD
  test/fixtures/planning/    T-086, then T-087, then T-100  Plan snapshots for the panel tests; then T-110, T-112, T-115 to T-118
  src/
    main.tsx             T-068
    app/                 T-068  router, layout, nav, error boundary; T-124 moves its text to en/app.json
    i18n/                T-124  t() and the language files (D50): en/<namespace>.json, one per folder, each edited only by that folder's cards
    theme/               T-068  palette, fonts, base CSS, a few shared components; T-108 moves the overlays' fade into theme.css; T-115 the tray and the card view; T-140 the card view's list; T-136 the HUD layout
    api/                 T-068  request(): fetch, parse with @chaosgrid/http, ApiError
    art/                 T-068  spriteFor, CardArt: each art key's placeholder (D13, D39); T-082 adds the manifest loader and ArtView; T-104 sizes the Emblem; T-119 the version 2 manifest, sprite strips, SpriteView and stills (D45, D46)
    auth/                T-074  AuthProvider, RequireLogin, AccountMenu, login and sign-up pages
    cards/               T-075  card browser, useCards, CardTile, CardDetail, filters; T-115 CardDetail's large size; T-127 sorting, groups, views and filter chips; T-134 bot-game stats
    decks/
      index.tsx, api.ts, list/   T-076  deck list, the deck API client; T-126 the tiles
      editor/                    T-077  deck editor; T-106 the unsaved-changes guard; T-125 problems and quick add
    lobby/               T-084; T-110 the point target's range; T-138 presets and bot levels
    host/                T-080  GameHost, MockTransport (the only folder that imports core); T-105 the timeouts in host.test.ts; T-110 the solo clocks; T-112 ignores discard.choose; T-116 the Discard step; T-141 the human seat's timeout in host.test.ts; T-135 the planner's simulator; T-137 bot styles
    match/
      model/             T-081  MatchModel: the match folded from events; T-110 and T-112 keep it on the protocol
      battlefield/       T-082  the Pixi scene; T-104 the Emblem on its cell and chaosBanner; T-111 picks what a click lands on; T-117 says where each grid is on screen; T-118 the targets on the battlefield; T-136 the free area under the HUD; then T-120 (animated units and permanents), T-121 (attack wind-ups, projectile sprites), T-122 (fx sprites, spell casts)
      playback/          T-083  timeline playback and its controls; T-113 the round clock in seconds; T-128 the timeline, seeking and rewatching; T-121 upcoming, the steps due next (D47)
      index.tsx, MatchScreen.tsx, session.ts   T-085  the page, the screen, the Ready bar and Plan timer; T-104 turns the Chaos banner off; then T-110 (MatchScreen.test.tsx), T-113 (the clocks, the Chaos pause), T-115 (the tray, the card view), T-116 (the Discard step), T-117 (the grid on the battlefield), T-118 (targets on the battlefield), T-140 (a squad's attached cards), T-136 (the HUD, D51), T-120 (the speed prop), T-121 (upcoming)
      CardView.tsx       T-115  the card view, in front of the screen; T-142 its Escape comes first; T-140 the list of a squad's attached cards; T-136 puts it in a HUD region
      planning/          T-086, then T-087, then T-100; then T-112 (no Discard button), T-115 (the tray), T-116 (choosing discards), T-117 (the grid on the battlefield), T-118 (targets on the battlefield), T-142 (Escape, the Zones panel, ticked discards), T-136 (the panel and the tray fold)
      overlays/          T-088  reveal, scoreboard, round log, game over; T-108 the round summary in live play; T-113 the round banner is the Chaos pause; T-128 lines that jump playback to their moment; T-136 Hud.tsx, the regions later panels plug into
    replay/              T-082  replay viewer page; T-083 adds its playback controls; T-120 and T-121 pass its battlefield the speed and upcoming
```

- **Placeholders.** Each feature folder's `index.tsx` exports the names the router and the layout use, from T-068 on: `auth` (`AuthProvider`, `RequireLogin`, `AccountMenu`, `LoginPage`, `SignupPage`), `cards` (`CardsPage`), `decks` (`DecksPage` and `DeckEditorPage`, which `decks/index.tsx` re-exports from `./list` and `./editor`), `lobby` (`LobbyPage`), `match` (`MatchPage`), `match/planning` (`PlanningPanel`), `match/overlays` (`Overlays`) and `replay` (`ReplayPage`). `PlanningPanel` and `Overlays` take no props; T-136 gives `Overlays` optional ones, so `<Overlays />` still renders. The other `match/` subfolders and `host/` export nothing until their owners fill them. T-068's `AuthProvider` and `RequireLogin` render their children, and its `AccountMenu` renders nothing. The folder's owner replaces them and keeps the names.
- **Feature API clients.** Each feature folder that calls the API has its own `api.ts` built on `src/api/`'s `request()`: `auth/api.ts` (T-074), `cards/api.ts` (T-075), `decks/api.ts` (T-076). Nobody calls `fetch` directly, except `src/art/manifest.ts`, which fetches the art manifest (T-082); T-068's lint rule enforces it.
- **Imports.** Other folders import a folder only through its `index.ts(x)`, as the lobby takes `useDecks` from `../decks` (T-084). Files inside one feature folder import each other directly (`decks/editor/` uses `decks/api.ts`, `match/planning/` uses `match/session.ts`). Only `host/` imports `core`, through its public entry, and only `lobby/` and `host/` import `bots`. Other folders import only types from `host/`, except `match/session.ts`, which starts the match (T-080, T-085). T-068's lint zones enforce the rules on `core`, `bots` and `host/`.
- **Art (D39).** Every art key (a card id, or `ui.<name>` for art no card owns) has a placeholder drawn in code in `src/art/`. Real art is files listed by a manifest under the base URL in `VITE_CHAOSGRID_ART_URL`: the web loads a file the first time it's drawn, and the browser caches it. An unset URL, an unlisted key or a failed load draws the placeholder. Only `src/art/` knows art URLs and file names (T-082). Pages draw art only through `CardArt` (the DOM) or `ArtView` (a Pixi sprite), so `art/` imports `pixi.js`. A unit and an Emblem are drawn 16×16 on their cell (the Emblem from T-104), the card back and the prize 32×32, and the status icons (`ui.fear`, `ui.shield`, `ui.extraLife`) and the token mark (`ui.token`) 6×6 (T-082). From T-119 on, D45 supersedes D39: art becomes animated sprites, stills and icons at 16 px a cell (D46), and attacks wind up ahead of their step (D47). [ART.md](../../ART.md) has the keys, sizes, animations and manifest.
- **Tests.** Vitest with jsdom and Testing Library, in `src/**/*.test.{ts,tsx}`. The environment is `test/jsdom-environment.ts` (T-068): jsdom with Vite's server-side transforms, since the client ones rewrite `new URL('…', import.meta.url)`, which `@chaosgrid/cards/node` uses to find the card files. A test that stubs the API uses `stubApi` and the response builders from `test/fixtures/api.ts` (T-068), so a stub can't drift from `@chaosgrid/http`. The art manifest's tests stub `fetch` with `vi.stubGlobal` (T-082). Playwright specs live in `e2e/*.spec.ts` and run Chromium only. `e2e/*.test.ts` are Vitest tests of the e2e tooling, run in Node (T-109), and so are the art pack's `art-pack/*.test.ts` (T-123).
- **Dependencies.** T-068 adds every M4 dependency to the pnpm catalog. A task that needs another one asks lead. jsdom stays on 29 (the catalog says why): a task asks lead to upgrade it only when a test can't pass without a newer one (2026-10-28).
- **Desktop first.** Pages work from 1024 px wide. Phones are out of scope for M4.

## Routes

| Path | Page | Login |
| --- | --- | --- |
| `/login`, `/signup` | `LoginPage`, `SignupPage` | no; a logged-in visitor goes to `/decks` |
| `/` | redirects to `/decks` | — |
| `/cards` | `CardsPage` | yes |
| `/decks` | `DecksPage` | yes |
| `/decks/new`, `/decks/:id` | `DeckEditorPage` | yes |
| `/play` | `LobbyPage` | yes |
| `/match` | `MatchPage`; the lobby passes the `MatchSetup` in router state | yes |
| `/replay` | `ReplayPage`; loads a log file, no API | no |

`RequireLogin` sends a visitor without a session to `/login?next=<path>`, and login goes back to `next`. Sign-up keeps `next` through the links between the two pages. After a logout the guest state carries `loggedOut: true`, and `RequireLogin` sends a plain `/login`. `AccountMenu` shows a guest a "Log in" link, as on `/replay` (T-074).

## Ports and the e2e DB

- `pnpm dev` (the human, main checkout): web on `4000`, API on `5000`.
- A worker that starts a server uses `4000 + N` for the web and `5000 + N` for the API (CLAUDE.md), through `CHAOSGRID_WEB_PORT` and `CHAOSGRID_API_PORT`. Vite reads both: its own port (`strictPort`) and where to proxy `/api`.
- Playwright uses `CHAOSGRID_WEB_PORT` and `CHAOSGRID_API_PORT` when they're set, else `4999` and `5999`. Its API runs on an in-memory DB (`CHAOSGRID_DB=:memory:`), so each run starts empty, and `reuseExistingServer` is off.
- `pnpm test:e2e` checks both ports before Playwright starts (T-109). When one is taken, it says what holds it, how to stop it and which free ports to use instead, and Playwright doesn't start.
- The API seeds the cards and the starter decks when it starts (`seedAll`, T-070), so an empty DB file works. It sets the admin's password from `CHAOSGRID_ADMIN_PASSWORD`, and the admin stays locked while that's unset (T-072, D40).

## The match

- **The host** (`src/host/`, T-080) owns the only core instance (PLAN.md › Runtime shape). It runs the bots, filters every event with `isVisibleTo` for the human's seat, and answers each `plan.submit` that extends the seat's last one (`extendsPlan`, D37) with that seat's `plan.checked`. When every human seat is ready it calls `playRound`. From T-116, when Cleanup leaves a seat over the hand limit, it holds the Discard step (D42) before the next `beginRound`. `start()` runs once: a second call throws. Commands arrive typed and aren't parsed again, and one that makes core throw stops the game through `onError`.
- **The transport** is what the UI holds. Every screen talks to the host only through it, so M6 can swap in a `WsTransport`:

  ```ts
  interface Transport {
    send(command: Command): void;
    onEvents(listener: (events: readonly Event[]) => void): () => void; // returns unsubscribe
    onSnapshot(listener: (snapshot: Snapshot) => void): () => void;
    /** The game stopped: the host threw (in M6, the connection dropped). Returns unsubscribe. */
    onError(listener: (error: Error) => void): () => void;
    close(): void;
  }
  ```

  `close()` doesn't count as `player.ready`: the host keeps waiting for that seat, so a solo match stops with its screen. Only an open transport counts as connected, so a new `createMockTransport` for the seat connects again (T-080).

- **The model** (`match/model/`, T-081) folds the event stream into what the screens draw: the board, scores, the round and phase, and the round log. The battlefield draws the model, never the snapshot: `<Battlefield model step viewer cards stepMs focusRequest />`, where a new `focusRequest` object moves the camera to its seat's grid (T-082). `chaosBanner={false}` turns off its "Chaos: …" banner: the match screen passes it, since T-088's round banner names the round's Chaos cards there, and the replay keeps the banner (T-104). The planning panel reads the seat's `Snapshot` (hand, resources, Leader, `AbilityUse`), which is what a bot plans from: the latest `plan.checked`'s snapshot when there is one, else the round's.
- **The session** (`match/session.ts`, T-085) is what the screen, the planning panel and the overlays use: `useSession()` returns `{ session, state }` and throws outside a `SessionContext` provider. `MatchScreen` provides one itself, so it works without `MatchPage` (which provides one too), and a test renders a panel or an overlay alone inside `<SessionContext.Provider value={session}>`. `submitPlan` and `ready` do nothing while `state.planning` is false. `stubSession` (`test/fixtures/session.ts`) records both in `sent` even then, so a test sees what a component tried to send. On a transport error the session stops taking the transport's events and the playback's updates, so the screen freezes where it was, under "The game stopped: <message>". The match lives in the page: `MatchPage` drops the setup from its history entry, so a reload of `/match` shows "No match running." instead of starting the match again.
- **Plan legality** comes from core, never from web code (D29). The panel sends the whole plan with `plan.submit` after each change, and draws the rejections from `plan.checked`. A utility spell's draws show up in the same reply. The panel disables a control only on a fact the snapshot states (`usable`, `unlocked`, `rested`, `attachedTo`, …), never on a rule it works out (affordability, room). The plan only grows (D37): the panel has no Undo and no Clear, and each `plan.submit` starts with the plan the seat sent last in this round. An action core refuses stays in the plan, marked, and the round skips it (`plan.rejected`).
- **The clocks** come from `GameSettings` (D41): `revealSeconds` of Chaos pause while the round banner shows, then `planSeconds` of Plan, then `player.ready`; and `discardSeconds` for the Discard step (D42). The solo host sets `planSeconds` and `discardSeconds` to 9999, and a clock with more than an hour left reads "No limit". The UI runs the clocks; the host has none (M6 adds server deadlines).
- **Playback** plays a round's timeline at 1×, 2× or 4× (1× is `TICKS_PER_SECOND` ticks a second, never a hard-coded 100), with Skip. The next round's events wait in a queue until playback ends. At an end condition the round settles first (D38, T-101): `simulate.ending` marks the tick the condition held, and the timeline plays on to `simulate.ended` while what's in flight lands and its triggers fire. The round clock freezes at `simulate.ending`.
