---
id: T-178
title: Regenerate the web event-log fixtures
milestone: M5
depends_on: [T-170]
branch: agent/T-178-regenerate-the-web-event-log-fixtures
model: sonnet
effort: medium
scope:
  - apps/web/test/fixtures/logs/**
  - apps/web/src/**/*.test.ts
  - apps/web/src/**/*.test.tsx
context:
  - docs/tasks/M5/T-170-live-unit-stats-in-core-and-protocol.md
---

# T-178 — Regenerate the web event-log fixtures

## Goal

The web event-log fixtures in `apps/web/test/fixtures/logs` are stale since T-110 and lack `unit.statsChanged` (T-170 kept the old logs so its PR stays small). Regenerate them and fix the web tests that depend on them.

## Deliverables

1. Regenerated logs. The regenerated seed-1 game differs from event 10 on and places no squad before its first tick, and seed 3 no longer holds an Emblem: pick a seed that does.
2. Fixed expectations in the tests that failed with the new logs: scene, sprites, MatchScreen, replay, parseLog, log overlay and fixtures.test.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test` passes

## Out of scope

- Changes to core or protocol.
