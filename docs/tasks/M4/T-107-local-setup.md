---
id: T-107
title: A guide to running ChaosGrid locally
milestone: M4
depends_on: [T-085]
branch: agent/T-107-local-setup
model: sonnet
effort: medium
scope:
  - README.md
  - scripts/dev.sh
  - scripts/README.md
context:
  - docs/APPS.md#Routes
  - docs/APPS.md#Ports and the e2e DB
---

# T-107 — A guide to running ChaosGrid locally

## Goal

Nothing tells a person how to run ChaosGrid on their machine. The tools exist: `pnpm dev` starts Redis and the DB viewer in Docker, then the API and the web app, and `pnpm dev api web` starts only the game. But the README has no setup section, `pnpm dev` stops when Docker isn't running without naming the Docker-free way, and `dev.sh` and `scripts/README.md` still say the apps "arrive in M4". The human asked for a guide (2026-10-29). After this task, the root README's "Run it locally" section takes someone from a fresh clone to a game against the bots in the browser, and shows how to run the API or the web app on its own.

## Interfaces

What exists (copied from the code on 2026-10-29):

```sh
# package.json (root): "packageManager": "pnpm@10.27.0", "engines": { "node": ">=22" }; .nvmrc: 22
#   "dev": "bash scripts/dev.sh"   # pnpm passes the extra words on: pnpm dev api web runs scripts/dev.sh api web
#   also "test", "test:e2e" (Playwright, apps/web), "sim" (tools/sim-cli), "db:seed", "cards:validate"

# scripts/dev.sh (117 lines: read it whole). Every command acts on $MAIN, the main checkout (lib.sh:10).
#   :2–15    the header, which --help prints (lib.sh:25 usage); :14 says "apps/api and apps/web, from M4 on"
#   :31      need_docker() dies "Docker isn't running. Start Docker Desktop, then try again." (start_viewer uses it too, :38)
#   :52–71   run_components(): :56–57 still say "apps/api and apps/web arrive in M4"
#   :73–89   status(): :88 says the same
#   :93–99   up, the default: need_jq, need_docker, Redis if it's down, start_viewer (seeds the DB first if the file
#            is missing), need_deps, run_components
#   :100–102 seed: db:seed, then restarts the viewer only if it's running, so it needs no Docker
#   :103–105 db: start_viewer, which needs Docker, then opens the viewer
#   :112–116 a component list (api, web): need_jq, need_deps, seeds the DB if the file is missing, run_components "$@".
#            No Docker.
# scripts/lib.sh: die() :20, note() :22, need_jq() :52 ("jq is needed: brew install jq")
# scripts/README.md › Running locally (:59–70): the sh block :61–67; :69 still says "None exists yet"

# apps/api (T-071, T-072): pnpm --filter @chaosgrid/api dev (tsx watch) | start (no watch)
#   listens on 127.0.0.1:$CHAOSGRID_API_PORT (default 5000) and prints "api listening on http://127.0.0.1:5000"
#   seeds the cards and the starter decks at every start ("<db file>: seeded"), so an empty DB file works
#   prints "admin: locked (CHAOSGRID_ADMIN_PASSWORD is not set)" until that's set; players never need the admin
#   an invalid card file: prints the problems and exits 1 before it listens
#   GET /api/cards needs no login
#   apps/api/README.md › Run it: its env vars (CHAOSGRID_API_PORT, CHAOSGRID_DB, CHAOSGRID_ADMIN_PASSWORD)
# packages/db/src/open.ts: the DB defaults to <repo root>/.data/chaosgrid.db; a relative CHAOSGRID_DB resolves
#   against the directory pnpm runs in; CHAOSGRID_DB=:memory: is a throwaway DB
# apps/web (T-068): pnpm --filter @chaosgrid/web dev (Vite)
#   serves on $CHAOSGRID_WEB_PORT (default 4000) with strictPort: a taken port stops it instead of moving it
#   proxies /api to 127.0.0.1:$CHAOSGRID_API_PORT (default 5000): give it the API's port when that isn't 5000
#   VITE_CHAOSGRID_ART_URL: the art manifest's URL (D39); unset, the app shows placeholder art
#   routes: /signup, /login; /decks, /cards and /play need a login; /replay doesn't (it plays a `pnpm sim --log` file)
#   the nav (app/Layout.tsx:5–10): Cards, Decks, Play, Replay; sign-up lands on /decks, with the starters listed
#   the lobby (/play) picks the player's first legal deck, else a starter, so a new account can play at once; Start opens /match
#   pnpm test:e2e: ports 4999 and 5999, CHAOSGRID_DB=:memory:; Chromium once: pnpm --filter @chaosgrid/web exec playwright install chromium
# tools/sim-cli: pnpm sim --games 1 --seed 1 --log run.json (the path is relative to where pnpm runs)
# README.md: "## Look and platform" :55, "## Docs" :59; the Status block :9–15 is written by scripts/merged.sh
```

What this task adds: the root README's "Run it locally" section, the Docker-free hint and the fixed texts in `dev.sh`, and the update to `scripts/README.md`.

## Deliverables

1. **The guide**: a `## Run it locally` section in the root README, between "Look and platform" and "Docs". About 60 lines at most: the README is also the pitch, so use tables and short lists rather than prose.
   - **What you need**: Node 22 or later (`nvm install` reads `.nvmrc`), pnpm 10 (`corepack enable` gives the version `packageManager` pins), git and jq. Docker Desktop only for `pnpm dev`'s Redis (the agents' message bus) and the DB viewer: the game needs neither.
   - **First run**: clone, `pnpm install`, `pnpm dev`. Then http://localhost:4000: sign up, then Play, with a starter deck until you build your own. The API is on http://127.0.0.1:5000, and the web app sends `/api` there. Ctrl+C stops both. Without Docker: `pnpm dev api web`.
   - **One part at a time**: `pnpm dev api` and `pnpm dev web`, or the packages' own scripts. `pnpm dev status` shows what's running. Link to apps/api/README.md › Run it and to scripts/README.md › Running locally.
   - **Settings**: the five env vars above, with their defaults and when you'd set each.
   - **The database**: where it lives, that the API creates and seeds it, `pnpm dev seed` to rebuild the cards from the JSON, deleting the file to start over (accounts and decks go too), and `pnpm dev db` for the read-only viewer on http://localhost:8080 (Docker).
   - **More**: `pnpm test` (the other gates: CLAUDE.md › Commands), `pnpm test:e2e` and its one-time Chromium install, and a bot game in the terminal (`pnpm sim …`) to watch in `/replay`.
   - **When something goes wrong**: a taken port, "Docker isn't running", the locked admin, and an invalid card file (`pnpm cards:validate` lists the problems).
   - A last line for working on the code: CLAUDE.md and scripts/README.md.
2. **`dev.sh`**:
   - `up` without Docker still stops before it starts anything, but its message names the Docker-free way: `pnpm dev api web`. `db` keeps today's message, since the viewer needs Docker.
   - :14, :56–57 and :88 stop saying the apps "arrive in M4". Finding no component with a dev script now means a broken checkout: say so plainly.
   - The header says that `pnpm dev <words>` runs `scripts/dev.sh <words>`, with `pnpm dev api web` as the example.
   - Nothing else changes: `up` still starts Redis and the viewer, and every command still acts on the main checkout.
3. **`scripts/README.md` › Running locally**: :69 names the components, `api` (port 5000) and `web` (port 4000); the sh block shows `pnpm dev api web` for a machine without Docker; and a line links to the root README's guide.

## Acceptance

- [ ] `crew check` green
- [ ] `bash -n scripts/dev.sh` passes, and `scripts/dev.sh --help` prints the new header
- [ ] `pnpm dev status` prints what `scripts/dev.sh status` prints, including `Components: api web`
- [ ] `grep -n "arrive in M4" scripts/dev.sh scripts/README.md` finds nothing
- [ ] With a failing `docker` first on the PATH, `up` stops with the new message and exit code 1. Write `.data/nodocker/docker` (`#!/bin/sh`, then `exit 1`), run `chmod +x .data/nodocker/docker`, then `PATH="$PWD/.data/nodocker:$PATH" scripts/dev.sh up; echo "exit $?"`. Check first that your `up` tests Docker before anything that starts or writes.
- [ ] The guide's servers, from your worktree on your ports, never through `dev.sh`: start `CHAOSGRID_API_PORT=5107 CHAOSGRID_DB=:memory: pnpm --filter @chaosgrid/api start` and `CHAOSGRID_WEB_PORT=4107 CHAOSGRID_API_PORT=5107 pnpm --filter @chaosgrid/web dev` in the background. `curl -fsS http://localhost:4107/api/cards | head -c 200` shows the cards' JSON, through the web app's proxy. Stop both after.
- [ ] `git diff main...HEAD -- README.md` changes nothing between `<!-- status:start` and `<!-- status:end -->`

## Out of scope

- `pnpm dev` without Docker: `up` means everything, Redis included, and `pnpm dev api web` is the game alone.
- `scripts/setup.sh`, the agent workflow, `CLAUDE.md` and `docs/agents/`.
- The root `package.json`: root files belong to dedicated tasks (planning rule 4), and its `dev` script already passes the words on.
- `apps/web/README.md` (T-089 links to your section) and `apps/api/README.md`: link to them, don't change them.
- Deploys, Docker images of the app, and Windows.

## Notes

- **Never run `scripts/dev.sh` or `pnpm dev` with `up`, `seed`, `db`, `stop` or a component list.** `dev.sh` always acts on the main checkout (`$MAIN`), where the human runs it on ports 4000 and 5000. Only `--help`, `status` and the failing-Docker `up` above are safe for you.
- The README's Status block (`<!-- status:start … -->` to `<!-- status:end -->`) is written by `scripts/merged.sh`. Never edit it. If a rebase conflicts there, take main's side.
- Default: the guide is a section of the root README, named "Run it locally" (T-089 links to `#run-it-locally`), not a new doc.
- Default: macOS first (`brew install jq`); say once that Linux works the same with its own package manager.
- Default: the settings table starts from apps/api/README.md › Run it and adds the web's two. Link there for the API's details rather than copy them.
- Write for someone who has never seen the repo: the commands in the order they'll type them, and what they'll see.
- The human tries `pnpm dev` with Docker stopped when they review.
