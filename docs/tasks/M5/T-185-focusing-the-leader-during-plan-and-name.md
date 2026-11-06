---
id: T-185
title: Focusing the Leader during Plan and nameless grid icons
milestone: M5
depends_on: []
branch: agent/T-185-focusing-the-leader-during-plan-and-name
model: sonnet
effort: medium
scope:
  - apps/web/src/match/planning/**
  - apps/web/src/match/CardView.tsx
  - apps/web/src/match/CardView.test.tsx
  - apps/web/src/i18n/en/planning.json
context:
  - docs/APPS.md#The match
  - docs/DECISIONS.md#Decision log
  - apps/web/README.md#Rules a change must keep
---

# T-185 — Focusing the Leader during Plan and nameless grid icons

## Goal

A bug from the human's playtest (2026-11-05): "I charged the Leader (Grimbark the Hollow) and couldn't focus on him to get card details during planning." After this PR a click on any of the viewer's squads or permanents during Plan opens the card view with that card, the Leader's included, and the cause is pinned by a regression test. PlanGrid's icons also stop printing the card's name (D71): the art shows, the name stays in the accessible label.

## Interfaces

What exists (copied on 2026-11-05):

```tsx
// apps/web/src/match/planning/PlanLayer.tsx:57-:81 — PlanGrid over the viewer's grid during Plan:
{...(isPlacing(selection)
  ? { onCell: place }
  : attachedSelection
    ? { pickable: ownSquads.map((squad) => squad.squad), onSquad: (squad) => attachPermanent(squad.squad) }
    : { onSquad: (squad) => inspect({ squad: squad.squad }),
        onPermanent: (permanent) => inspect({ permanent: permanent.permanent }) })}
// :48-:52 attachPermanent: casts an attached artifact or enchantment on the picked squad

// apps/web/src/match/planning/PlanGrid.tsx
function cellOf(event): Cell | null {                       // :346, one listener for the whole grid
  const button = (event.target as Element).closest<HTMLElement>('button[data-col]');
  …
}
function click(event: MouseEvent) {                         // :352
  const cell = cellOf(event);
  if (cell === null || disabled) return;
  onCell?.(cell);
  const here = contents[cell.row]?.[cell.col];
  if (here?.squad !== undefined && (pickable === undefined || pickable.includes(here.squad.squad))) onSquad?.(here.squad);
  if (here?.permanent !== undefined) onPermanent?.(here.permanent);
}
// :113 chargeOf(view, squad, card) → 'charged' | 'ready' | null; :250 the Block draws
//   <span className="cg-charge-glow …"> (theme.css:103 `.cg-charge-glow { pointer-events: none }`)
// :470-:474 the caption on blocks bigger than one cell:
{w * h > 1 && (<span style={CAPTION}>{name}{squad.leader ? ' ★' : ''}</span>)}
// :436 label={t('planning.squad.label', { name, level, leader, durability, canLevelUp, rested, flying, reach, blocker })}

// apps/web/src/match/planning/index.tsx
// :128-:136 inspectedSquad / inspectedPermanent from `inspected`; :231-:233 they render <SquadPanel> / <PermanentPanel>
// :224-:247 <section aria-label="Leader">: shows the Leader's tile only while view.leader isn't null
// apps/web/src/match/planning/SquadPanel.tsx:33-:37 <section aria-label="Squad"><h3>{name}{' (Leader)'}</h3> — no way to the card view

// apps/web/src/match/CardView.tsx
export function useCardView(): { show(subject: CardViewSubject): void; close(): void } // :75
export type CardViewSubject = | { kind: 'card'; card: Card; caption?: string; attached?: readonly Card[]; unit?: UnitId } | … // :22
// MatchScreen.tsx:236-:260 builds a squad's subject for a battlefield click outside Plan ("You, level 2");
// MatchScreen.tsx is T-188's this wave: don't edit it.

// packages/cards/data/leaders/grimbark_the_hollow.json: cost "1ED", stats.charge 1,
// "If charged: draw 1 resource extra this round. 2D: revive a unit card from your discard pile"
```

## Deliverables

1. **Find the cause first.** Write the repro as a component test before changing code: the Leader on the grid (from `plan.checked`, as `PlanningPanel.test.tsx` › "shows the Leader on the grid once plan.checked has it there" does), a resource attached to it (the `attach` action; T-193 replaces it with `charge` later), then a click on one of its cells. Say in the PR what the cause was. What the code suggests, to check rather than assume:
   - During Plan the PlanLayer takes every click on the viewer's grid and only calls `inspect`, which opens the Squad panel. That panel has no way to the card view, and the Leader section is gone once the Leader stands on the grid, so no placed card can be read. "Charged" may not matter at all.
   - An attach selection that stays on after the attach, so the click goes elsewhere.
   - Something in front of the cell buttons. The glow and the Block take no pointer events in CSS, which jsdom doesn't apply, so check the DOM order and the handlers too.
2. **The fix.** A click on one of the viewer's squads or permanents during Plan opens the card view with that card, as a click does outside Plan, and keeps opening the Squad or Permanent panel. The caption reads like MatchScreen's ("You, level 2"; "(Leader)" for the Leader). Build the subject in `planning/` with the existing texts; put any new text in `en/planning.json`. Leave out `unit` if the planning snapshot doesn't name the squad's units. Placing and attaching keep taking clicks as they do now.
3. **No names on the icons (D71).** The caption goes from PlanGrid's blocks, except the Leader's ★, which stays alone in its place so the Leader can be found. The name stays in the block's accessible label (`planning.squad.label`).
4. **Tests.**
   - The repro, passing.
   - Clicking a squad and a permanent opens the card view with the right card and caption, while placing doesn't.
   - The block shows no name text, and a Leader's block shows ★.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test planning CardView` passes.
- [ ] `pnpm test` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The battlefield's scene: it draws no names, so nothing changes there.
- Moving the actions into the card view and the Leader's slot in the tray: T-199.
- Durability in the block's label: T-194.

## Notes

- Lead default: the card view opens beside the panel, not instead of it; T-199 later moves the panel's actions into the card view.
- `apps/web/src/match/MatchScreen.tsx` and `en/match.json` belong to T-188 this wave. If the fix needs either, stop and say what.
