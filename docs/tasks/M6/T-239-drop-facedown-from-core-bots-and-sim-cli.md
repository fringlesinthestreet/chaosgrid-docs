---
id: T-239
title: Drop faceDown from core, bots and sim-cli
milestone: M6
depends_on: []
branch: agent/T-239-drop-facedown-from-core-bots-and-sim-cli
model: sonnet
effort: medium
scope:
  - packages/core/**
  - packages/bots/**
  - tools/sim-cli/**
  - packages/protocol/src/**
context:
  - docs/tasks/M6/T-223-traps-out-of-the-protocol-and-the-web.md
---

# T-239 — Drop faceDown from core, bots and sim-cli

## Goal

`faceDown` is gone from the protocol (`permanent.destroyed`, `permanent.respawned`, `permanent.retired` events and `PermanentSnapshot`) and from every place that emits or fixtures it, since traps no longer exist.

## Interfaces

Core emits `faceDown: false` in view/board.ts, effects/health.ts, tokens.ts, round/cleanup.ts and banish.ts. Tests, `packages/bots/test/fixtures/snapshots.ts` and the sim-cli golden files carry it too. The protocol schemas are strict.

## Deliverables

1. Remove the `faceDown` fields from the protocol schemas and every emitter, test, fixture and golden file. Bump `PROTOCOL_VERSION`.

## Acceptance

- [ ] `crew check` green
- [ ] `grep -rn faceDown packages tools` finds nothing

## Out of scope

- The web app (T-223 already handled it).
