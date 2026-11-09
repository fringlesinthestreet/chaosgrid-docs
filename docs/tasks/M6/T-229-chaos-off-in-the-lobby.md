---
id: T-229
title: Chaos off in the lobby
milestone: M6
depends_on: [T-221, T-224, T-227]
branch: agent/T-229-chaos-off-in-the-lobby
model: sonnet
effort: medium
scope:
  - packages/core/src/state/config.ts
  - packages/core/src/state/config.test.ts
  - packages/core/src/chaos/**
  - packages/core/README.md
  - apps/web/src/lobby/**
  - apps/web/src/host/host.ts
  - apps/web/src/host/host.test.ts
  - apps/web/src/match/overlays/**
  - apps/web/src/i18n/en/lobby.json
  - apps/web/src/i18n/en/match.json
  - tools/sim-cli/src/command.ts
  - tools/sim-cli/src/game.ts
  - tools/sim-cli/src/command.test.ts
  - tools/sim-cli/README.md
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Chaos deck and Emblems
  - docs/APPS.md#The match
  - packages/core/README.md#Config
---

# T-229 — Chaos off in the lobby

## Goal

A player can play without Chaos (D82): the lobby's options turn it off, and then Reveal draws nothing, Plan starts with no Chaos pause, and no banner shows the round's Chaos.

## Interfaces

On `main` (grep the names, the lines move):

- Core: `GameConfig` is core-only (`packages/core/src/state/config.ts`, `GameConfigSchema`, `makeConfig`); no command or protocol message carries it. `revealChaos(ctx)` (`chaos/reveal.ts`) runs at Reveal from `round/begin.ts`; `cleanupChaos` (`chaos/cleanup.ts`) sets the next round's Extra Chaos.
- Web: `LobbyChoice { deck, opponents, seed, pointTarget }` and the saved choice (`lobby/lobby.ts`), its "More options" in `lobby/index.tsx`; `buildSetup(...)` returns `MatchSetup { seats, seed, pointTarget }`; the host's constructor (`host/host.ts`) builds `config: { ...SOLO_CLOCKS, pointTarget? }` for core. The session skips the Chaos pause when `settings.revealSeconds` is 0 (`session.test.ts`: "never starts when revealSeconds is 0").
- The banner and the Chaos chip: `RoundBanner()` and the chip in `overlays/panels.tsx` and `overlays/Hud.tsx`.
- sim-cli: `--target` in `command.ts` reaches `playGame`'s `GameOptions` (`game.ts`), which builds the core config.

## Deliverables

1. **Core.** `chaos: z.boolean().default(true)` in `GameConfigSchema`. With `chaos: false`, `revealChaos` draws nothing and Cleanup never makes Extra Chaos due. The README's config table lists it.
2. **Lobby.** A "Chaos" on/off choice under the lobby's options, on by default and saved with the choice (a saved choice without it reads as on). `MatchSetup` gains `chaos?: boolean`, and with `chaos: false` the host passes `{ chaos: false, revealSeconds: 0 }` to core.
3. **Overlays.** In a round that revealed no Chaos, neither the round banner nor the Chaos chip shows.
4. **sim-cli.** `--no-chaos` plays with `chaos: false`; the README lists it.
5. **Tests:** core, a game with `chaos: false` has no `chaos.revealed` and no Chaos squad in 6 rounds; lobby, the choice is saved and builds `chaos: false`; host, the config has `chaos: false` and `revealSeconds: 0`; overlays, no banner or chip without Chaos; sim-cli, `--no-chaos` parses.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check perf` green
- [ ] `crew check soak` green

## Out of scope

- The protocol: `GameSettings` doesn't change, so the golden streams and the recorded logs don't either.

## Notes

- Cards that name Chaos or Emblems (Seeks Emblems) just find none; no card changes.
- The bots plan from the snapshot, which then holds no Chaos.
