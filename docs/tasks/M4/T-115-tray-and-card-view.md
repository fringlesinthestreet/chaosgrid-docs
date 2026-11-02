---
id: T-115
title: The match tray and the card view
milestone: M4
depends_on: [T-111, T-112, T-113]
branch: agent/T-115-tray-and-card-view
model: sonnet
effort: high
scope:
  - apps/web/src/match/planning/**
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/src/match/session.ts
  - apps/web/src/match/session.test.ts
  - apps/web/src/match/CardView.tsx
  - apps/web/src/match/CardView.test.tsx
  - apps/web/src/cards/CardDetail.tsx
  - apps/web/src/cards/cards.test.tsx
  - apps/web/src/theme/theme.css
  - apps/web/test/fixtures/session.ts
  - apps/web/test/fixtures/planning/**
  - apps/web/e2e/m4.spec.ts
context:
  - docs/tasks/M4/README.md#The match
---

# T-115 — The match tray and the card view

## Goal

From the human's playtest (2026-10-29):

- **The tray.** The player's hand, resource pool and discard pile sit in rows under the battlefield, laid out horizontally. They stay on screen through the round's playback, so the next round can be planned while the fight plays. Today they show only during Plan, stacked in the planning panel's side column.
- **The card view.** Clicking a card opens a larger view in front of the screen, instead of the small one at the bottom of that column.
- **The battlefield.** Clicking a unit, a permanent, a prize or an Emblem opens the same view, for any owner, Chaos included (D43). T-111 made the battlefield say what a click hit.

## Interfaces

What exists (copied from the code on 2026-10-29):

```tsx
// apps/web/src/match/MatchScreen.tsx:121-159
// SessionContext.Provider > div[data-match-screen] > TopBar; the error Panel; the battlefield box
//   (:130, position relative, height min(70vh, 640px), minHeight 360) with <Battlefield model step
//   viewer cards stepMs chaosBanner={false} /> and the "Round over" status; PlaybackControls while
//   playing; {state.planning && <ReadyBar …/>}; {state.planning && <PlanningPanel />}; <Overlays />
//   (a fixed layer at zIndex 20, panels.tsx:30-35).

// apps/web/src/match/planning/index.tsx
// PlanningPanel (:363-377): section[aria-label="Planning panel"] > h2 "Planning" >
//   <PlanProvider key={view.round} round view={planView(state)}> > PanelBody (:87-361).
// PanelBody: Esc cancels and R rotates (:108-124); div[data-planning-panel] (:203) holds the left
//   column (status line :205-216; TargetPicker or PlanGrid :218-243; SquadPanel, PermanentPanel
//   :245-246) and div[data-plan-side] (:248): "Leader" (:250-270), RulesBar (:272), "Hand"
//   (:273-298, HandEntry per card), "Resources" (:300-324, "Attach N" and ResourceEntry per
//   resource), "Plan" (:326-350), ZonesPanel (:351), "Card detail" (:352-357, `detail` state at :90).
// PlanContext.tsx: PlanProvider({ round, view, children }) (:76), usePlan (:104), PlanControls
//   { draft, view, push, selection, select, inspected, inspect } (:60-71).
// draft.ts:34-36: planView(state) = state.checked?.snapshot ?? state.snapshot
// HandEntry.tsx: a flex-row <li data-hand-card> (:55) with a CardTile (:59) and its Place / Cast
//   buttons (:65-82). ResourceEntry.tsx:16. ZonesPanel.tsx:11-66: every seat's discard pile and void
//   as <details>, with its own "Zone card detail" (:58-63).

// apps/web/src/cards
export function CardDetail({ card }: { card: Card }): JSX.Element;  // CardDetail.tsx:70: article.cg-card-detail, aria-label card.name, art 96 px
export function CardTile(props: { card: Card; count?: number; onClick?: () => void; disabled?: string }): JSX.Element; // CardTile.tsx:5-10, a <button> only with onClick

// apps/web/src/match/session.ts:102-103: onEvents clears `checked` when round.started arrives, but
//   the next round's snapshot waits for playback.idle() (:116-125). So during playback planView falls
//   back to the Plan-start snapshot of the round being played: the hand before the plan.
// The model holds no hand, pool or pile (model/types.ts:125-149); they come from the snapshot:
//   Snapshot.hand, .resources, .players[seat].discardPile ({ card, cardId, size, cost }[]).
// Battlefield picks (T-111): BattlefieldProps.onPick?: (pick: BattlefieldPick) => void, where
//   BattlefieldPick { world, seat, cell, unit: UnitModel | null, permanent: PermanentModel | null }.
//   UnitModel.cardId (model/types.ts:56), PermanentModel.cardId: CardId | null and kind (:99).
//   session.cards: ReadonlyMap<string, Card>, Chaos cards included.
// Tests that find the old places: PlanningPanel.test.tsx:103 (getByLabelText('Hand')), :120 and
//   :125 ('Card detail'); Zones.test.tsx:113 ('Zone card detail'); [data-hand-card]
//   (PlanningActions.test.tsx:64, Zones.test.tsx:46).
```

What this task adds:

```tsx
// match/planning, exported from planning/index.tsx
/** The seat's hand, resource pool and discard pile in rows: with their Plan actions while planning, read-only the rest of the match. */
export function Tray(): JSX.Element | null;

// match/CardView.tsx
export type CardViewSubject =
  | { kind: 'card'; card: Card; caption?: string } // caption: whose it is, and a unit's level
  | { kind: 'prize'; seat: Seat; hp: number };
export function CardViewProvider({ children }: { children: ReactNode }): JSX.Element;
export function useCardView(): { show(subject: CardViewSubject): void; close(): void };
/** The card view: fixed in front of the screen, labeled "Card view". */
export function CardView(): JSX.Element | null;

// cards/CardDetail.tsx
export function CardDetail({ card, size }: { card: Card; size?: 'normal' | 'large' }): JSX.Element; // large: art at 192 px
```

## Deliverables

1. **The tray.** A band under the battlefield with three labeled groups, "Hand", "Resources" and "Discard pile". Each lists its cards left to right as tiles and scrolls sideways when it runs out of room. It shows whenever the session has a snapshot: Plan, playback, and up to game over. While `state.planning` is true the tiles keep their Plan actions (Place, Cast, abilities, Attach's checkboxes); otherwise a tile only opens the card view. The hand and resources leave the planning panel's side column. The panel keeps the rest: the Leader, the rules bar, the Plan list, Zones (the other seats' piles and voids), the squad and permanent panels, and the grid.
2. **The plan's result through playback.** The session keeps `checked` until a newer round's snapshot is released, instead of clearing it at `round.started`. During playback `planView` is then the seat's view as its plan left it: the cards it kept, the resources it has left.
3. **The card view.**
   - **Look.** A panel fixed at the right of the screen, in front of everything (above the overlays' layer), about 360 px wide, with `CardDetail` at its large size.
   - **Behavior.** It's non-modal: the screen behind it still works. Close and Escape close it. Opening it moves focus to its Close button, and closing it returns focus to whatever opened it. A new subject replaces the one shown, and it stays open across rounds until closed.
   - **Openers:** every card tile in the tray, the Leader tile, the cards in ZonesPanel and the Plan list, and the battlefield.
   - **From the battlefield.** `onPick` shows the pick's unit's card (captioned "You", "Seat N" or "Chaos", and its level), else the permanent's card. A prize shows `{ kind: 'prize' }`: whose prize it is and its HP from the model. A click on an empty cell shows nothing.
   - **What goes.** The panel's "Card detail" section, and ZonesPanel's own detail.
4. **Tests.**
   - The tray in Plan with its actions, and during playback without them.
   - The tray during playback shows the plan's result, not the Plan-start hand.
   - The card view opens from a tray tile, from ZonesPanel and from a battlefield pick (a stub `Battlefield` that calls `onPick`). Escape closes it, and focus returns.
   - Update the tests that found the old places.
5. **The e2e** passes, with any locator that moved updated.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test -- planning MatchScreen CardView session cards` passes
- [ ] `grep -rn -E "Zone card detail" apps/web/src` prints nothing
- [ ] `pnpm test:e2e` passes

## Out of scope

- Choosing discards in the tray (T-116).
- Planning on the battlefield (T-117, T-118). The grid stays in the panel for now.
- Where the Ready bar sits, and the round banner (T-113).

## Notes

- The tray's selection state lives in `PlanProvider`, so it has to wrap the tray as well as the panel. Mount the provider whenever there's a snapshot, keyed by round as now. Only the controls depend on `state.planning`.
- D29 as in the panel: a tray control is disabled only on a fact the snapshot states.
- The tray reads the snapshot (`planView`). The card view's battlefield subjects come from the model, which is what the battlefield draws (D43).
- Desktop first: it must work from 1024 px wide. Tiles are buttons named after their card, so the tray works by keyboard.
- Default: the discard pile lists oldest first, as the snapshot does, so the newest card is at the right end.
