---
id: T-098
title: Protocol and core READMEs catch up with M3
milestone: M3
depends_on: [T-097]
branch: agent/T-098-m3-docs-catch-up
model: haiku
effort: low
scope:
  - packages/protocol/README.md
  - packages/core/README.md
context:
  - packages/protocol/README.md#Files
  - packages/core/README.md#Module map
  - packages/core/README.md#State slices
  - packages/core/README.md#Shield, Extra life and Ward
---

# T-098 — Protocol and core READMEs catch up with M3

## Goal

The M3 tasks changed the protocol and core, and some lines in their READMEs now say what the code did before. Make those lines match the code. Docs only: no code changes.

## Interfaces

What's stale (copied from the READMEs on 2026-10-26; T-064 to T-097 may have fixed some of it, so check each line again):

```md
<!-- packages/protocol/README.md -->
:39 | `src/arena.ts` | `ArenaLayout`: where each seat's grid and strip and the central zone are in one round |
    <!-- the fields are `chaosGrid`, and per seat `origin`, `right`, `back` and `chaosEdge`: no strip -->
:40 | `src/event.ts` | `Event` and its 36 event types |
    <!-- 45 `type: z.literal(…)` in event.ts on 2026-10-26, before T-065's new events -->
:44 | `test/fixtures/samples.ts` | … two snapshots and an arena layout per seat count, … |
    <!-- every game has 4 seats: the samples are `defaultArena` and `smallArena` -->

<!-- packages/core/README.md › Module map -->
:45 | `movement/` | T-012 | pathing and steps per tick |
    <!-- movement/ also has push.ts, area.ts and flee.ts (fear, T-052) -->
<!-- core has no line on fear: its state is `effects.feared` (effects/state.ts:275), and feared
     units walk away through movement/flee.ts -->
```

## Deliverables

1. **packages/protocol/README.md**
   - The `src/arena.ts` row names what `ArenaLayout` holds now: where each seat's grid is and which way it faces, its Chaos edge, and the Chaos Grid.
   - The `src/event.ts` row gives the number of event types in `Event`'s union, counted from the code on your branch. Say in the PR how you counted.
   - The `samples.ts` row says the samples hold two arena layouts (`defaultArena`, `smallArena`), not one per seat count.
   - Any other line in the file that names a removed field or a seat count other than 4: fix it the same way, and list it in the PR.
2. **packages/core/README.md**
   - › Module map: the `movement/` row covers pushes and fleeing too, and the task column names T-052.
   - A short bullet on Fear where the other per-unit effects are described (› Shield, Extra life and Ward is the nearest, or a new › Fear section after it): `effects.feared` holds each feared unit's source cell and end tick, `movement/flee.ts` moves it away, and `unit.feared` / `unit.fearEnded` report it.
   - One line where the README describes combat or Simulate: the early end conditions wait while a queued death will fire an On death (T-097, RULES.md › End conditions), and the timer doesn't.
   - Any other line T-047 to T-097 made wrong that you find while reading the file: fix it and list it in the PR.

## Acceptance

- [ ] `crew check` is green (the format check covers Markdown).
- [ ] `git diff --name-only main...HEAD` prints only the two READMEs.
- [ ] Every number and name you changed matches the code on your branch: the PR lists each change with the file and line it comes from.

## Out of scope

- docs/PROTOCOL.md, RULES.md and the other docs.
- The bots and sim-cli READMEs (T-062 has them).
- Code and comments.

## Notes

- From the merged M3 tasks' open questions (2026-10-26): the protocol README's arena row, event count and samples row, and core README's fear and movement lines are stale.
- T-078 (M4) changes both READMEs too, so it waits for this task.
