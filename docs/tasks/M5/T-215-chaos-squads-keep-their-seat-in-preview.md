---
id: T-215
title: Chaos squads keep their seat in the preview
milestone: M5
depends_on: [T-213]
branch: agent/T-215-chaos-squads-keep-their-seat-in-preview
model: sonnet
effort: high
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/core/src/view/**
  - packages/core/src/round/rebuild.ts
  - packages/core/src/round/rebuild.test.ts
  - packages/core/src/round/preview.test.ts
  - packages/bots/src/**/*.test.ts
  - apps/web/test/fixtures/planning/**
  - apps/web/src/**/*.test.ts
  - apps/web/src/**/*.test.tsx
  - packages/bots/src/*.test.ts
context:
  - docs/PROTOCOL.md#Snapshot
  - docs/PROTOCOL.md#Versioning
  - packages/core/README.md#Previews
---

# T-215 — Chaos squads keep their seat in the preview

## Goal

The planner bot looks ahead with core's `previewRound` (D49), which rebuilds the state from the seat's Plan snapshot. That rebuild seats each Chaos squad by pairing the card's `targets` with its `squads` by index, which holds only when every target gets one squad. Since D65 a unit card spawns its Chaos factor of squads for each target, so from round 2 on, the preview gives most Chaos squads the wrong seat or none. A squad's seat decides its targets among equally near enemies, and which seat's units a Raider Pack goes for. After this PR the snapshot says each Chaos squad's seat, and the preview seats every squad as the real round does. D76's per-player cap makes the counts per seat uneven, so no pairing could work.

## Interfaces

What exists on `main` (copied on 2026-11-07; grep the names, the lines move):

```ts
// packages/core/src/round/rebuild.ts, stateFromSnapshot's spawned squads
spawnedFor: squad.kind === 'chaos' ? chaosTarget(snapshot, squad.squad) : [],

/** The seat a Chaos squad spawned for: its card's targets pair with its squads, in order. */
function chaosTarget(snapshot: Snapshot, squad: string): Seat[] {
  for (const chaos of snapshot.chaos) {
    const index = chaos.squads.indexOf(squad);
    const seat = chaos.targets[index];
    if (index >= 0 && seat !== undefined) return [seat];
  }
  return [];
}
// snapshot.chaos[].targets has each seat once, in seat order; .squads has every squad by id.

// packages/core/src/view/units.ts, spawnedSquads: builds each SpawnedSquadSnapshot from the state's Squad,
// whose spawnedFor is [seat] for a Chaos squad (chaos/spawn.ts) and [] for a token.

// packages/protocol/src/snapshot.ts
export const SpawnedSquadSnapshot = z.strictObject({
  squad, owner, card, cardId, kind: z.enum(['chaos', 'token']), stats, keywords, level, pointsPerKill,
});
export const PROTOCOL_VERSION = 34; // packages/protocol/src/version.ts
```

After this PR:

```ts
// SpawnedSquadSnapshot gains, after `kind`:
/** The seats a Chaos squad spawned in front of, and attacks first: one for a Chaos squad, none for a token. */
spawnedFor: seatList(0, 4),
// stateFromSnapshot: spawnedFor: [...squad.spawnedFor], and chaosTarget goes.
export const PROTOCOL_VERSION = 35;
```

## Deliverables

1. **The protocol.** `SpawnedSquadSnapshot.spawnedFor` as above, required. `PROTOCOL_VERSION` 35, with a Versioning row in docs/PROTOCOL.md that says what changed and why, with no task id (D73). The `SpawnedSquadSnapshot` paragraph in docs/PROTOCOL.md lists the field.
2. **Core.** `spawnedSquads` fills `spawnedFor` from the squad. `stateFromSnapshot` copies it, and `chaosTarget` goes.
3. **The fixtures and tests** that build a `SpawnedSquadSnapshot` get the field: the bots' tests, the protocol's samples and tests, core's `view/snapshot.test.ts` and the web's two planning fixtures (`snapshot-actions.json`, `snapshot-zones.json`).
4. **A test that fails on `main` first**, in `rebuild.test.ts` or `preview.test.ts`: from a real Plan snapshot of a round where a Chaos unit card spawned two or more squads in front of one seat, `stateFromSnapshot` gives every Chaos squad the seat it has in the real state. Add a second case with a card sent against several seats.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check perf` green
- [ ] `crew check soak` green
- [ ] The test of deliverable 4 fails without the fix (say so in the PR) and passes with it
- [ ] `grep -rn "chaosTarget(" packages` finds nothing

## Out of scope

- How many squads spawn: T-214, in this wave, caps them (D76).
- The bots: `chaosAgainst` in `packages/bots/src/value.ts` finds a seat's Chaos by its chaosEdge, and can keep doing so. Reading `spawnedFor` there instead is an idea for the PR, not this card.
- The full soak: the lead runs it on `main` after this wave (D75).

## Notes

- The planner soak's win bar passes on seed 1 with a thin margin (33 > 29, since T-210), and a better preview was the stronger fix it named. This changes what the planner foresees: if `crew check soak` shows anything odd, say so in the PR.
- T-212 and T-200 come after this card and bump the protocol to 36 and 37.
