---
id: T-197
title: Charge in the web
milestone: M5
depends_on: [T-192, T-193, T-194]
branch: agent/T-197-charge-in-the-web
model: sonnet
effort: high
scope:
  - apps/web/src/match/**
  - apps/web/src/replay/**
  - apps/web/src/cards/CardFace.tsx
  - apps/web/src/cards/CardFace.test.tsx
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

# T-197 — Charge in the web

## Goal

D68: Charge is a Plan ability paid in mana, and resources no longer attach to units. Core (T-193) takes `{ action: 'charge', squad }`, reports `SquadSnapshot.charged` and emits `squad.charged`, and keeps `attach` working until T-200 removes it. The web drops every attach control and shows a Charge button instead; the battlefield's Charge glow and the card view follow `charged`. The human asked for it after the 2026-11-05 playtest: attaching asked for a pick per resource and per unit when paying mana is the same decision in one click.

## Interfaces

What exists (copied on 2026-11-05):

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
// apps/web/src/match/planning/PlanGrid.tsx
function chargeOf(view: Snapshot, squad: SquadSnapshot, card: Card | undefined) { // :113
  if (squad.rested || card === undefined || !('stats' in card) || !('charge' in card.stats)) return null;
  const { charge } = card.stats;
  if (charge <= 0) return null;
  if (squad.attached >= charge) return 'charged';
  const free = view.resources.filter((resource) => !resource.rested && resource.attachedTo === null).length;
  return free >= charge - squad.attached ? 'ready' : null;
}
// :230 Block's prop charge?: 'charged' | 'ready' | null → .cg-charge-glow / .cg-charge-ready (:249-:250)

// apps/web/src/match/battlefield/scene.ts
// :1295 charged: !rested && charge > 0 && attachedResources(model, squad.squad).length >= charge,
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
// apps/web/src/cards/CardFace.tsx:158 [t('cards.face.charge'), card.stats.charge]; cards.json "face.charge": "Charge"
// en/planning.json "resource.attached": "Attached"

// What T-193 provides (packages/protocol, docs/PROTOCOL.md › Plans): the plan action
//   { action: 'charge'; squad: SquadId }   — pays the card's Charge in generic floating mana (D64), once a round
//   SquadSnapshot.charged?: boolean       — true for the round once charged; optional until T-200: read `squad.charged === true`
//   event 'squad.charged' { seat, squad }  — on apply; the charge ends at Cleanup, with no event
//   and in the web: describeAction's "Charge {squad}", actionCard's case, the round log's line
//   (`overlays.log.squadCharged`), and apply.ts logs `squad.charged` but stores nothing
//   `attach`, `attachedTo`, `attached` and resources.attached/detached stay until T-200: core still accepts them.
```

Tests today: `PlanningActions.test.tsx` (the Attach cases: grep `attach`), `PlanningPanel.test.tsx` :419 "shows resources: rested ones dimmed, attached ones marked", `Tray.test.tsx`, `PlanGrid.test.tsx` (the glow: grep `charge`), `scene.test.ts` (charged cues, T-162/T-180), `CardView.test.tsx` :259 "with cards attached to the squad", `apply.test.ts`, `log.test.ts`, `units-list.test.ts`, `pools.test.ts` :83 "groups by card and by state".

## Deliverables

1. **The attach UI goes.** Delete the `attach` selection kind, the Tray's "Attach N" button, ResourceEntry's checkbox and "Attached" text, SquadPanel's "Attach resources" button and "Attached" row, the `attach` cases in `index.tsx` and `draft.ts`, `attachedResources` and `model/pools.ts`, the model's `attachedTo` handling and the `resources.attached`/`detached` handlers (the event types stay in the protocol until T-200; `applyEvent` ignores them), the log's lines for them, the strip's attached outline and the `attachedTo` part of `poolStacks`'s key, the "attached to" texts in `units-list.ts` and `MatchScreen.tsx`. The card view's `attached` list keeps the permanents attached to the squad (enchantments, T-140) and stops listing resources.
2. **A Charge action.** `SquadPanel` shows "Charge (N mana)" for a card with Charge N > 0, where "Attach resources" was: it pushes `{ action: 'charge', squad: squad.squad }`. Hidden for Charge 0; disabled only on snapshot facts: `squad.charged` already true, or `state.checking` (D29: affordability is core's, and T-202 adds the inactive state from `payable`). A charged squad's panel says "Charged this round". Keep the `useAbility` buttons as they are.
3. **The glow reads `charged`.** `chargeOf` in PlanGrid returns `'charged'` when `squad.charged === true`, and `'ready'` when the card has Charge and the seat's floating mana count is at least its Charge (`view.resources.filter((r) => r.floating).length`), else null. `cueOf` in `scene.ts` sets `charged` from the model's squad. `SquadModel` gains `charged: boolean`: `apply.ts` sets it on `squad.charged` and clears it on `round.ended`, where `rested` clears; update the test literals that build a `SquadModel` (MatchScreen, CardView, pick, sprites, units-list).
4. **CardFace's Charge row** reads "N mana" (`cards.face.chargeMana`: "{n, plural, one {# mana} other {# mana}}"), or stays hidden at 0 if the face hides zero rows today (keep its current rule).
5. **Regenerated fixtures.** After T-196 (bots charge) merged, rerun the two `pnpm sim` commands from `apps/web/test/fixtures/logs/README.md` and Prettier, so the logs hold `squad.charged` events. It's their first regeneration since T-189, so they also lose their `*.durabilityChanged` events and hold Fleeting retirements: update the README's table and the tests that count on the logs (`model/fixtures.test.ts`, the replay's). If `emblem.json`'s seed no longer holds an Emblem, pick the first seed in 1..40 that does, as the README says. The planning fixture snapshots (`apps/web/test/fixtures/planning/*.json`) get `charged: false` on every squad and keep `attached: 0`, `attachedTo: null` and their Durability numbers until T-200.
6. **Tests.** `PlanningActions.test.tsx`: Charge sends the action; hidden for Charge 0; disabled when `charged`; no Attach anywhere. `PlanningPanel.test.tsx`: the resources test without "attached ones marked". `PlanGrid.test.tsx`: `'charged'` from the snapshot, `'ready'` from the floating mana. `scene.test.ts`: the glow from the model's `charged`. `apply.test.ts`: `squad.charged` sets it, the round's end clears it, `resources.attached` is ignored. `CardView.test.tsx`: the attached list holds only permanents. `CardFace.test.tsx`: the Charge row's text. `log.test.ts`, `units-list.test.ts`, `pools.test.ts` as needed.
7. **Docs.** `apps/web/README.md` › How a match flows or Rules a change must keep, where it names attaching (grep `attach`).

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test` passes.
- [ ] `pnpm test` passes.
- [ ] `grep -rn "attach" apps/web/src/match --include=*.ts --include=*.tsx -i` finds only the attached-permanent code (`mode === 'attached'`, enchantments) and no resource attaching.
- [ ] `grep -c "squad.charged" apps/web/test/fixtures/logs/starter-2-rounds.json` is above 0 (a bot charged), or the PR says why no bot charged in that seed.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The inactive state from `payable` and resting from the strip: T-202.
- Moving the actions into the card view and the Leader's slot: T-199.
- The protocol's `attach` removal and the `attached`/`attachedTo` fields: T-200.

## Notes

- Permanents attached to squads (equipment and auras, `PermanentSnapshot` `mode: 'attached'`, `castPermanent` with `mode: 'attached'`, HandEntry :51) are a different thing and stay: only resources stop attaching.
- D64: the player rests resources for mana first, then charges; the Charge button never rests anything.
- While T-200 hasn't merged, the snapshot still has `attached: 0` and `attachedTo: null`; read neither.
- T-196 (bots charge) runs in this wave: rebase on main once it's merged before regenerating the logs, so they show bots charging. If it isn't merged when you're done, regenerate anyway and note it; T-200 regenerates again.
