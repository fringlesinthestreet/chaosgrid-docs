---
id: T-024
title: Sim CLI and golden tests
milestone: M1
depends_on: [T-017, T-023]
branch: agent/T-024-sim-cli
scope:
  - tools/sim-cli/**
---

# T-024 — Sim CLI and golden tests

## Goal

Build a headless runner that plays many bot games, prints stats and saves event logs, plus golden tests that lock down the event stream. It's M1's demo, and the proof that the core holds up.

## Read first

- packages/core/README.md (the public API), the `packages/bots` README, docs/PROTOCOL.md
- docs/PLAN.md: M1 (its "Done when"), and M2 and M3 (which use these logs next)
- docs/DECISIONS.md › Working rules (golden files)

## Deliverables

1. `@chaosgrid/sim-cli` (Node) with a `sim` script. The root `pnpm sim` already calls it. Options:
   - `--games N` and `--seed S`
   - `--bots random,random,random,random`, for 2 to 4 seats
   - `--log <file>`: the first game's event log, as JSON
   - `--rounds <max>`
2. Decks for the bots, built from the sample cards and chosen with the seed. Each seat gets a legal-looking 40-card main deck (at most 2 copies of a card), 30 resources and a Leader.
3. The output: games played, wins per seat and per Leader, the average number of rounds, average points per round, and any game that threw an error, with its seed so it can be replayed.
4. Golden tests: two scripted rounds (fixed seed, decks and plans), with their event streams stored in `test/golden/`. `UPDATE_GOLDEN=1` rewrites them, and a PR that changes them says why in one line.
5. M1's done-when check as a test: 100 games between 4 RandomBots finish without errors.

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green
- [ ] `pnpm sim --games 100 --seed 1` finishes without errors and prints the stats
- [ ] `pnpm sim --games 1 --seed 1 --log run.json` writes an event log in which every entry parses as a protocol `Event`

## Out of scope

- Smarter bots and tournaments (M2), and the replay viewer (M3).
