---
id: T-199
title: The tray, the Leader's slot and the card view's actions
milestone: M5
depends_on: [T-197, T-200]
branch: agent/T-199-the-tray-the-leader-s-slot-and-the-card
model: opus
effort: high
scope:
  - apps/web/src/match/planning/**
  - apps/web/src/match/CardView.tsx
  - apps/web/src/match/CardView.test.tsx
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/src/match/overlays/Hud.tsx
  - apps/web/src/match/overlays/overlays.test.tsx
  - apps/web/src/cards/CardTile.tsx
  - apps/web/src/cards/cards.test.tsx
  - apps/web/src/theme/theme.css
  - apps/web/src/i18n/en/match.json
  - apps/web/src/i18n/en/planning.json
  - apps/web/src/i18n/en/overlays.json
  - apps/web/README.md
context:
  - docs/DECISIONS.md#Decision log
  - docs/APPS.md#The match
  - docs/RULES.md#Round structure
  - apps/web/README.md#Rules a change must keep
---

# T-199 — The tray, the Leader's slot and the card view's actions

## Goal

D71: the grid is the planning surface. The tray at the bottom holds the hand and, at its left, the Leader's slot, empty once the Leader stands on the grid; the planning panel's Leader section goes. A squad, a permanent or a hand card acts from the card view: its actions (Place or Cast, Move, Level up, Charge, its Plan abilities) stand beside the focused card, on the right, and the Squad and Permanent panels under the grid go. The human asked for both after the 2026-11-05 playtest.

## Interfaces

What exists (copied on 2026-11-05):

```tsx
// apps/web/src/match/planning/index.tsx
// :224-:247 <section aria-label="Leader">: the Leader's CardTile (opens the card view) and the "Place Leader" button → select({ kind: 'castLeader', size: leader.size, rotated: false })
// :209-:211 const leader = view.leader; leaderCard = session.cards.get(leader.cardId); leaderPicked = selection?.kind === 'castLeader'
// :215-:222 the status line "<selectionText>. Esc cancels." and the Rotate (R) button; :221 <TargetPicker …/>
// :231-:233 {inspectedSquad !== undefined && <SquadPanel squad={inspectedSquad} />} {inspectedPermanent !== undefined && <PermanentPanel permanent={inspectedPermanent} />}
// :249 <RulesBar rules={view.rules} />
// :308 <section aria-label="Planning panel"><h2>Planning</h2>…
// apps/web/src/match/planning/PlanContext.tsx
export type Inspected = { squad: SquadId } | { permanent: PermanentId };          // :58
export interface PlanControls { draft; view; push; selection; select; inspected; inspect } // :60-:72
// apps/web/src/match/planning/PlanLayer.tsx:72-:78 onSquad → inspect({ squad }), onPermanent → inspect({ permanent }) (T-185 fixed the Leader's focus here)
// apps/web/src/match/planning/SquadPanel.tsx (after T-197): name, Level, Move (Leader), "Level up ({cost})" when unlocked and below max, "Charge (N mana)", AbilityButtons for the card and its attached permanents, Close → inspect(null)
// apps/web/src/match/planning/PermanentPanel.tsx: Kind, AbilityButtons, Close
// apps/web/src/match/planning/AbilityButtons.tsx:10 AbilityButtons({ card, name, uses, rests? }) — one "Use ability N" button per AbilityUse, disabled on !use.usable
// apps/web/src/match/planning/HandEntry.tsx:13 HandEntry({ entry, card, discard? }): the tile opens the card view; Place (units) / Cast (the rest) buttons, :29-:54 cast()
// apps/web/src/match/planning/Tray.tsx (after T-190): <section aria-label="Hand"> and <section aria-label="Resources"> (FloatingMana + ResourceEntry list)
// apps/web/src/match/CardView.tsx
export type CardViewSubject =
  | { kind: 'card'; card: Card; caption?: string; attached?: readonly Card[]; unit?: UnitId } // :22 (T-192 adds the live stats from `unit`)
  | { kind: 'prize'; seat: Seat; hp: number }
  | { kind: 'pile'; … };
export function useCardView(): { show(subject): void; close(): void }   // :75
export function CardView()  // :200: <aside aria-label="Card view" data-card-view="" className="cg-panel cg-card-view"> with Close first; Escape closes (T-142)
// apps/web/src/match/MatchScreen.tsx
// :236-:260 subjectOf(pick, …) → the 'card' subject for a battlefield click, with caption "You, level 2" / "Seat 2"
// :372-:375 <PlanningProvider>{planning && <PlanLayer />}{createPortal(<Tray />, trayHost)}{createPortal(<PlanningPanel />, planningHost)}</PlanningProvider>
// :379-:397 Overlays pieces: topBar, status, planning (left region, LEFT_PANEL_PX wide), playback, tray (bottom), ready, cardView (right region)
// apps/web/src/match/overlays/Hud.tsx:107-:160 Overlays: regions top / left (RoundSummaryCard, the planning HudPanel) / center (freeArea) / right (RoundBanner, LogDrawer, cardView) / bottom (playback, the tray's HudPanel "overlays.hud.yourCards" with unfoldKey, ready)
// apps/web/src/match/battlefield/camera.ts:23 Insets; :33 freePart(viewport, insets) — T-188 feeds the tray's height as the bottom inset
// packages/protocol/src/snapshot.ts: Snapshot.leader: LeaderCard | null (null once the Leader is on the grid); SquadSnapshot.leader: boolean, unlocked, level, cost, uses, charged (T-193)
```

Tests today: `PlanningPanel.test.tsx` :109 "shows the Leader, the hand, the resources and an empty plan", :147 "opens the card view from the Leader tile", :163 "places the Leader: Place Leader, then a cell, sends castLeader", :270 "shows the Leader on the grid once plan.checked has it there, and moves it from there"; `PlanningActions.test.tsx` (Level up, Charge, abilities, through the SquadPanel); `CardView.test.tsx`; `overlays.test.tsx`; `MatchScreen.test.tsx`.

## Deliverables

1. **The Leader's slot in the tray.** The Tray's Hand section starts with the Leader's slot: while `view.leader` isn't null it shows the Leader's tile (opens the card view) and, while planning, "Place Leader" (the `castLeader` selection as today); once the Leader stands on the grid the slot is an empty frame labelled "Leader on the grid" (`planning.leader.onGrid`), the same size as a tile, so the hand doesn't shift. The panel's Leader section goes. A Leader respawns when killed and can't be banished (RULES.md › Leader), so the slot stays empty for the rest of the game.
2. **Actions beside the focused card.** The card view's `'card'` subject gains `actions?: ReactNode` (or an `acts` description the view renders; pick the simpler), shown in a column to the right of the face under a "Actions" heading. The planning side fills it:
   - a squad of the viewer's (from a battlefield click or PlanLayer's `inspect`): Move (Leader), Level up with its cost, Charge, its abilities and those of the permanents attached to it, as `SquadPanel` shows them today, disabled only on snapshot facts (`unlocked`, max level, `charged`, `usable`, `state.checking`; D29);
   - a free-standing permanent of the viewer's: its abilities, as `PermanentPanel`;
   - a hand card (a click on its tile): Place or Cast, as `HandEntry`'s buttons; the tile keeps them too while T-202 hasn't moved the tray to tiles only, or drop them from the tile now if the tray stays usable from the view (lead default: drop them, the view is the one place for actions);
   - another seat's card, a resource, a pile: no actions column.
   `SquadPanel.tsx` and `PermanentPanel.tsx` are deleted or reduced to the action lists the view renders (`SquadActions`, `PermanentActions`, `HandCardActions` in `planning/`); `inspect` opens the card view with the squad's or permanent's subject and its actions instead of a panel under the grid. The status line ("Placing X: pick a cell. Esc cancels.", Rotate) and the target picker stay in the planning panel.
3. **The planning panel shrinks** to what the battlefield doesn't show: the status line and target picker, `RulesBar`, and (T-202 later) nothing else. The tray takes as little height as it can: one scrollable row of tiles (`overflow-x: auto`, no wrap), the Leader's slot fixed at its left; the card view keeps the HUD's right region and doesn't cover the viewer's grid (the camera's free area excludes the right region already through `freeArea`; check `Hud.tsx` and `MatchScreen`'s insets from T-188, and give the card view a max height with its own scroll so it never grows past the region).
4. **Tests.** `Tray.test.tsx`: the Leader's slot with the tile and Place Leader; empty once `view.leader` is null; the castLeader flow (move from `PlanningPanel.test.tsx` :163 and :270). `PlanningPanel.test.tsx`: no Leader section. `CardView.test.tsx`: the actions column for a squad (Level up sends `levelUp`, Charge sends `charge`, an ability sends `useAbility`, each through `stubSession().sent`), for a permanent, for a hand card (Place starts the selection, Cast sends `castSpell`), and none for another seat's card. `PlanningActions.test.tsx`: its cases go through the card view now. `overlays.test.tsx`/`MatchScreen.test.tsx` where they look for the panels.
5. **Docs.** `apps/web/README.md` › How a match flows step 4 names the card view as where actions are taken.
6. **What T-190 left behind.** `Pile.tsx` and `Pile.test.tsx` go: nothing renders `PileRow` since the piles moved to the strips. `FloatingMana.tsx`'s header comment cites D64, not D58, which D64 replaced. `CardTile` takes an optional `describedBy` and sets it as its button's `aria-describedby`; `HandEntry` passes its rejection reason's id that way instead of on the `li`, so a screen reader reads the reason with the focused tile. `ResourceEntry` can stay as it is: T-202 removes it. A `cards.test.tsx` case pins the button's description.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test planning CardView MatchScreen overlays` passes.
- [ ] `pnpm test` passes.
- [ ] `grep -rn "aria-label=\"Leader\"\|aria-label=\"Squad\"\|aria-label=\"Permanent\"" apps/web/src/match` finds nothing.
- [ ] `grep -rn "PileRow\|D58" apps/web/src/match/planning` finds nothing.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Resting from the strip, the Resources section's removal and the inactive state from `payable`: T-202.
- The battlefield (`battlefield/**`) and the model: nothing here changes them.

## Notes

- Keep `inspect` in `PlanContext` as the one way the layer and the view talk: `inspect({ squad })` sets the inspected squad and shows the card view; the view's Close calls `inspect(null)` too. A new battlefield pick replaces the subject, as today.
- The card view is non-modal and gives the focus back to its opener on Close (T-115, T-142): the actions column must keep that (Close stays the first button).
- The tray's `HudPanel` folds with `unfoldKey` (a new Plan or Discard step unfolds it); keep it.
- The tile buttons: a `CardTile` lays one button over the face (its name); if the Place/Cast buttons leave the tile, a hand tile's only control is "open the card view", which is where Place and Cast now are: two clicks to place, one to read. Say in the PR if that feels slow in the e2e flow; T-202 can add a shortcut.
- T-201 runs in the same wave: it edits card data, the starter decks and core's effects, nothing in the web.
