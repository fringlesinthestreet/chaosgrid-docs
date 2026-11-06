---
id: T-197
title: No attach or Charge in the web
milestone: M5
depends_on: [T-192, T-193, T-194]
branch: agent/T-197-no-attach-or-charge-in-the-web
model: sonnet
effort: medium
scope:
  - apps/web/src/match/**
  - apps/web/src/replay/**
  - apps/web/src/cards/CardFace.tsx
  - apps/web/src/cards/CardFace.test.tsx
  - apps/web/src/theme/palette.ts
  - apps/web/src/theme/palette.test.ts
  - apps/web/src/theme/theme.css
  - apps/web/test/fixtures/**
  - apps/web/src/i18n/en/match.json
  - apps/web/src/i18n/en/planning.json
  - apps/web/src/i18n/en/battlefield.json
  - apps/web/src/i18n/en/overlays.json
  - apps/web/src/i18n/en/cards.json
  - apps/web/README.md
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Resources and mana
  - docs/APPS.md#The match
  - docs/PROTOCOL.md#Plans
  - apps/web/README.md#Rules a change must keep
---

# T-197 — No attach or Charge in the web

## Goal

D74: resources never attach to units, and Charge goes, so a unit spends mana during Plan only on its level-ups and its Plan abilities. The web drops every attach control and every Charge cue: the Attach buttons and checkboxes, the Charge glow and the card face's Charge row. The Plan ability buttons stay as they are, and the abilities that replace Charge (T-212) show there like every other. The human asked for it on 2026-11-06: Charge was a second way to spend mana on a unit, beside its Plan abilities.

## Interfaces

What exists (copied on 2026-11-05; grep the names, the lines move):

```tsx
// apps/web/src/match/planning/SquadPanel.tsx
// :15 const attached = view.resources.filter((resource) => resource.attachedTo === squad.squad);
// :20 const attaching = selection?.kind === 'attach' && selection.squad === squad.squad;
// :23-:27 hasCharge: cardData.stats.charge > 0;  :28 canAttach: an unrested, unattached resource exists
// :48-:56 <dt>Attached</dt>; :87-:96 the "Attach resources" button → select({ kind: 'attach', squad, resources: [] })
// apps/web/src/match/planning/ResourceEntry.tsx
// :26 const free = !resource.rested && resource.attachedTo === null;  :27 attaching = selection?.kind === 'attach'
// :44 {resource.attachedTo !== null && <span>{t('planning.resource.attached')}</span>}
// :72-:88 the "Select {name} to attach" checkbox
// apps/web/src/match/planning/Tray.tsx:57-:72 the "Attach N" button that pushes { action: 'attach', squad, resources }
// apps/web/src/match/planning/PlanContext.tsx:50 | { kind: 'attach'; squad: SquadId; resources: CardInstanceId[] };
// apps/web/src/match/planning/index.tsx:196 selectionText case 'attach'; :106 actionCard case 'attach'
// apps/web/src/match/planning/draft.ts:134 describeAction case 'attach'
// apps/web/src/match/planning/PlanGrid.tsx:113 chargeOf(view, squad, card) → 'charged' | 'ready' | null, from the
//   card's stats.charge and the squad's attached resources; :230 Block's prop charge → .cg-charge-glow / .cg-charge-ready
// apps/web/src/theme/theme.css:111-:135 .cg-charge-glow, .cg-charge-ready, @keyframes cg-charge-pulse;
//   apps/web/src/theme/palette.ts:11 and :38 `charge`, the glow's color
// apps/web/src/match/battlefield/scene.ts
// :203-:204 a unit's `glow` (drawChargeGlow); :334 the cue's `charged`; :337-:343 drawChargeGlow (PALETTE.charge);
// :346-:374 the squad cue draws the glow; :1301 the glowing units; :1318-:1329 charged from stats.charge and
//   attachedResources(model, squad)
// :673-:678 the outline of an attached stack in a strip (`first.attachedTo !== null`)
// :1112 case 'attached' (a permanent attached to a squad: stays, that's an enchantment, not a resource)
// apps/web/src/match/battlefield/pools.ts:72 poolStacks keys by `${cardId}|${rested}|${attachedTo}`
// apps/web/src/match/battlefield/units-list.ts:46-:50 "…, attached to {squads}" (battlefield.json "poolList.attached")
// apps/web/src/match/model/pools.ts: attachedResources(model, squad)   // the only export; used by scene.ts and MatchScreen.tsx
// apps/web/src/match/model/apply.ts :135, :480 attachedTo; :492 case 'resources.attached'; :500 case 'resources.detached'
// apps/web/src/match/model/types.ts:186 'resources.attached' in the logged event types
// apps/web/src/match/overlays/log.ts:74, :224 ('overlays.log.resourcesAttached'), :377
// apps/web/src/match/MatchScreen.tsx:180-:185 the "attached to {squad}" caption (match.json "cardView.attachedTo"); :236-:248 the squad subject's `attached` list adds attachedResources
// apps/web/src/match/CardView.tsx:22 CardViewSubject 'card' has `attached?: readonly Card[]` (T-140's list, :181-:196)
// apps/web/src/cards/CardFace.tsx:201 and :205 [t('cards.face.charge'), card.stats.charge]; cards.json "face.charge": "Charge"
// en/planning.json "resource.attached": "Attached"

// What stays until T-212 removes it with the protocol: the `charge` action (draft.ts:115 and :175, "Charge {squad}"),
//   the `squad.charged` event (apply.ts:521, types.ts:187, the log's line and `overlays.log.squadCharged`) and
//   SquadSnapshot.charged. `attach`, `attachedTo`, `attached` and resources.attached/detached stay in the protocol
//   until T-200: core still accepts them.
```

Tests today: `PlanningActions.test.tsx` (the Attach cases: grep `attach`), `PlanningPanel.test.tsx` :419 "shows resources: rested ones dimmed, attached ones marked", `Tray.test.tsx`, `PlanGrid.test.tsx` (the glow: grep `charge`), `scene.test.ts` (charged cues, T-162/T-180), `CardView.test.tsx` :259 "with cards attached to the squad", `apply.test.ts`, `log.test.ts`, `units-list.test.ts`, `pools.test.ts` :83 "groups by card and by state", `CardFace.test.tsx`, `palette.test.ts`.

## Deliverables

1. **The attach UI goes.** Delete the `attach` selection kind, the Tray's "Attach N" button, ResourceEntry's checkbox and "Attached" text, SquadPanel's "Attach resources" button and "Attached" row, the `attach` cases in `index.tsx` and `draft.ts`, `attachedResources` and `model/pools.ts`, the model's `attachedTo` handling and the `resources.attached`/`detached` handlers (the event types stay in the protocol until T-200; `applyEvent` ignores them), the log's lines for them, the strip's attached outline and the `attachedTo` part of `poolStacks`'s key, the "attached to" texts in `units-list.ts` and `MatchScreen.tsx`. The card view's `attached` list keeps the permanents attached to the squad (enchantments, T-140) and stops listing resources.
2. **The Charge cues go.** SquadPanel's `hasCharge`, PlanGrid's `chargeOf` and the Block's `charge` prop, the `.cg-charge-*` classes and their keyframes, scene.ts's Charge glow (`drawChargeGlow`, the units' `glow`, the cue's `charged` and what feeds it), `PALETTE.charge` and `COLORS.charge` once nothing reads them, and CardFace's Charge row with `cards.face.charge`. Keep the `useAbility` buttons as they are.
3. **What stays.** The `charge` cases in `draft.ts`, the model's `squad.charged` case and the log's line for it stay while the protocol has them: T-212 removes them. No control in the web sends `charge`.
4. **Tests.** `PlanningActions.test.tsx`: no Attach and no Charge anywhere, and the ability buttons as before. `PlanningPanel.test.tsx`: the resources test without "attached ones marked". `PlanGrid.test.tsx` and `scene.test.ts`: no Charge glow. `apply.test.ts`: `resources.attached` is ignored. `CardView.test.tsx`: the attached list holds only permanents. `CardFace.test.tsx`: no Charge row. `log.test.ts`, `units-list.test.ts`, `pools.test.ts` and `palette.test.ts` as needed.
5. **Docs.** `apps/web/README.md` › How a match flows or Rules a change must keep, where it names attaching or Charge (grep `attach` and `charge`).

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test` passes.
- [ ] `pnpm test` passes.
- [ ] `grep -rn "attach" apps/web/src/match --include='*.ts' --include='*.tsx' -i` finds only the attached-permanent code (`mode === 'attached'`, enchantments) and no resource attaching.
- [ ] `grep -rn "charge" apps/web/src --include='*.ts' --include='*.tsx' --include='*.css' -i` finds only the `charge` action and the `squad.charged` event of item 3, and "the cost core charges".
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The inactive state from `payable` and resting from the strip: T-202.
- Moving the actions into the card view and the Leader's slot: T-199.
- The protocol's `charge` (T-212) and `attach` (T-200), with the `charged`, `attached` and `attachedTo` fields.
- Regenerating the event logs: T-200 does it once nothing attaches.

## Notes

- Permanents attached to squads (equipment and auras, `PermanentSnapshot` `mode: 'attached'`, `castPermanent` with `mode: 'attached'`, HandEntry :51) are a different thing and stay: only resources stop attaching.
- While T-200 hasn't merged, the snapshot still has `attached: 0` and `attachedTo: null`; read neither.
- The planning fixtures (`apps/web/test/fixtures/planning/*.json`) are hand-made: edit them only where a test needs it.
