# ChaosGrid plan

The private plan for ChaosGrid (github.com/fringlesinthestreet/chaosgrid): the milestones, the task cards, the changelog and the status. The code repo is shared, and keeps the code with the docs anyone working on it needs: the rules, the protocol, the decisions, the architecture, the conventions and the art (D53). crew (`~/Documents/AI/tools/crew`) reads this repo for the lead and the workers, from its `main`. Keep it private.

## Status

<!-- status:start (generated from git by crew status --update-readme; crew merged refreshes it, don't edit by hand) -->
- **Milestone:** M5 — Balance pass · 0 of 22 tasks merged
- **Latest task completed:** [T-142](docs/tasks/M4/T-142-match-screen-follow-ups.md) Match screen follow-ups (2026-10-31)
- **Next up:**
  - [T-124](docs/tasks/M5/T-124-language-files.md) Language files and t()
  - [T-129](docs/tasks/M5/T-129-round-previews.md) Round previews for bots
  - [T-130](docs/tasks/M5/T-130-bots-aim.md) Bots aim for points
  - [T-131](docs/tasks/M5/T-131-balance-report.md) Balance report v2
<!-- status:end -->

## What's here

| Path | What |
| --- | --- |
| [docs/PLAN.md](docs/PLAN.md) | The milestones, M0 to M7 |
| [docs/tasks/](docs/tasks/README.md) | Task cards by milestone, ChaosGrid's planning rules and the board |
| [docs/CHANGELOG.md](docs/CHANGELOG.md) | How the plan, the decisions and the way we work changed |
| [docs/agents/CREW.md](docs/agents/CREW.md) | What crew's workers need to know about ChaosGrid |
| [.crew/](.crew/config.sh) | crew's settings, the code repo's lead paths, and the commits that only look like task merges |
| [scripts/dev.sh](scripts/dev.sh), [docker-compose.yml](docker-compose.yml) | ChaosGrid on this machine with Redis and the DB viewer |

Paths under `docs/` read the same from either repo: a card's `context:` entry or a code comment that says `docs/PLAN.md` means this repo's file, and one this repo doesn't have, such as `docs/RULES.md`, the code repo's.

## How it changes

Only through lead branches, reviewed like code: `crew plan new <slug>` (or `crew card widen T-NNN <glob>` for a scope), then `crew plan ready <slug>`. The human runs `crew pr lead/<slug>`, squash-merges it, and runs `crew merged lead/<slug>`. The code repo's docs change the same way, on a lead branch there: `crew plan new <slug> --code`.

## Running ChaosGrid with Redis

`pnpm dev` in the code repo runs only the game. `scripts/dev.sh` (`--help`) runs it the way the lead does: crew's Redis and the read-only DB viewer (http://localhost:8080) in Docker, then the API and the web app. It finds the code repo through `crew link`.
