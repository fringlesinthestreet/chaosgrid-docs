---
id: T-190
title: Every seat's piles on its strip
milestone: M5
depends_on: [T-185, T-188]
branch: agent/T-190-every-seat-s-piles-on-its-strip
model: sonnet
effort: high
scope:
  - apps/web/src/match/battlefield/pools.ts
  - apps/web/src/match/battlefield/pools.test.ts
  - apps/web/src/match/battlefield/scene.ts
  - apps/web/src/match/battlefield/scene.test.ts
  - apps/web/src/match/battlefield/pick.ts
  - apps/web/src/match/battlefield/pick.test.ts
  - apps/web/src/match/battlefield/units-list.ts
  - apps/web/src/match/battlefield/units-list.test.ts
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/src/match/CardView.test.tsx
  - apps/web/src/match/planning/index.tsx
  - apps/web/src/match/planning/Tray.tsx
  - apps/web/src/match/planning/Tray.test.tsx
  - apps/web/src/match/planning/ZonesPanel.tsx
  - apps/web/src/match/planning/Zones.test.tsx
  - apps/web/src/match/planning/PlanningPanel.test.tsx
  - apps/web/src/match/planning/HandEntry.tsx
  - apps/web/src/match/planning/HandEntry.test.tsx
  - apps/web/src/match/planning/ResourceEntry.tsx
  - apps/web/src/match/planning/PlanGrid.tsx
  - apps/web/src/match/planning/PlanGrid.test.tsx
  - apps/web/src/match/planning/draft.ts
  - apps/web/src/match/planning/draft.test.ts
  - apps/web/src/i18n/en/match.json
  - apps/web/src/i18n/en/planning.json
  - apps/web/src/i18n/en/battlefield.json
  - apps/web/README.md
context:
  - docs/DECISIONS.md#Decision log
  - docs/APPS.md#The match
  - docs/RULES.md#Components and setup
  - apps/web/README.md#Rules a change must keep
---

# T-190 — Every seat's piles on its strip

## Goal

D71: the battlefield shows every zone, so the planning panel stops repeating it. Each seat's strip gains its hand, as a pile of card backs with its size, and its void beside the discard pile. In the planning panel, the tray's Piles section, the Zones panel ("Discard piles and voids") and the Plan list go, and a refused action is marked on the card it concerns. The human asked for this after the 2026-11-05 playtest: the panel listed what the grid already showed, and the opponents' piles belong next to their grids.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// apps/web/src/match/battlefield/pools.ts
export const STRIP_ROWS = 4;                                   // :15
export interface PileSizes { deck: number; resourceDeck: number; discard: number; discardTop: CardId | null } // :18
export type PileName = 'deck' | 'resourceDeck' | 'discardPile'; // :25
export interface StripSources { piles?: Readonly<Record<Seat, PileSizes>>; pools?: Readonly<Record<Seat, readonly PoolCard[]>> } // :28
export interface PileSpot { pile: PileName; rect: WorldRect; countRect: WorldRect } // :43
export function stripLayout(arena: ArenaLayout, seat: ArenaSeat, pool: readonly PoolCard[]): StripLayout // :83
// :83-:103 lays out the piles: deck at col 0, resourceDeck at col PILE_COLS, discardPile at
// `Math.max(2 * PILE_COLS, cols - PILE_COLS)`, and the stacks between them with one empty column
// on each side.

// apps/web/src/match/battlefield/scene.ts
function pileCount(piles: PileSizes, pile: PileName): number   // :539
class StripView { sync(seat, layout, piles) … redraw(color, layout, piles) … drawPile({ pile, rect, countRect }, count, top, color) } // :561-:640
// :595: `const top = spot.pile === 'discardPile' ? piles.discardTop : null;`

// apps/web/src/match/battlefield/pick.ts:25
pile: { seat: Seat; pile: PileName } | null;

// apps/web/src/match/battlefield/units-list.ts:26
export function poolListItems(model: MatchModel, cards: ReadonlyMap<string, Card>, sources: StripSources = {}): string[]
// en/battlefield.json: "poolList.piles": "main deck {deck}, resource deck {resourceDeck}, discard pile {discard}"

// apps/web/src/match/MatchScreen.tsx
function pileSizes(snapshot: Snapshot | null): Readonly<Record<Seat, PileSizes>> | undefined // :143, from player.deckCount, resourceDeckCount, discardPile
function stripSubject(pick, state, cards, piles): CardViewSubject | null // :170; a 'pile' subject for deck and resourceDeck, the newest card for discardPile
// apps/web/src/match/CardView.tsx:24
| { kind: 'pile'; seat: Seat; pile: 'deck' | 'resourceDeck'; count: number };
// en/match.json: "cardView.pile": "{owner, select, you {Your} other {Seat {seat}'s}} {pile, select, …}" and "cardView.discardPile"

// packages/protocol/src/snapshot.ts:114 PlayerSnapshot: handCount, deckCount, resourceDeckCount,
// resourceCount, pool (public, D57), discardPile (public, with card/cardId/size/cost), void: CardId[] (public, oldest first)

// apps/web/src/match/planning/Tray.tsx:17 Piles({ view }) → PileRow of mainDeck, resourceDeck, discard, void (the viewer's)
// apps/web/src/match/planning/Tray.tsx:83 <section aria-label="Piles"> … en/planning.json "pile.title": "Piles"
// apps/web/src/match/planning/ZonesPanel.tsx: the other seats' discard piles and voids, en/planning.json "zones.title", "zones.asOf"
// apps/web/src/match/planning/index.tsx:250-:280 <section aria-label="Plan">: the plan list, `describeAction`, the
//   "N actions will be skipped" status and REJECT_TEXT; :281 <ZonesPanel view={view} />
// apps/web/src/match/planning/index.tsx:124
const rejected = state.checked?.rejected ?? [];
const rejectionAt = (index: number) => rejected.find((one) => one.index === index);
// apps/web/src/match/planning/draft.ts:91 export const REJECT_TEXT: Record<RejectReason, string>
// apps/web/src/match/planning/draft.ts:110 export function describeAction(action, lookup, view, plan?): string
// packages/protocol/src/event.ts: plan.checked { rejected: PlanRejection[]; snapshot }, PlanRejection { index, reason }
```

The tests that cover today's behaviour: `Tray.test.tsx` ("shows the four piles folded", "unfolds the discard pile"), `Zones.test.tsx` ("folds another seat's piles", "keeps a rejected action in the list, struck through"), `PlanningPanel.test.tsx` ("strikes a rejected action through with its reason", "says how many actions will be skipped", "opens the card view from the Leader tile and from a Plan line"), `pools.test.ts`, `units-list.test.ts`, `CardView.test.tsx` › "a strip's piles".

## Deliverables

1. **The strips show every zone.** `PileName` gains `'hand'` and `'void'`, `PileSizes` gains `hand: number`, `void: number` and `voidTop: CardId | null`, and `pileSizes` in MatchScreen fills them from `handCount` and `void`. `stripLayout` places, from the player's left: main deck, resource deck, hand, then the pool's stacks, then the discard pile and the void at the right end; the stacks get the columns between, still with one empty column on each side. The hand draws as card backs with its count under it, like the decks; the void draws like the discard pile, its newest card on top (`voidTop`), empty when there is none. The viewer's own hand pile shows its size too.
2. **A click on them opens the card view.** `stripSubject` gives the hand a `'pile'` subject (`pile: 'hand'`, the texts in `cardView.pile`) and the void its newest card with a `cardView.void` caption ("Your void, 3 cards" / "Seat 2's void, …"), like the discard pile. `pick.ts` needs no new logic beyond the new names.
3. **The hidden list says the same.** `poolListItems` names the hand and the void in `poolList.piles` ("main deck 87, resource deck 24, hand 6, discard pile 12, void 1").
4. **The planning panel stops repeating the battlefield.** The Tray's Piles section and its `Piles` helper go; `ZonesPanel.tsx` is deleted with its texts (`planning.zones.*`, and `planning.pile.*` where nothing uses them any more); the Plan section goes with `describeAction` if nothing else uses it (check `Zones.test.tsx`'s copy picker first: it may describe actions; keep what it needs). `RulesBar` stays in the panel.
5. **Rejections show on their card.** A refused action (`state.checked.rejected`) marks what it concerns: the hand entry whose `card` it names (`castUnit`, `castPermanent`, `castSpell`), the squad or permanent block in `PlanGrid` (`levelUp`, `useAbility`, `castLeader`/`moveLeader` on the Leader's block), the resource entry (`restForMana`, `useResource`). The mark is a `data-rejected="<reason>"` attribute, a visible sign (the error color of `cg-error`) and the reason from `REJECT_TEXT` as the element's accessible description (`aria-describedby` on the tile's button, or in the block's label). One `role="status"` line in the panel keeps "N actions will be skipped" so the player hears it. The mapping lives in `draft.ts` as a pure function `rejectionsByCard(plan, rejected): Map<CardInstanceId | SquadId | PermanentId, RejectReason>`, tested there.
6. **Tests.** `pools.test.ts`: the hand pile and the void in the layout, for the bottom and a turned seat. `scene.test.ts`: a strip draws the hand's backs and count, and the void's top card. `units-list.test.ts`: the new line. `CardView.test.tsx`: the hand pile's subject and the void's newest card. `Tray.test.tsx`: no Piles section. `PlanningPanel.test.tsx`: no Plan section and no Zones; a rejected `castUnit` marks its hand entry with the reason; a rejected `levelUp` marks the squad's block; the status line counts the skipped actions. `Zones.test.tsx`: the revive and copy pickers still work without the panel (move the zone-panel tests out or delete them with the panel). `draft.test.ts`: `rejectionsByCard`.
7. **Docs.** `apps/web/README.md` › How a match flows step 4 says the panel marks the refused actions on their cards. (`docs/APPS.md` › The match already describes the strips and the planning surface; don't edit it.)

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test pools scene units-list pick CardView MatchScreen Tray Zones PlanningPanel HandEntry PlanGrid draft` passes.
- [ ] `pnpm test` passes.
- [ ] `grep -rn "zones\." apps/web/src/i18n/en/planning.json` finds nothing, and `apps/web/src/match/planning/ZonesPanel.tsx` is gone.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Acting on the strip (rest for mana from a click on a resource): T-202.
- The Leader's slot in the tray and the actions in the card view: T-199.
- Durability badges: T-194. The model's durability fields: T-200.
- Core and the protocol: everything this card shows is in the snapshot already (D57).

## Notes

- The hand's count: `handCount` is the latest snapshot's, so during Plan another seat's hand shows as it was when Plan began (RULES.md › Zones), like its pool. The viewer's own hand pile follows `planView` through `MatchScreen`'s `piles`: pass the planning view's counts for the viewer while planning, as `planPools` does for pools.
- Layout: a grid is 30 columns; five 2-column piles plus two empty columns leave 18 columns for stacks, enough for 9 stacks of 2 × 2 a row. Keep `stripLayout`'s fallback to 1 × 1 cells and the "+N" spot as they are.
- The void's top card is a `CardId` (`void: CardId[]`), so the card view shows the card data, no instance.
- T-185 (wave 36) changed PlanGrid's blocks (no names on the icons) and T-188 MatchScreen's TopBar: rebase on main before you start and build on their versions.
- `Zones.test.tsx` tests the revive and copy pickers through the plan list ("keeps a rejected action in the list, struck through" at :239). Those pickers stay; only the list goes. A copy's choices come from the draft, not from the list.
