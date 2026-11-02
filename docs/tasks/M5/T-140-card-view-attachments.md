---
id: T-140
title: List attached cards in the card view
milestone: M5
depends_on: [T-124, T-142]
branch: agent/T-140-card-view-attachments
model: sonnet
effort: medium
scope:
  - apps/web/src/match/CardView.tsx
  - apps/web/src/match/CardView.test.tsx
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/i18n/en/match.json
  - apps/web/src/theme/theme.css
context:
  - docs/RULES.md#Non-unit permanents and spells
  - apps/web/README.md#Text
  - apps/web/README.md#Tests
---

# T-140 — List attached cards in the card view

## Goal

Equipment and auras are attached cards: each one sits on a squad and has no cell of its own (RULES › Non-unit permanents and spells), so no click on the battlefield opens one. The human asked for this on 2026-10-30: "show card details should show list, defaulting to creature or permanent that the rest is attached to, and be able to click and check the equipment and auras".

After this task a click on a unit opens a list in the card view: the unit's card first and shown, then every card attached to its squad. A click on an entry shows that card. Only squads carry attached cards, so a permanent, an Emblem or a prize still opens alone.

## Interfaces

What exists (copied from the code on 2026-10-30, and from the T-124 and T-142 cards):

```ts
// apps/web/src/match/CardView.tsx:20-22
export type CardViewSubject =
  /** `caption`: whose it is, and a unit's level. */
  { kind: 'card'; card: Card; caption?: string } | { kind: 'prize'; seat: Seat; hp: number };

// CardView.tsx:40-52, the provider: show() records the opener unless the focus is inside the
// view, and close() gives the focus back to it.
// CardView.tsx:84-120, CardView: a new subject moves the focus to Close (an effect on `subject`),
// and Escape closes it (in the capture phase from T-142). It renders:
<aside aria-label="Card view" data-card-view="" className="cg-panel cg-card-view">
  <button type="button" className="cg-button" ref={closeButton} onClick={close}>Close</button>
  {subject.kind === 'card' ? (
    <>
      {subject.caption !== undefined && <p data-card-caption="">{subject.caption}</p>}
      <CardDetail card={subject.card} size="large" />
    </>
  ) : (
    <PrizeSubject seat={subject.seat} hp={subject.hp} />
  )}
</aside>

// apps/web/src/match/MatchScreen.tsx:124-148, what a click on the battlefield opens
function subjectOf(pick: BattlefieldPick, state: SessionState, cards: MatchSession['cards']) {
  // a unit: { kind: 'card', card: cards.get(unit.cardId), caption: 'You, level 2' }, the squad's level
  // a prize: { kind: 'prize', seat, hp }; any other permanent: its card, captioned by its owner
}

// apps/web/src/match/battlefield/pick.ts: `unit` is the living unit drawn on the cell. A pick never
// holds an attached permanent: "An attached one has no cell of its own."

// apps/web/src/match/model/types.ts
export type PermanentWhere =
  | { mode: 'freeStanding'; seat: Seat; cell: Cell; rotated: boolean; size: Size }
  | { mode: 'attached'; seat: Seat; squad: SquadId }
  | { mode: 'world'; at: WorldCell };
export interface PermanentModel {
  permanent: PermanentId;
  kind: PermanentKind; // 'trap' | 'permanent' | 'emblem' | 'prize'
  owner: Owner;
  cardId: CardId | null; // null for a prize
  where: PermanentWhere;
  alive: boolean;
  // and faceDown, hp, maxHp, durability, points
}
// MatchModel.permanents: Record<PermanentId, PermanentModel>

// apps/web/src/i18n (T-124): t(id, values?), with ids '<namespace>.<key>'. The `match` namespace,
// en/match.json, owns match/'s own files: the page, MatchScreen, session and CardView.
```

`CardView.test.tsx` › "the card view on a click on the battlefield" renders MatchScreen with a stub battlefield that hands over `onPick`, then picks a unit, a permanent or a prize from a model.

Two attached cards for the tests: `artifact.whetstone` (Whetstone: "Unit gets +{unit level} Attack") and `enchantment.fire_brand` (Fire Brand: "Unit gets Trample and +1 Attack").

What this task adds: an optional list of attached cards on the card subject, one key in `en/match.json`, and a style for the entry that's shown.

## Deliverables

1. **The subject.** The card variant of `CardViewSubject` gains `attached?: readonly Card[]`: the cards attached to the unit's squad, in the order the list shows them. subjectOf fills it for a unit pick from the model's permanents with `where.mode === 'attached'`, `where.squad === unit.squad` and `alive`, in `model.permanents`' order, each by its card. It skips an unknown cardId. Every other subject stays as now, with no `attached`.
2. **The list.** When `attached` holds at least one card, CardView shows a list between the caption and the card: `<ul aria-label={t('match.cardView.squadCards')}>`, "This squad's cards", with one `<li>` per card holding a `cg-button` that shows the card's name and carries `aria-pressed`. The unit's card comes first and is pressed at open. A click on an entry presses it and shows that card's `CardDetail` in place of the unit's. The caption stays, since it describes the squad. With nothing attached there's no list, as now.
3. **The shown card is CardView's own state.** A new subject resets it to the first entry. A click on an entry doesn't call show(), because a new subject moves the focus to Close; the focus stays on the clicked button.
4. **The style.** In `theme.css`, next to `.cg-card-view`: the list wraps, and a pressed entry stands out by more than its color, by its border for example.
5. **Tests** in `CardView.test.tsx` › the card view on a click on the battlefield, with a model whose squad s1 has Whetstone and Fire Brand attached:
   - A unit pick shows the list "This squad's cards" with Candle Bearer, Whetstone and Fire Brand in that order, Candle Bearer pressed and its card shown.
   - A click on Whetstone presses it and shows Whetstone's card. Candle Bearer's card is gone, the caption stays, and the focus stays on Whetstone's button. A click on Candle Bearer shows the unit again.
   - A card attached to another squad, and a dead one, aren't listed.
   - A unit with nothing attached, and a free-standing permanent, show no list.
   - A new pick shows the new unit's card first. Escape closes the view, from an entry too.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test CardView` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `pnpm test:e2e` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- A card opened from the hand or the Zones panel: it opens alone, as now. Only the battlefield holds attached cards.
- Drawing attached cards on the battlefield, or picking one there: the list is the way to reach one.
- Attached resources and Charge: they aren't cards.
- The card view's place and size: T-136 floats it over the battlefield.

## Notes

- Defaults: a dead attached card isn't listed, since it's destroyed until Cleanup (RULES). The list keeps the model's order. Only a unit pick lists, since a permanent never carries attached cards (RULES).
- The PR says which text it added to `en/match.json`.
