---
id: T-146
title: One stored playback speed
milestone: M5
depends_on: []
branch: agent/T-146-one-playback-speed
model: sonnet
effort: low
scope:
  - apps/web/src/replay/ReplayPage.tsx
  - apps/web/src/replay/replay.test.tsx
context:
  - docs/APPS.md#Web layout and ownership
---

# T-146 — One stored playback speed

## Goal

T-128's handoff noted that the playback controls might override the replay's own stored speed. They do. ReplayPage starts its playback at the speed under `chaosgrid.replay.speed`. Then PlaybackControls, which the replay renders, sets the speed under `chaosgrid.playback.speed` on mount whenever that key is set. And a speed chosen in a replay is written under both keys. So the replay's key only counts until the first speed is chosen anywhere. On 2026-11-02 the human chose one shared key.

After this task the replay reads and writes only the match's key, and starts at it.

## Interfaces

What exists (copied from the code on 2026-11-02):

```ts
// apps/web/src/match/playback/speed.ts
export const SPEED_KEY = 'chaosgrid.playback.speed'; // :3
export function readSpeed(): Speed | null; // :6: null when nothing valid is stored or storage is blocked
export function writeSpeed(speed: Speed): void; // :16

// apps/web/src/match/playback/PlaybackControls.tsx
//   :45-48 chooseSpeed: playback.setSpeed(speed); writeSpeed(speed)
//   :50-53 on mount: const stored = readSpeed(); if (stored !== null) playback.setSpeed(stored)
//   :64-67 the keys 1, 2 and 4 do the same as chooseSpeed

// apps/web/src/replay/ReplayPage.tsx
const SPEED_KEY = 'chaosgrid.replay.speed'; // :42
function readSpeed(): Speed; // :45-53: 2 or 4 when stored, else 1
function writeSpeed(speed: Speed); // :55-61
//   :206 session ??= { playback: play(replay, null, readSpeed()), stepIndex: null };
//   :246 useEffect(() => writeSpeed(speed), [speed]);
```

## Deliverables

1. **ReplayPage.** Delete its `SPEED_KEY`, `readSpeed`, `writeSpeed` and the effect at :246. The playback starts at `readSpeed() ?? 1`, with `readSpeed` imported from `../match/playback/speed`. PlaybackControls keeps restoring and writing the speed as it does.
2. **Tests** in `replay.test.tsx`: a replay opens at the speed stored under `chaosgrid.playback.speed`; a speed chosen in a replay is stored there; nothing is written under `chaosgrid.replay.speed`.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test replay playback` passes.
- [ ] `grep -rn "chaosgrid.replay.speed" apps/web/src | grep -v "\.test\."` prints nothing.

## Out of scope

- `speed.ts` and PlaybackControls: they already do the right thing.
- Moving a speed stored under the old key: it is forgotten once, and the next choice is kept.

## Notes

- Default: no migration of the old key. The stored speed is a convenience.
- T-120 and T-121 edit `ReplayPage.tsx` after this card, so T-120 waits for it.
