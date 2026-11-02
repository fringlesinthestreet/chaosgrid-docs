#!/usr/bin/env bash
# Usage: scripts/dev.sh [up | seed | db | stop | status]
#
# Runs ChaosGrid on this machine the way the lead does: crew's Redis and a read-only DB viewer in
# Docker, then the game (the code repo's pnpm dev). It finds the code repo through crew link.
#
#   up (default)    start Redis and the DB viewer (seeding the DB first if it doesn't exist yet),
#                   then the API and the web app, until Ctrl+C
#   seed            rebuild the cards table from the card JSON (pnpm db:seed), then refresh the viewer
#   db              open the DB viewer, http://localhost:8080 (read-only)
#   stop            stop the DB viewer. Redis keeps running, because agents use it.
#   status          show the services and the DB file
#
# Ports: web 4000, API 5000. Workers use 4000+N and 5000+N (docs/agents/CREW.md), so they never clash.
set -euo pipefail

DOCS=$(cd "$(dirname "$0")/.." && pwd)
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
CODE=$(git -C "$DOCS" config --get crew.code) || die "this repo isn't linked to the code repo yet. In the code repo, run: crew link $DOCS"

VIEWER_URL=http://localhost:8080
DB_FILE="$CODE/.data/chaosgrid.db"
export CHAOSGRID_DATA="$CODE/.data" # what the DB viewer mounts (docker-compose.yml)
compose() { docker compose -f "$DOCS/docker-compose.yml" "$@"; }

need_docker() { docker info >/dev/null 2>&1 || die "Docker isn't running. Start Docker Desktop, or run only the game: pnpm dev, in $CODE"; }
redis_up() { [ "$(docker exec chaosgrid-redis redis-cli ping 2>/dev/null)" = PONG ]; }
viewer_running() { [ "$(docker inspect -f '{{.State.Running}}' chaosgrid-db-viewer 2>/dev/null)" = true ]; }
need_deps() { [ -d "$CODE/node_modules" ] || { echo "Installing dependencies (pnpm install)…"; pnpm -C "$CODE" install; }; }
seed_db() { need_deps; pnpm -C "$CODE" db:seed; }

start_viewer() {
  need_docker
  [ -f "$DB_FILE" ] || seed_db
  local out
  if ! out=$(compose up -d db-viewer 2>&1); then
    printf '%s\n' "$out" >&2
    die "couldn't start the DB viewer (is port 8080 taken?)"
  fi
  for _ in $(seq 1 20); do
    curl -fsS "$VIEWER_URL/-/versions.json" >/dev/null 2>&1 && { echo "DB viewer: $VIEWER_URL"; return 0; }
    sleep 0.5
  done
  die "the DB viewer didn't come up. See: docker compose -f $DOCS/docker-compose.yml logs db-viewer"
}

status() {
  local count=""
  if redis_up; then echo "Redis:      up (crew's board and messages)"; else echo "Redis:      down (crew setup starts it)"; fi
  if [ -f "$DB_FILE" ]; then
    if command -v sqlite3 >/dev/null 2>&1; then
      count=$(sqlite3 "$DB_FILE" 'SELECT count(*) FROM cards WHERE retired_at IS NULL' 2>/dev/null || true)
    fi
    echo "DB:         $DB_FILE${count:+, $count cards}"
  else
    echo "DB:         not created yet (scripts/dev.sh seed)"
  fi
  if viewer_running; then echo "DB viewer:  $VIEWER_URL"; else echo "DB viewer:  stopped (scripts/dev.sh db)"; fi
}

case "${1:-up}" in
  -h|--help) awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0" ;;
  up)
    need_docker
    redis_up || compose up -d redis >/dev/null
    start_viewer
    need_deps
    exec pnpm -C "$CODE" dev ;;
  seed)
    seed_db
    if viewer_running; then compose restart db-viewer >/dev/null 2>&1 && echo "Refreshed the DB viewer: $VIEWER_URL"; fi ;;
  db)
    start_viewer
    open "$VIEWER_URL" 2>/dev/null || true ;;
  stop)
    compose stop db-viewer >/dev/null 2>&1 || true
    echo "Stopped the DB viewer. Redis keeps running." ;;
  status) status ;;
  *) die "unknown command: $1 (see --help)" ;;
esac
