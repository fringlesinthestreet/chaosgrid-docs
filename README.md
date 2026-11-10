# ChaosGrid plan

The private plan for ChaosGrid (github.com/fringlesinthestreet/chaosgrid): the milestones, the task cards, the workflow decisions, the changelog and the status. The code repo is shared, and keeps the code with the docs anyone working on it needs: the rules, the protocol, the decisions, the architecture, the conventions and the art (D53). crew (`~/Documents/AI/tools/crew`) reads this repo for the lead and the workers, from its `main`. Keep it private.

## Status

<!-- status:start (generated from git by crew status --update-readme; crew merged refreshes it, don't edit by hand) -->
- **Milestone:** M6 — Balance v2 · 11 of 19 tasks merged
- **Latest task completed:** [T-234](docs/tasks/M6/T-234-resources-as-cards-of-the-deck.md) Resources as cards of the deck (2026-11-10)
- **Next up:**
  - [T-235](docs/tasks/M6/T-235-core-resources-on-the-grid-and-the-round.md) "Core: resources on the grid and the round's mana"
  - [T-240](docs/tasks/M6/T-240-fix-the-round-2-preview-test-on-main.md) Fix the round 2 preview test and the e2e hand window clicks on main
<!-- status:end -->

## What's here

| Path | What |
| --- | --- |
| [docs/PLAN.md](docs/PLAN.md) | The milestones, M0 to M8 |
| [docs/tasks/](docs/tasks/README.md) | Task cards by milestone, ChaosGrid's planning rules and the board |
| [docs/CHANGELOG.md](docs/CHANGELOG.md) | How the plan, the decisions and the way we work changed |
| [docs/DECISIONS-HISTORY.md](docs/DECISIONS-HISTORY.md) | What the code repo's decisions said before, and why they changed (D79) |
| [docs/agents/CREW.md](docs/agents/CREW.md) | What crew's workers need to know about ChaosGrid |
| [.crew/](.crew/config.sh) | crew's settings, the code repo's lead paths, and the commits that only look like task merges |
| [scripts/dev.sh](scripts/dev.sh), [docker-compose.yml](docker-compose.yml) | ChaosGrid on this machine with Redis and the DB viewer |

Paths under `docs/` read the same from either repo: a card's `context:` entry that says `docs/PLAN.md` means this repo's file, and one this repo doesn't have, such as `docs/RULES.md`, the code repo's. Nothing in the code repo cites this repo (D73).

## How it changes

Only through lead branches, reviewed like code: `crew plan new <slug>` (or `crew card widen T-NNN <glob>` for a scope), then `crew plan ready <slug>`. The human runs `crew pr lead/<slug>`, squash-merges it, and runs `crew merged lead/<slug>`. The code repo's docs change the same way, on a lead branch there: `crew plan new <slug> --code`.

## Running ChaosGrid with Redis

`pnpm dev` in the code repo runs only the game. `scripts/dev.sh` (`--help`) runs it the way the lead does: crew's Redis and the read-only DB viewer (http://localhost:8080) in Docker, then the API and the web app. It finds the code repo through `crew link`.
