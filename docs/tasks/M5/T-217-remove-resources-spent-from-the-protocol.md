---
id: T-217
title: Remove resources.spent from the protocol
milestone: M5
depends_on: [T-200]
branch: agent/T-217-remove-resources-spent-from-the-protocol
model: sonnet
effort: medium
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - apps/web/src/**
  - apps/web/test/fixtures/planning/*.json
context:
  - docs/PROTOCOL.md
---

# T-217 — Remove resources.spent from the protocol

## Goal

`ResourcesSpentEvent` (`resources.spent`) is in the protocol, but core never emits it. Remove it so the protocol lists only events that exist.

## Interfaces

- `packages/protocol/src/event.ts`: `ResourcesSpentEvent`, its entry in the event union, and the doc comment on `ResourcesDetachedEvent` that cites it.
- `packages/protocol/src/visibility.ts`: the `'resources.spent'` case.
- `docs/PROTOCOL.md`: the event table row, the visibility list, and a new row in the version table.
- `PROTOCOL_VERSION` in `packages/protocol/src/version.ts`.

## Deliverables

1. The event, its schema, its visibility case, its tests and every reference in the web app are gone (`grep -rn "resources.spent\|ResourcesSpent"` finds nothing outside the version history).
2. `PROTOCOL_VERSION` bumped by one, with its row in PROTOCOL.md's version table.
3. The `ResourcesDetachedEvent` comment and PROTOCOL.md row no longer mention the removed event; they say where a consumed ability's resources go at Cleanup, as core does it.

## Acceptance

- [ ] `crew check` green
- [ ] The grep above is clean

## Out of scope

- Failing e2e tests (`replay.spec.ts`, `m4.spec.ts`): not part of this task.

## Notes

Start from the latest `main`: T-200 changes the same protocol files, so it merges first.
