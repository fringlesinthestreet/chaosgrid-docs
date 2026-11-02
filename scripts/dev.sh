#!/usr/bin/env bash
# Usage: scripts/dev.sh [up | <component>... | seed | db | stop | status]
#
# Runs ChaosGrid on your machine, in the main checkout. `pnpm dev <words>` runs `scripts/dev.sh <words>`,
# so `pnpm dev api web` runs the game alone, without Docker.
#
#   up (default)    start Redis and the DB viewer (seeding the DB first if it doesn't exist yet),
#                   then run every component that has a dev script, until Ctrl+C
#   <component>...  run only these components, for example: scripts/dev.sh web api
#   seed            rebuild the cards table from the card JSON (pnpm db:seed), then refresh the viewer
#   db              open the DB viewer, http://localhost:8080 (read-only)
#   stop            stop the DB viewer. Redis keeps running, because agents use it.
#   status          show the services, the DB file and the components
#
# A component is a workspace package with a "dev" script: apps/api and apps/web.
# Local ports: web 4000, api 5000. Workers use 4000+N and 5000+N (CLAUDE.md), so they never clash.
. "$(dirname "$0")/lib.sh"

VIEWER_URL=http://localhost:8080
DB_FILE="$MAIN/.data/chaosgrid.db"
compose() { docker compose -f "$MAIN/docker-compose.yml" "$@"; }

# Every workspace package with a dev script, one per line: "<short name> <package name>".
components() {
  local f
  for f in "$MAIN"/packages/*/package.json "$MAIN"/apps/*/package.json "$MAIN"/tools/*/package.json; do
    [ -e "$f" ] || continue
    jq -r 'select(.scripts.dev != null) | (.name | sub("^@chaosgrid/"; "")) + " " + .name' "$f"
  done
}

need_docker() { docker info >/dev/null 2>&1 || die "Docker isn't running. Start Docker Desktop, then try again."; }
viewer_running() { [ "$(docker inspect -f '{{.State.Running}}' chaosgrid-db-viewer 2>/dev/null)" = true ]; }
need_deps() { [ -d "$MAIN/node_modules" ] || { note "Installing dependencies (pnpm install)…"; pnpm -C "$MAIN" install; }; }

seed_db() { need_deps; pnpm -C "$MAIN" db:seed; }

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
  die "the DB viewer didn't come up. See: docker compose logs db-viewer"
}

run_components() {  # run_components [short names...]: every component when none are given
  local all list="" name pkg
  all=$(components)
  if [ -z "$all" ]; then
    die "no workspace package has a dev script, but apps/api and apps/web should. This checkout looks broken: run pnpm install, then check apps/*/package.json."
  fi
  if [ $# -eq 0 ]; then
    note "Running: $(printf '%s\n' "$all" | awk '{ print $1 }' | tr '\n' ' ')(Ctrl+C stops them)"
    exec pnpm -C "$MAIN" -r --parallel --if-present run dev
  fi
  for name in "$@"; do
    pkg=$(printf '%s\n' "$all" | awk -v n="$name" '$1 == n { print $2 }')
    [ -n "$pkg" ] || die "no component named '$name'. Components with a dev script: $(printf '%s\n' "$all" | awk '{ print $1 }' | tr '\n' ' ')"
    list="$list --filter $pkg"
  done
  # shellcheck disable=SC2086 # $list is a series of "--filter <package>" words
  exec pnpm -C "$MAIN" --parallel $list run dev
}

status() {
  local count
  if redis_up; then echo "Redis:      up (agents' message bus)"; else echo "Redis:      down (scripts/setup.sh starts it)"; fi
  if [ -f "$DB_FILE" ]; then
    count=""
    if command -v sqlite3 >/dev/null 2>&1; then
      count=$(sqlite3 "$DB_FILE" 'SELECT count(*) FROM cards WHERE retired_at IS NULL' 2>/dev/null || true)
    fi
    echo "DB:         ${DB_FILE#"$MAIN"/}${count:+, $count cards}"
  else
    echo "DB:         not created yet (scripts/dev.sh seed)"
  fi
  if viewer_running; then echo "DB viewer:  $VIEWER_URL"; else echo "DB viewer:  stopped (scripts/dev.sh db)"; fi
  local all; all=$(components)
  if [ -n "$all" ]; then echo "Components: $(printf '%s\n' "$all" | awk '{ print $1 }' | tr '\n' ' ')"
  else echo "Components: none (no package has a dev script: this checkout looks broken)"; fi
}

case "${1:-up}" in
  -h|--help) usage ;;
  up)
    need_jq
    docker info >/dev/null 2>&1 || die "Docker isn't running. Start Docker Desktop, then try again. To run the game without Docker: pnpm dev api web"
    redis_up || (cd "$MAIN" && docker compose up -d redis >/dev/null)
    start_viewer
    need_deps
    run_components ;;
  seed)
    seed_db
    if viewer_running; then compose restart db-viewer >/dev/null 2>&1 && echo "Refreshed the DB viewer: $VIEWER_URL"; fi ;;
  db)
    start_viewer
    open "$VIEWER_URL" 2>/dev/null || true ;;
  stop)
    compose stop db-viewer >/dev/null 2>&1 || true
    echo "Stopped the DB viewer. Redis keeps running." ;;
  status)
    need_jq
    status ;;
  *)
    need_jq
    need_deps
    [ -f "$DB_FILE" ] || seed_db
    run_components "$@" ;;
esac
