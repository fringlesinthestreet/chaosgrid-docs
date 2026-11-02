---
id: T-104
title: The Emblem on its cell and the Chaos banner
milestone: M4
depends_on: [T-085]
branch: agent/T-104-emblem-banner
model: sonnet
effort: medium
scope:
  - apps/web/src/match/battlefield/**
  - apps/web/src/art/placeholders.ts
  - apps/web/src/art/art.test.tsx
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
context:
  - docs/tasks/M4/README.md#Web layout and ownership
  - docs/tasks/M4/README.md#The match
---

# T-104 — The Emblem on its cell and the Chaos banner

## Goal

Two answers to questions from the T-082 handoff (2026-10-28). An Emblem stands on one cell, but the battlefield draws it 32×32, over 2×2 cells: after this task it's 16×16 on its cell, like a unit. And the "Chaos: <name>" banner shows one name, so a second reveal replaces the first: after this task it lists every card revealed while it shows. The match screen turns it off, because T-088's round banner names the round's Chaos cards there; the replay keeps it.

## Interfaces

```ts
// apps/web/src/match/battlefield/Battlefield.tsx (T-082), as it is
export interface BattlefieldProps {
  model: MatchModel;
  step?: readonly Event[];
  viewer: Seat | null;
  cards: ReadonlyMap<string, Card>;
  stepMs?: number;
  focusRequest?: { seat: Seat | null };
}
// apps/web/src/match/battlefield/mount.ts (T-082): createBattlefield(element, options: BattlefieldOptions)
export interface BattlefieldOptions {
  viewer: Seat | null;
  cards: ReadonlyMap<string, Card>;
}
// scene.ts (T-082): BANNER_MS = 1200; on chaos.revealed it calls onBanner(`Chaos: ${name}`), where name is the
//   card's name, else its id; mount.ts shows the text in its [data-banner] div (role="status") for BANNER_MS.
// scene.ts: an Emblem's rect is `side` × `side` cells at where.at, with side = 2 for an Emblem, 1 for the rest.
// apps/web/src/art/placeholders.ts (T-068, T-082): ART_SIZE = { unit: 16, large: 32, icon: 8 };
//   artSize(key) returns 32 for ui.cardBack, ui.emblem and ui.prize. The ui.emblem placeholder's map is 16×16.
// apps/web/src/match/MatchScreen.tsx (T-085): renders <Battlefield model step viewer cards stepMs />

// What this task adds
interface BattlefieldProps {
  /** Shows the "Chaos: …" banner on chaos.revealed. Default true; the match screen passes false. */
  chaosBanner?: boolean;
}
interface BattlefieldOptions {
  chaosBanner?: boolean; // the same, default true
}
```

## Deliverables

1. **The Emblem on its cell.** The scene draws an Emblem on the one cell at its `where.at`, 16×16 at 16 px per cell, with its HP bar and HP number as now. `artSize('ui.emblem')` is 16, so `CardArt` and `ArtView` draw it 16×16 wherever it shows, and the doc comments on `ART_SIZE` and `artSize` say so. The card back and the prize stay 32×32.
2. **The banner lists every name.** A `chaos.revealed` while the banner shows adds its card's name to the list ("Chaos: Ember Imp, Tide Caller") and restarts the `BANNER_MS`. Several in one step go in one banner. Once the banner hides, the next reveal starts a new list. Whether the list lives in the scene or in `mount.ts` is your choice.
3. **`chaosBanner`.** `<Battlefield chaosBanner={false} />` and `createBattlefield(element, { …, chaosBanner: false })` show no banner. The default is true, so the replay doesn't change. Like `viewer` and `cards`, a new value may make a new battlefield.
4. **The match screen** passes `chaosBanner={false}` to its `<Battlefield>`. The replay passes nothing.
5. **Tests.**
   - scene: an Emblem's rect is one cell; two reveals in one step, and a second one while the banner shows, give one banner with both names; a reveal after the banner hid shows only its own.
   - mount: with `chaosBanner: false`, a `chaos.revealed` leaves `[data-banner]` hidden (or absent).
   - art: `artSize('ui.emblem')` is 16. The `CardArt` test that passes `size={32}` can stay.
   - MatchScreen: a `chaos.revealed` during playback shows no banner.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test -- battlefield art MatchScreen` passes

## Out of scope

- The round banner and the other overlays (T-088): they name the round's Chaos cards on the match screen.
- The replay page (`replay/`, T-083): it keeps the default.
- Other sizes: units, the card back, the prize and the icons stay as they are.

## Notes

- Default: the names in the banner are in the order of their reveals, joined with ", ".
- Until T-088 merges, the match screen shows no Chaos names at all. That's expected.
