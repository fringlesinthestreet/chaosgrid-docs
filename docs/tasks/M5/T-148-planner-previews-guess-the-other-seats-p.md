---
id: T-148
title: Planner previews guess the other seats' plans
milestone: M5
depends_on: [T-135]
branch: agent/T-148-planner-previews-guess-the-other-seats-p
model: opus
effort: high
scope:
  - packages/core/src/**
  - packages/protocol/src/**
  - packages/bots/src/**
  - packages/bots/README.md
  - tools/sim-cli/test/planner.soak.test.ts
  - tools/sim-cli/src/game.ts
  - tools/sim-cli/src/**/*.test.ts
  - apps/web/src/host/host.ts
  - apps/web/src/host/*.test.ts
  - packages/core/README.md
  - docs/PROTOCOL.md
  - packages/protocol/**
context:
  - docs/DECISIONS.md#D55
  - packages/core/README.md#Previews
  - docs/tasks/M5/T-135-planner-bot.md
---

# T-148 — Planner previews guess the other seats' plans

## Goal

The planner bot (T-135) wins about as often as greedy, because in a preview the other seats play nothing (D49, replaced by D55), so previews barely rank plans. After this PR a preview fills in the other seats with a guess of their plans, and the soak prints how many games the planner wins. Beating the average greedy seat moves to T-149.

## Interfaces

Core's `previewRound` (T-129) and the planner's `plan` (T-135). Any change to a protocol payload bumps `PROTOCOL_VERSION`. Changing a contract (previewRound's signature, a protocol message) needs the lead's OK: send a `question` first.

## Deliverables

1. Previews that play the other seats with a guessed plan (for example, the heuristic bots' plans on the snapshot).
2. The planner uses it, and its budget stays documented in the bots README.
3. The soak plays 40 games (planner vs 3 greedy, starter decks, target 30) and prints each seat's wins. It asserts only that the games finish, with no win threshold: T-149 adds it.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm test:soak` passes and prints the win shares
- [ ] `pnpm test:perf` passes

## Out of scope

- Changing greedy's plans or D33's soak.

## Notes

T-135's measurements: over 40 games the planner seat won 10–12 (fair share 10, pass needs 11+); greedy in that seat won 8–14. A bigger search budget didn't help (3×18000 ticks gave 11).
