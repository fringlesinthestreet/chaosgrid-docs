---
id: T-002
title: Protocol stubs
milestone: M0
depends_on: [T-001]
branch: agent/T-002-protocol-stubs
scope:
  - packages/protocol/**
---

# T-002 — Protocol stubs

## Goal

Create the contract between the UI and the core (D3) as Zod schemas: commands go in, events come out, and snapshots describe what one player can see. M0 only needs the skeleton and the conventions. M1 fills in the real messages.

## Read first

- docs/DECISIONS.md: D3, D7, and the `PROTOCOL_VERSION` rule under Working rules
- docs/PLAN.md: Runtime shape
- docs/RULES.md: Round structure (Reveal, Plan, Simulate, Cleanup)

## Deliverables

1. `@chaosgrid/protocol`, following the internal-package pattern in CLAUDE.md. Its only dependency is `zod` (`catalog:`).
2. `PROTOCOL_VERSION = 1`.
3. `Command`: a Zod discriminated union on `type`, with two stubs:
   - `plan.submit`: a seat and a loosely typed plan
   - `player.ready`: a seat
4. `Event`: a discriminated union on `type`, with four stubs:
   - `round.started`: the round number
   - `phase.changed`: the phase, one of `reveal`, `plan`, `simulate`, `cleanup`
   - `tick`: an integer tick
   - `game.ended`: the winning seats
5. `Snapshot`: `{ protocolVersion, round, phase, tick, players: [{ seat, points }] }`. Grids, hands and the rest arrive in M1.
6. TypeScript types derived with `z.infer`, all exported from a single `src/index.ts`.
7. `packages/protocol/README.md` covering:
   - what the protocol is for
   - naming: commands are `noun.verb`, events are past tense
   - how to add a message
   - when to bump `PROTOCOL_VERSION`
8. Tests:
   - each stub accepts a valid sample
   - an unknown `type` is rejected
   - a field with the wrong type is rejected
   - `PROTOCOL_VERSION` is a positive integer

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green
- [ ] `pnpm --filter @chaosgrid/protocol test` runs the new tests

## Out of scope

- `docs/PROTOCOL.md`, which M1 writes from the real types.
- Core or UI code, and card types (those belong to `@chaosgrid/cards`).

## Notes

- Seats are integers from 0 to 3. Seat 0 is the human in solo play (D12), but the protocol doesn't need to know that.
- Keep every payload plain JSON: no `Date`, `Map` or class instances. Events get saved as replay files.
