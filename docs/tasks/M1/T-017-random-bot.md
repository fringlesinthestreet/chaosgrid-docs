---
id: T-017
title: Random bot
milestone: M1
depends_on: [T-009]
branch: agent/T-017-random-bot
scope:
  - packages/bots/**
---

# T-017 — Random bot

## Goal

Write the first bot: given a Snapshot, it returns a random but mostly legal Plan. The sim CLI (T-024) uses it to play hundreds of games.

## Read first

- docs/PROTOCOL.md and packages/protocol/README.md
- docs/DECISIONS.md: import rule 3 (bots import only the protocol) and D8
- docs/RULES.md: Round structure (Plan)

## Deliverables

1. `@chaosgrid/bots`, following the internal-package pattern. It's browser-safe and depends only on `@chaosgrid/protocol`.
2. A `Bot` interface: `{ name, plan(snapshot): Plan }`.
3. `createRandomBot({ random })`. `random` is a seeded `() => number` that the caller passes in, because bots keep no randomness of their own (D8). The bot:
   - casts affordable cards from its hand onto free cells that fit their footprint, sometimes rotated
   - attaches spare resources to squads that have Charge
   - queues sorceries at random valid targets, from each hand card's `TargetSpec`
   - levels up when it can
   - sometimes moves its Leader
   - discards down to the hand limit
4. Tests:
   - every plan parses as a protocol `Plan`
   - the same seed and snapshot give the same plan
   - on sample snapshots, it only places cards on free cells and only spends what its pool can pay

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green

## Out of scope

- Smarter bots (M2).
- Checking plans against the full rules: core rejects bad actions with `plan.rejected`.
