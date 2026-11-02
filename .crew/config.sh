# crew settings for ChaosGrid (~/Documents/AI/tools/crew/README.md › Configuration). This is the plan
# repo: the paths below are paths here, while the gates, the install command and Redis run in the code
# repo, which `crew link` connects to this one. The git hooks and the Agent scope check read this file
# too: keep to plain NAME=value lines, with comments on their own.

CREW_PROJECT=ChaosGrid
CREW_PREFIX=cg

# Redis runs in Docker, from this repo's docker-compose.yml. crew runs this in the code repo.
CREW_REDIS_START='docker compose -f "$CREW_DOCS/docker-compose.yml" up -d redis'
CREW_REDIS_CONTAINER=chaosgrid-redis

CREW_TASKS=docs/tasks
CREW_PLAN=docs/PLAN.md
CREW_STATUS_FILE=README.md
CREW_NOTES=docs/agents/CREW.md

# The gates. soak isn't a default: workers run it when their scope touches the sim (docs/agents/CREW.md).
CREW_GATES="lint format typecheck test"
CREW_GATE_lint="pnpm lint"
CREW_GATE_format="pnpm format:check"
CREW_GATE_typecheck="pnpm typecheck"
CREW_GATE_test="pnpm test"
CREW_GATE_soak="pnpm test:soak"

# --frozen-lockfile never rewrites the lockfile; with nothing new, pnpm only checks.
CREW_LOCKFILE=pnpm-lock.yaml
CREW_INSTALL="pnpm install --frozen-lockfile"
CREW_REQUIRE="node pnpm docker"

# The docs are formatted by hand, so lead branches get no format check.
CREW_LEAD_FORMAT=

# Workers run on their card's model and effort, else these (D17).
CREW_MODEL=sonnet
CREW_EFFORT=medium
CREW_COMPACT=150000
