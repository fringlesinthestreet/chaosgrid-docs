---
id: T-086
title: Planning panel, the grid and placement
milestone: M4
depends_on: [T-085]
branch: agent/T-086-planning-placement
model: sonnet
effort: high
scope:
  - apps/web/src/match/planning/**
  - apps/web/test/fixtures/planning/**
context:
  - docs/tasks/M4/README.md#The match
  - docs/PROTOCOL.md#Plans
  - docs/PROTOCOL.md#Coordinates
  - docs/PROTOCOL.md#Planning
  - docs/PROTOCOL.md#`HandCard`
  - docs/PROTOCOL.md#`SquadSnapshot`
---

# T-086 — Planning panel, the grid and placement

## Goal

The player plans here. After this task the Plan phase shows the seat's grid, hand, Leader and resource pool, and the player places units and the Leader: pick a card, then a cell, with a footprint preview. Each change sends the whole plan, and core's answer (`plan.checked`, D29) redraws the panel and marks the actions it would refuse. Spells, permanents, abilities, level-ups, attachments and discards come next (T-087), on this panel.

## Interfaces

What exists (T-075, T-085, and the protocol):

```ts
// apps/web/src/match/session.ts (T-085)
export function useSession(): { session: MatchSession; state: SessionState };
// state: snapshot (the round's), checked (the latest plan.checked), checking, planning; session.cards: Map by card id
// session.submitPlan(plan: Plan); MatchScreen owns the Ready bar and the Plan timer
// apps/web/test/fixtures/session.ts (T-085): stubSession(state, cards) → session + sent + setState
// apps/web/src/cards (T-075): CardTile, CardDetail
// apps/web/src/art (T-068, T-082): CardArt({ cardId, size }), a card's art in the DOM; the panel reads no sprite itself
// apps/web/src/theme (T-068): the class cg-dimmed, the seat colors --cg-seat-0 … --cg-seat-3
// @chaosgrid/protocol: Plan, PlanAction, Snapshot, HandCard, LeaderCard, PoolResource,
//   SquadSnapshot, PermanentSnapshot, PrizeSnapshot, PlanRejection, RejectReason, Cell, Size, Seat, SquadId, CardInstanceId
//   extendsPlan(previous, next) (T-078): next starts with previous's actions, in order (D37)
// A grid is Snapshot.arena.cols × .rows cells (30 × 30 today; MAX_GRID_SIZE, 64, is only the schema's bound).
// Snapshot.prizes: one per seat, { permanent, seat, cell, size: [2, 2], hp, maxHp, alive }; its cells can't be built on.
// apps/web/src/match/planning/index.tsx (T-068 placeholder): PlanningPanel, no props
```

What this task adds (`apps/web/src/match/planning/`):

```ts
// draft.ts (pure, no React)
export interface Draft { round: number; actions: readonly PlanAction[] }
export function emptyDraft(round: number): Draft;
export function pushAction(draft: Draft, action: PlanAction): Draft; // adds at the end: a plan only grows (D37)
/** What to plan from: the latest plan.checked's snapshot, else the round's. */
export function planView(state: SessionState): Snapshot | null;
/** The cells a footprint covers, anchored at its lowest col and row; cells off the grid included. */
export function footprint(cell: Cell, size: Size, rotated: boolean): Cell[];
/** What stands on each cell of a seat's grid, [row][col], sized from view.arena: squads, free-standing permanents and the prize. */
export function gridContents(view: Snapshot, seat: Seat): GridCell[][]; // GridCell { squad?: SquadSnapshot; permanent?: PermanentSnapshot; prize?: PrizeSnapshot }
export const REJECT_TEXT: Record<RejectReason, string>; // 'noRoom' → "No room there", …
/** One line of the plan list: "Place Flame Lancer at col 3, row 0". `lookup` gives a card's name, else the line uses its cardId. */
export function describeAction(action: PlanAction, lookup: (card: CardInstanceId) => string | undefined): string;

// PlanContext.tsx
export type Selection =
  | { kind: 'castUnit'; card: CardInstanceId; size: Size; rotated: boolean }
  | { kind: 'castLeader'; size: Size; rotated: boolean }
  | { kind: 'moveLeader'; size: Size; rotated: boolean }; // T-087 adds kinds
export interface PlanControls {
  draft: Draft;
  view: Snapshot;                                  // planView
  push(action: PlanAction): void;                  // adds at the end and submits the whole plan
  selection: Selection | null;
  select(selection: Selection | null): void;
  inspected: SquadId | null;                       // the squad shown in SquadPanel
  inspect(squad: SquadId | null): void;
}
export function usePlan(): PlanControls;

// PlanGrid.tsx: one seat's grid (view.arena.cols × rows), reused by T-087's target picker
export function PlanGrid(props: {
  view: Snapshot; seat: Seat;
  /** The cells to outline for the hovered (or focused) cell: a footprint here; T-087 adds a row and an area. */
  preview?(hovered: Cell): readonly Cell[];
  onCell?(cell: Cell): void;
  onSquad?(squad: SquadSnapshot): void;
}): JSX.Element;

// SquadPanel.tsx: one of the seat's squads, under the grid; T-087 adds its actions
export function SquadPanel(props: { squad: SquadSnapshot }): JSX.Element;

// index.tsx
export function PlanningPanel(): JSX.Element;      // still no props
```

## Deliverables

1. **The panel.** The seat's grid (`PlanGrid`) on the left. On the right, top to bottom: the Leader while it waits in the command zone, the hand, the resource pool (what each gives; rested ones dimmed with `cg-dimmed`; attached ones marked), and the plan list. Everything comes from `planView`, so a placed card leaves the hand and the resources that paid it show rested. Clicking a card shows its `CardDetail` (from `session.cards`).
2. **`PlanGrid`.** Row 0 (the front row, facing the Chaos Grid) at the top and col 0 at the left, as the battlefield draws the viewer's grid at the bottom. Each cell is a button labelled "col <c>, row <r>". A squad is one block over its footprint, in its owner's color (`--cg-seat-<seat>`), with its `CardArt`, card name, level and a Leader marker; free-standing permanents likewise, the seat's own face-down traps as a card back. The prize is one 2×2 block with its HP (`cg-dimmed` while `alive` is false); its cells can still be clicked, and core rejects a footprint over them. The preview outlines the cells `preview` gives for the hovered (or focused) cell; cells off the grid aren't drawn.
3. **Placing.**
   - A unit card's "Place", or the Leader's "Place Leader", selects it. Hovering the grid shows the footprint. R (or a Rotate button) turns it. Escape, or the same button again, cancels.
   - A click on a cell pushes `castUnit { card, cell, rotated }` or `castLeader { cell, rotated }` and clears the selection.
   - Clicking one of the seat's squads shows it in the `SquadPanel` under the grid: its card, level, Durability (none for a Leader) and attached resources. The Leader's has Move, which selects Move: a cell pushes `moveLeader { cell }`. The Leader keeps its rotation, so the preview can't be rotated. T-087 adds the panel's other actions.
   - The keyboard works too: Tab to a cell, Enter places.
4. **Sending.** `push` adds the action at the end of the draft and calls `session.submitPlan(draft.actions)`. A plan only grows during Plan (D37): there is no Undo and no Clear. While `state.checking`, the panel's buttons are disabled. The draft starts empty in each round (keyed by `snapshot.round`).
5. **The plan list.** One numbered line per action (`describeAction`). An action in `checked.rejected` is struck through with `REJECT_TEXT[reason]`: it stays in the plan, and the round skips it (D37). When any are rejected: "N actions will be skipped" above the list.
6. **Fixture** (`apps/web/test/fixtures/planning/`): `snapshot.json`, a seat-0 Plan `Snapshot` with the Leader in the command zone, a hand with two unit cards (one 1×1, one 2×1), unrested resources, a squad of another seat, the four prizes, and the 130 × 130 arena. Build it by hand or from a seeded game, and check it with the protocol's `Snapshot` schema in the tests. A `README.md` says what it holds. T-087 adds to it.
7. **Tests:**
   - `draft.ts`: `pushAction` adds at the end and keeps the actions before it; `footprint` of a 2×1 at col 29 (one cell off a 30-wide grid) and rotated; `gridContents` of a 2×2 squad, rotated and not, sized from `view.arena`, with the prize on its four cells; `REJECT_TEXT` has a text for every `RejectReason.options` entry; `planView` prefers `checked`
   - the panel on `stubSession` with the fixture:
     - the hand and the Leader show; Place Leader, then col 7 row 0, sends `plan.submit` with `[castLeader { cell: {col: 7, row: 0}, rotated: false }]`
     - R before the click sends `rotated: true`; Escape cancels and sends nothing
     - a `checked` whose snapshot has the Leader on the grid: the Leader leaves the command zone and its block is on the grid; clicking it, then Move, then a cell, sends a `moveLeader` after the `castLeader`
     - a `checked` with a rejection at index 1: that line is struck through with its reason, and "1 action will be skipped" shows
     - each `plan.submit` starts with the one before it (`extendsPlan`), and the panel has no Undo or Clear button (D37)
     - while `checking`, Place is disabled
   - with a real session (`startSoloMatch`, the real cards and starter decks from `@chaosgrid/cards/node`, as in T-085's session tests): placing the Leader gets core's `plan.checked`, and the panel shows either the Leader on the grid or the rejection core gave

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test -- planning` passes
- [ ] With the API on 5086 and the web on 4086: start a match, place the Leader and a unit, Ready: the battlefield shows both when the round plays

## Out of scope

- Every other plan action and every target (T-087).
- Drag and drop: click, then click.
- Undo, Clear, or removing any action: a plan only grows during Plan (D37).

## Notes

- Legality is core's (D29). Disable a button only on what the snapshot says (`usable`, `unlocked`, `rested`, `attachedTo`, the Leader being in the command zone), never on a rule the web code works out (affordability, room, overlap). The preview never judges the footprint; `plan.checked` does.
- No Undo and no Clear (D37): `plan.checked` shows the cards a utility spell draws (D29), so taking the spell back would be a free look at the deck. A refused action stays in the plan, struck through, and the round skips it (`plan.rejected`). The session sends only a plan that extends the last one (T-085), as the host keeps only those (T-080).
- `describeAction`'s lookup finds a card instance in the round's snapshot or the checked one (a card a utility spell drew is only in the second), and gives its name from `session.cards`, else its cardId.
- The squad ids in `checked.snapshot` are the ones the real round gives, because the human is seat 0 and core applies seat 0's plan first (D29). A later action can name them.
