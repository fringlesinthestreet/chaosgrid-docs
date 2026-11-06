---
id: T-192
title: Live stats on the card face
milestone: M5
depends_on: [T-189, T-190]
branch: agent/T-192-live-stats-on-the-card-face
model: sonnet
effort: medium
scope:
  - apps/web/src/cards/CardFace.tsx
  - apps/web/src/cards/CardFace.test.tsx
  - apps/web/src/cards/face.css
  - apps/web/src/cards/index.tsx
  - apps/web/src/match/CardView.tsx
  - apps/web/src/match/CardView.test.tsx
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/src/i18n/en/match.json
  - apps/web/src/i18n/en/cards.json
  - apps/web/test/fixtures/planning/*.json
context:
  - docs/APPS.md#The match
  - apps/web/README.md#Rules a change must keep
  - apps/web/README.md#Text (D50)
---

# T-192 — Live stats on the card face

## Goal

The card view shows a unit's current numbers where the printed ones are, on the card face itself, instead of the "Now" section under it (T-171). A changed value is marked the way a changed cost is (T-169, T-177), with the printed value in the accessible text. The human asked for it after the 2026-11-05 playtest: "show current stats where the static stats are on the card, no extra section".

## Interfaces

What exists (copied on 2026-11-05):

```tsx
// apps/web/src/cards/CardFace.tsx
export type FaceSize = 'small' | 'medium' | 'large';                // :18
/** The cost core charges now, marked when it isn't the printed one (T-169). */
function FaceCost({ card, cost }: { card: Card; cost: string | undefined }) { // :63
  if (card.type === 'resource' || card.type === 'chaos') return null;
  if (cost === undefined || cost === card.cost) return <CostPips cost={card.cost} />;
  const change = totalPips(cost) < totalPips(card.cost) ? 'lower' : 'higher';
  return (
    <span className="cg-face-cost-changed" data-cost-changed={change}>
      <span aria-hidden="true">{change === 'lower' ? '▼' : '▲'}</span>
      <CostPips cost={cost} label={t('cards.face.costPrinted', { cost, printed: card.cost })} />
    </span>
  );
}
type Stat = readonly [label: string, value: string | number];        // :145
function movement(stats: { attackSpeed: number; speed: number; range: Range }): Stat[] // :147: attackSpeed, speed, range
function statList(card: Card): Stat[]                                // :155: unit → movement + charge; leader → + leaderBonus; chaos …
function BottomRow({ card }: { card: Card })                         // :194: the Attack/HP box (`cg-face-combat`), gives
export function CardFace({ card, size, cost }: { card: Card; size: FaceSize; cost?: string }) // :226
// :239 const stats = full ? statList(card) : [];  :261 <dl className="cg-face-stats">
// face.css:288 .cg-face-cost-changed { … }  (the marked cost's style, T-177)
// en/cards.json: "face.costPrinted": "Cost {cost}, printed {printed}", "face.attack", "face.hp", "face.attackSpeed", "face.speed", "face.range", "face.charge"

// apps/web/src/match/CardView.tsx
export type CardViewSubject =
  | { kind: 'card'; card: Card; caption?: string; attached?: readonly Card[]; unit?: UnitId } // :22
  | { kind: 'prize'; seat: Seat; hp: number }
  | { kind: 'pile'; … };
function NowBlock({ unitId }: { unitId: UnitId })                    // :113-:173: reads state.playback.model.units[unitId]:
//   unit.alive, unit.hp, stats.maxHp, stats.attack, stats.attackSpeed, stats.speed, stats.range, stats.minRange,
//   stats.damageTaken, unit.keywords; "Dead" for a dead unit; rounds to two decimals (round2)
function CardSubject({ subject })                                    // :177: <CardFace card={shown} size="large" />, then <NowBlock unitId={subject.unit} />
// en/match.json: "cardView.now": "Now", "cardView.dead", "cardView.hp", "cardView.hpValue", "cardView.attack",
//   "cardView.attackSpeed", "cardView.perSecond", "cardView.speed", "cardView.cellsPerSecond", "cardView.range",
//   "cardView.rangeValue", "cardView.rangeMin", "cardView.damageTaken", "cardView.times", "cardView.keywords"

// apps/web/src/match/MatchScreen.tsx:236-:260 squadSubject(...) builds the 'card' subject with `unit: shownUnit`
// apps/web/src/match/model/types.ts:54 UnitModel { alive, hp, maxHp, stats: UnitStats | null, keywords: string[] | null, rested, … }
```

Tests today: `CardView.test.tsx` › "the live stats in the card view (T-171)" (:339-:430) and `CardFace.test.tsx` › "CardFace, live cost" (:118).

## Deliverables

1. **`CardFace` takes live numbers.** A new optional prop `live?: LiveStats` with `{ hp: number; maxHp: number; attack: number; attackSpeed: number; speed: number; range: number; minRange: number; damageTaken: number; keywords: readonly string[] | null; dead?: boolean }` (export the type from `CardFace.tsx` and the `cards` index). With it, the Attack/HP box and the stats list show the live values in place of the printed ones; a value that differs from the printed one is marked like a changed cost (`data-stat-changed="higher" | "lower"` on the row, the same ▲/▼ sign, the `cg-face-cost-changed` look generalised in `face.css` to a `cg-face-changed` class both use), and its accessible text says both: "Attack 6, printed 4" (`cards.face.statPrinted`). HP reads "HP 7 / 10" when hurt (`cards.face.hpValue`), range adds ", at least N" when `minRange > 0`, damage taken appears only when it isn't 1, and the keyword line shows the live keywords when given. A dead unit's face says "Dead" where the HP is (`cards.face.dead`). Without `live`, nothing changes: the cards page and the deck editor render as today.
2. **The card view passes them.** `CardSubject` builds `live` from the model's unit (what `NowBlock` reads today) and passes it to `CardFace`; the face follows the model while the view is open, as the block did. `NowBlock` and the `cardView.now`/`cardView.hp`… texts go; only `cardView.keywords` stays if something else uses it (check).
3. **Tests.** `CardFace.test.tsx`: live values in place of printed ones, marked higher and lower, the printed value in the accessible text; nothing marked when they're equal; "Dead"; no change without `live`. `CardView.test.tsx`: the T-171 block's cases move onto the face ("shows the model's values, not the card's", "adds the minimum range only when it is above 0", "follows the model while the view is open", "says a dead unit is dead", "shows no live numbers for a card with no unit", "shows damage taken only when it is not ×1"), and no "Now" section exists. `MatchScreen.test.tsx` where it looks for the Now section.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test CardFace CardView MatchScreen cards` passes.
- [ ] `pnpm test` passes.
- [ ] `grep -rn "cardView.now\|NowBlock" apps/web/src` finds nothing.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The battlefield's badges and PlanGrid's labels: T-194.
- The actions beside the card (Level up, Charge, abilities): T-199.
- Durability: since T-189 only an Emblem prints it, and the face shows it only then; don't add it for units. Charge's row stays as it is; T-197 changes it to mana.

## Notes

- Keep the face's layout stable: the live rows take the printed rows' places, so the card doesn't jump when the model updates. Mark with the sign and the attribute, never with color alone.
- The model's `UnitStats` already has `maxHp`, `attack`, `attackSpeed`, `speed`, `range`, `minRange`, `damageTaken`; keep `round2` for the two-decimal rounding.
- The printed values to compare against are the card's level-1 stats; a level-2 squad shows every scaled value as "higher", which is right: the card prints base numbers (RULES.md › Leveling).
- `CardFace` is shared with the cards page and the deck editor (T-186 and T-187 merged in wave 36): the prop is optional and nothing there passes it.
- T-194 (`scene.ts`, the panels, PlanGrid, the art keys) and T-193 (the model, the round log, `draft.ts`, `index.tsx`) run beside you in wave 38: don't touch those files.
