---
id: T-202
title: Resources from the strips and inactive actions
milestone: M5
depends_on: [T-195, T-199, T-200]
branch: agent/T-202-resources-from-the-strips-and-inactive-a
model: opus
effort: high
scope:
  - apps/web/src/match/**
  - apps/web/test/fixtures/**
  - apps/web/src/i18n/en/match.json
  - apps/web/src/i18n/en/planning.json
  - apps/web/src/i18n/en/battlefield.json
  - apps/web/src/i18n/en/overlays.json
  - apps/web/README.md
context:
  - docs/DECISIONS.md#Decision log
  - docs/APPS.md#The match
  - docs/RULES.md#Resources and mana
  - docs/PROTOCOL.md#Snapshot
  - apps/web/README.md#Rules a change must keep
---

# T-202 — Resources from the strips and inactive actions

## Goal

D71 and D72, the last step of the planning surface. The viewer rests resources from its strip on the battlefield: a click on a stack rests one for mana, and a resource with a Rest ability opens the card view with "Rest for mana" and the ability as actions, so the tray's Resources section goes. Every action shows inactive, with its cost and the reason, when the latest `plan.checked` snapshot says it doesn't apply: `payable` (T-195), `usable`, `charged`, `rested`, `unlocked`; nothing else disables (D29). The human asked for both after the 2026-11-05 playtest: resources used from the grid, and an action the mana can't pay shown inactive instead of refused after the click.

## Interfaces

What exists (copied on 2026-11-05; the wave-39 and wave-40 cards change some of it):

```tsx
// apps/web/src/match/planning/ResourceEntry.tsx (after T-197: no attach)
// :45-:53 the "Mana" button, aria-label planning.resource.restForMana "Rest {name} for mana", disabled={!free || busy} → push({ action: 'restForMana', resource: resource.card })
// :54-:70 the "Use" button for resource.spell !== null → push({ action: 'useResource', resource }) or select({ kind: 'target', spec: target, action })
// en/planning.json: "resource.mana": "Mana", "resource.restForMana", "resource.floating", "resource.rested", "mana.title": "Floating mana", "mana.hint"
// apps/web/src/match/planning/Tray.tsx (after T-199): <section aria-label="Hand"> with the Leader's slot; <section aria-label="Resources"> with FloatingMana and the ResourceEntry list
// apps/web/src/match/planning/FloatingMana.tsx:47 FloatingMana({ resources }) — one pip per floating resource
// apps/web/src/match/planning/draft.ts:91 REJECT_TEXT, 'unaffordable': "Not enough mana: rest resources first" (T-182's text)
// apps/web/src/match/planning/draft.ts:32 planView(state): state.checked?.snapshot ?? state.snapshot  — the projected snapshot (D29)

// apps/web/src/match/MatchScreen.tsx
// :170 stripSubject(pick, state, cards, piles): a pool stack's click → { kind: 'card', card, caption: "Your pool" / "…, rested" / "…, ×N" }
// :291-:296 onPick → subjectOf → cardView.show(subject); :361 planPools={pools} (the viewer's pool with its planned rests, D57)
// apps/web/src/match/battlefield/pick.ts:23 pool: { seat: Seat; cards: readonly PoolCard[] } | null  (on the "+N" spot, every card it stands for)
// apps/web/src/match/battlefield/pools.ts:72 poolStacks groups a pool by card and state (rested or not, after T-197)
// packages/protocol/src/snapshot.ts:223 PoolResource { card, cardId, gives, rested, floating, spell: SpellClass | null, target? } (a Rest ability costs no mana, so `rested` says whether it can be used; attachedTo gone after T-200)
// packages/protocol/src/snapshot.ts:146 AbilityUse { ability, cost, rest, spell, target?, usable (+ payable after T-195) }
// HandCard.payable and LeaderCard.payable (T-195); SquadSnapshot: unlocked, level, rested, charged, levelUpCost (own squads only),
//   levelUpPayable and chargePayable (T-195); all required since T-200 but levelUpCost (docs/PROTOCOL.md › Snapshot)
// apps/web/src/match/CardView.tsx (after T-199): the 'card' subject's actions column; planning/SquadActions, PermanentActions, HandCardActions
// apps/web/src/match/planning/PlanGrid.tsx (after T-197) chargeOf(): 'charged' from squad.charged, 'ready' from the floating mana count
```

Tests today: `Tray.test.tsx` ("shows the hand, the resources …", "opens the card view from a hand tile and from a resource tile"), `PlanningPanel.test.tsx` :419 (resources dimmed), `PlanningActions.test.tsx` (Use on a resource, abilities "cannot be used"), `CardView.test.tsx` (the actions column, T-199), `MatchScreen.test.tsx` (a strip click opens the card view).

## Deliverables

1. **Resting from the strip.** While planning, a click on a stack of the viewer's own pool (`pick.pool` with `seat === state.seat`) rests one unrested, non-floating resource of that stack for mana (`restForMana` through `push`) when its card has no Rest ability; a stack whose card has a Rest ability (`spell !== null`) opens the card view instead, with "Rest for mana" and "Use" (the ability, with its target picking as today) in the actions column. Outside Plan, and for every other seat's pool, a click opens the card view as today. The planned rests already show on the strip (`planPools`): no extra drawing. The hidden "Pools and piles" list says what a click does ("click to rest for mana") only if that's cheap; otherwise leave it.
2. **The Resources section goes.** The Tray keeps the Hand with the Leader's slot (T-199) and the floating mana row (`FloatingMana`), which moves into the planning panel or stays at the tray's left: pick what keeps the tray one row high. `ResourceEntry.tsx` and its tests go, or shrink to the action list the card view renders for a resource (`ResourceActions`).
3. **Inactive actions (D72).** Every action control reads the projected snapshot (`planView`) and renders inactive when a fact says it doesn't apply: a hand card the floating mana doesn't pay (`payable: false`), a level-up or a charge not payable, an ability with `usable: false` or `payable: false`, a resource's Rest ability when the resource is rested, a squad's rest-ability when the squad is rested. Inactive means `aria-disabled="true"` (not `disabled`, so it stays focusable and readable), the cost still shown, and the reason as the control's accessible description: "Not enough mana: rest resources first" (`payable`), "Rested" (`rested`), "Used this round" / "Not usable now" (`usable`), "Already charged" (`charged`), "Not unlocked yet" (`unlocked`), and the same words in a visible hint beside it. A click on an inactive control does nothing. Nothing else disables: no room checks, no target checks (D29). `state.checking` keeps disabling everything briefly, as today. Hand tiles in the tray dim and get the same description when not payable. PlanGrid's `'ready'` Charge glow reads `chargePayable` instead of counting the floating mana.
4. **The rejected-action marks stay** (T-190): a plan can still be refused by core (a rule the snapshot doesn't state), and the mark on the card shows it.
5. **Tests.** `MatchScreen.test.tsx` (or a new `strip.test.tsx` in `match/`): a click on the viewer's stack while planning sends a plan with `restForMana` for one card of that stack; a second click rests the next one; a click on a rested-only stack sends nothing and opens the card view; a stack with a Rest ability opens the card view with both actions; another seat's stack only opens the view; outside Plan only the view. `CardView.test.tsx`: the resource actions; each inactive state from its fact, with the description text; after `plan.checked` shows the resource rested, its Use is inactive. `Tray.test.tsx`: no Resources section; a hand tile not payable is dimmed and described. `PlanningActions.test.tsx`: the inactive reasons for level-up, charge and abilities. Fixtures: the planning snapshots gain the T-195 fields (`payable`) with a mix of true and false.
6. **Docs.** `apps/web/README.md` › Rules a change must keep: "Legality is core's" names `payable` among the facts, and says inactive controls carry the reason.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test` passes.
- [ ] `pnpm test` passes.
- [ ] `grep -rn "aria-label=\"Resources\"" apps/web/src/match` finds nothing.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Core and the protocol: T-195 added `payable` and pinned with tests that core refuses a rested permanent's ability; T-200 removed attach and Durability. If a fact you need is missing from the snapshot, say so in the PR rather than working it out in the web (D29).
- The Chaos factor, Unique cards and the new cards: other cards of this batch.

## Notes

- The resting click picks the resource to rest: the first unrested, non-floating card of the stack in pool order (`pick.pool.cards`), so repeated clicks walk through the stack. A stack is one card id in one state, so every card in it gives the same mana.
- Why `aria-disabled` and not `disabled`: a disabled button can't be focused or read, and the player needs to learn why an action is off (WCAG: the reason next to the control). The `Button` in `theme/` may need an `inactive` prop; add it there if `theme.css` must change (it's in `apps/web/src/theme/`, outside this scope: say so and keep the style local to `match/` if you can).
- "Rest for mana" from the card view and from the strip send the same `restForMana`; the floating mana row updates from `plan.checked`'s snapshot (`floating: true`).
- The human's bug from the playtest, "already rested permanents can cast an ability that rests them": core refuses it (packages/core/src/plan/abilities.ts:50 rejects a rested squad's rest ability and a rested artifact's abilities, and the projected snapshot's `usable` is false for them: T-195 pinned both with tests). The UI's job here is to show the ability inactive from that projected `usable`/`rested`, and to read `planView`, never the round's first snapshot.
- Keep clicks on the strip single-pointer and keyboard-reachable: the hidden "Pools and piles" list can carry buttons for the viewer's stacks while planning, so a keyboard user can rest for mana too (the battlefield canvas has no focusable cells).
