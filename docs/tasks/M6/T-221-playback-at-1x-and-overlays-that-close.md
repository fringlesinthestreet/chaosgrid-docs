---
id: T-221
title: Playback at 1x and overlays that close
milestone: M6
depends_on: []
branch: agent/T-221-playback-at-1x-and-overlays-that-close
model: sonnet
effort: medium
scope:
  - apps/web/src/match/playback/**
  - apps/web/src/match/overlays/**
  - apps/web/src/match/session.ts
  - apps/web/src/match/session.test.ts
  - apps/web/src/replay/**
  - apps/web/README.md
context:
  - docs/APPS.md#The match
  - apps/web/README.md#How a match flows
---

# T-221 — Playback at 1x and overlays that close

## Goal

Every round's playback starts at 1×, whatever speed the last round used. The round summary and a Chaos banner reopened from its chip close by themselves after a few seconds instead of staying until clicked.

## Interfaces

On `main` (grep the names, the lines move):

- Speed lives in two places. `createPlayback` (`playback/playback.ts`) holds `let speed: Speed = options.speed ?? 1` and `setSpeed`, and the session makes one playback for the whole match. `playback/speed.ts` keeps `SPEED_KEY = 'chaosgrid.playback.speed'`, `readSpeed()` and `writeSpeed()`. `PlaybackControls.tsx` writes it on a click and on the 1/2/4 keys, and re-applies the stored value on mount; `MatchScreen` mounts it only while playing, so it remounts every round. `replay/ReplayPage.tsx` calls `play(replay, null, readSpeed() ?? 1)`.
- A new round starts in `session.ts`: `onEvents` → `playback.push(events)`, and `onEvents` already resets per-round state on `round.started`.
- `overlays/panels.tsx`: `RoundSummaryCard()` closes only through its Close button (`setClosed(summary.round)`). `RoundBanner()` is open while `state.revealing || reopened === model.round`; the Chaos chip reopens it after the pause, and a reopened banner stays until clicked. The banner of the Chaos pause closes when the pause ends (`session.ts`, from `settings.revealSeconds`, D41).

## Deliverables

1. **Speed.** Each round's live playback starts at 1×, and the player can still pick 2× or 4× during it. The remembered speed goes: `playback/speed.ts` and its uses in `PlaybackControls.tsx` and `ReplayPage.tsx`; nothing reads the old localStorage key any more. A replay starts at 1× and keeps the speed its viewer picks for the rest of the replay.
2. **Overlays.** `RoundSummaryCard` closes by itself `OVERLAY_SECONDS` (8) after it opens, as its Close button does, and so does a `RoundBanner` reopened from the chip. The pause's banner still closes when the pause ends. While the pointer is over an overlay its countdown waits, and it starts again from the full time when the pointer leaves. `OVERLAY_SECONDS` is a constant in `overlays/`.
3. **Tests:**
   - `playback.test.tsx`: after a round at 4×, the next round plays at 1×; a replay starts at 1×. Replace the tests of the remembered speed.
   - `overlays.test.tsx`, with fake timers: the summary closes after 8 s, stays while hovered and closes 8 s after the pointer leaves; a reopened banner closes after 8 s. Replace "keeps the summary of the round that ended through the next Plan".
   - `session.test.ts`'s reveal timing tests stay green.
4. `apps/web/README.md`, if it says the speed is remembered.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test playback overlays session replay` green

## Out of scope

- `MatchScreen.tsx` (T-220 edits it).
- Chaos off in the lobby (T-229).

## Notes

- Lead default: a rewatch of the last round doesn't reopen a summary that closed. If "keeps the live summary on screen during a rewatch" needs that, change the test and say so in the PR.
