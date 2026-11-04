---
id: T-152
title: One card face in three sizes
milestone: M5
depends_on: []
branch: agent/T-152-one-card-face-in-three-sizes
model: opus
effort: high
scope:
  - apps/web/src/cards/CardFace.tsx
  - apps/web/src/cards/CardFace.test.tsx
  - apps/web/src/cards/face.css
  - apps/web/src/cards/CardTile.tsx
  - apps/web/src/cards/CardDetail.tsx
  - apps/web/src/cards/CardsPage.tsx
  - apps/web/src/cards/index.tsx
  - apps/web/src/cards/cards.test.tsx
  - apps/web/src/decks/editor/DeckEditorPage.tsx
  - apps/web/src/decks/editor/editor.test.tsx
  - apps/web/src/match/CardView.tsx
  - apps/web/src/match/CardView.test.tsx
  - apps/web/src/match/planning/ZonesPanel.tsx
  - apps/web/src/match/planning/Zones.test.tsx
  - apps/web/src/i18n/en/cards.json
  - apps/web/src/theme/palette.ts
  - apps/web/src/theme/palette.test.ts
  - apps/web/src/theme/theme.css
  - apps/web/README.md
  - docs/APPS.md
  - docs/ART.md
context:
  - apps/web/README.md#Text
  - apps/web/README.md#Tests
  - apps/web/README.md#Rules a change must keep
  - docs/ART.md#Stills
  - docs/RULES.md#Units
  - docs/RULES.md#Non-unit permanents and spells
---

# T-152 — One card face in three sizes

## Goal

The card browser, the deck editor, the hand, the resource pool, the discard piles and the match's card view each draw a card as a plain box: the art, the name, "unit · cost 3", a list of numbers. The human wants cards to look like cards (2026-11-04), in the style of a Magic: The Gathering card face: a frame in the card's color, the name on top with the cost at its right, the art under it, a type line, the rules text, and the combat numbers in a box at the bottom right, with the Durability at the bottom left. Each card type shows only what it has: an artifact has no Attack or HP.

After this task one component, `CardFace`, draws every card in the DOM, in three sizes, and every page that shows a card uses it: tiles are small faces, the browser's and the editor's detail is a medium face, and the match's card view a large one. A place that shows a card never composes its fields again.

## Interfaces

What exists (copied on 2026-11-04):

```ts
// packages/cards/src/schema.ts: the Card union, by `type`. Numbers are in the card text's units.
// Every type has id, name, type, cost, text and abilities. A cost is a string: the generic number,
// then one letter per colored pip, "2RR"; a free card costs "0". Resources and Chaos cards always
// cost "0". Units, Leaders, spells, traps, artifacts and enchantments may carry `colorless: true`;
// units, traps, artifacts and enchantments `unique: true`.
unit:        stats: { hp, attack, attackSpeed, speed, range: 'melee' | 'ranged' | 'artillery', charge },
             size: [w, h], squad (units per squad), keywords: Record<Keyword, true | undefined>,
             durability, levelUnlock
leader:      the same, plus leaderBonus; durability is optional
spell:       spell: 'utility' | 'defensive' | 'offensive'
trap:        mode: 'freeStanding', area: [w, h], trigger; durability optional
artifact, enchantment: mode: 'attached' (no area) | 'freeStanding' with area: [w, h]; durability optional
resource:    colors: Color[], gives: 'any' | Color[] ([] is one colorless pip)
chaos:       tier: 1 | 2 | 3, amount, and by `kind`: 'units' (stats without charge, size, squad,
             keywords, points, spawn), 'emblem' (points, durability), 'rule', 'nothing'

// @chaosgrid/cards (cost.ts, colors.ts, deck/check.ts, values.ts)
export const COLORS = ['R', 'T', 'E', 'D', 'L'] as const;   // Ember, Tide, Earth, Dark, Light
export function parseCost(cost: string): { generic: number; colors: Record<Color, number> };
export function cardColor(card: Card): Color[];   // [] for a colorless card and for every Chaos card
export function isUnique(card: Card): boolean;
export const KEYWORDS: readonly Keyword[];        // the keywords' order

// apps/web/src/art/CardArt.tsx: the key's still at the largest whole multiple that fits `size`,
// centred, else its placeholder. Decorative: wherever it shows, the card's name shows too.
export function CardArt({ cardId, size }: { cardId: string; size: number }): JSX.Element;

// apps/web/src/cards/CardTile.tsx, used by CardsPage (the images view), DeckEditorPage (the pool,
// with count and disabled), HandEntry, ResourceEntry, Tray (the viewer's discard pile) and
// planning/index.tsx (the Leader). Today a <button> (a <div> when not clickable) holding CardArt
// at 48, the name, "cost · type", the count badge (aria-label "{count} copies") and the disabled
// reason. The tests click it by a name regex: getByRole('button', { name: /^Candle Bearer/ }).
export function CardTile(props: { card: Card; count?: number; onClick?: () => void; disabled?: string });

// apps/web/src/cards/CardDetail.tsx, used by CardsPage and DeckEditorPage (size 'normal', art 96)
// and match/CardView.tsx (size 'large', art 192): <article className="cg-card-detail"
// aria-label={card.name}> with the name, "type · cost", the colors, Unique, the text and a <dl>
// of the numbers. The tests find it with getByRole('article', { name }) (cards.test.tsx,
// editor.test.tsx, e2e/m4.spec.ts) and getByLabelText(name, { selector: 'article' })
// (CardView.test.tsx). No CSS names .cg-card-detail or .cg-tile today.
export function CardDetail({ card, size = 'normal' }: { card: Card; size?: 'normal' | 'large' });

// apps/web/src/theme/palette.ts: COLORS (seat-0 … seat-3, chaos, warning, muted, bg, panel,
// border, text, error) gives PALETTE, for Pixi, and CSS_VARIABLES, --cg-<name>, which
// applyPalette() sets on :root. theme.css: --cg-font-pixel (Press Start 2P, used by h1 to h3,
// .cg-pixel and .cg-button) and --cg-font-body; .cg-panel, .cg-button, .cg-dimmed; .cg-tray-row
// (a row that scrolls sideways) and .cg-tray-entry; .cg-card-view is 360 px wide and scrolls.

// apps/web/src/i18n: t(id, values?), ids '<namespace>.<key>'. en/cards.json already has
// type.<type> ("Unit", …), color.<R|T|E|D|L|multicolor|colorless> ("Ember", …, "Multicolor",
// "Colorless"), keyword.<keyword>, range.<range> and spellClass.<class>.

// apps/web/src/match/planning/ZonesPanel.tsx: every other seat's discard pile and void, and the
// viewer's own void, each an <ol reversed> of <Button>s named by the card, newest first, that
// open the card view with the caption "You" or "Seat N". The viewer's own discard pile is the
// tray's (Tray.tsx), a .cg-tray-row of CardTiles.

// apps/web/src/cards/cards.test.tsx loads real cards with loadCards() from @chaosgrid/cards/node.
```

What this task adds:

```ts
// apps/web/src/cards/CardFace.tsx
export type FaceSize = 'small' | 'medium' | 'large';
/** One card drawn as a card: the frame in its color, the name and cost, the art, the type line, the text and the numbers. */
export function CardFace({ card, size }: { card: Card; size: FaceSize }): JSX.Element;
```

`cards/index.tsx` exports `CardFace` and `FaceSize` in place of `CardDetail`.

## Deliverables

1. **`CardFace`**, in `cards/CardFace.tsx`, its CSS in `cards/face.css` (imported by the component, as `CardsPage.tsx` imports `cards.css`). The root carries `data-card-face={card.id}`, `data-face-size` and `data-face-color`. Top to bottom:
   - **The name bar:** the name at the left, in the pixel font, cut with an ellipsis when it doesn't fit (the full name is the article's label, or the tile button's name). The cost at the right as pips: the generic number in a grey pip, then one pip per colored pip in `COLORS` order, each a disc in its color with the color's letter in it; a cost of "0" is one grey "0" pip. Resources and Chaos cards show no cost. The cost's accessible text is `t('cards.face.cost', { cost })`, "Cost {cost}".
   - **The art:** `CardArt` in a window the face's inner width, so the still draws at the largest whole multiple that fits, centred on a dark backdrop. Units, Leaders and Chaos units with a squad of more than one carry a badge on the window's corner, "×{squad}", with the accessible text `t('cards.face.squad', { squad })`, "Squad {squad}".
   - **The type line:** "Unique" when `isUnique(card)`, the color word, the type, and what the type adds (the table below). The color word is the one color's name, "Multicolor" for several, "Colorless" for none; a Chaos card has no color word.
   - **The text box** (medium and large only): a keywords line for units and Leaders (the keywords that are `true`, named from `cards.keyword.*`, in `KEYWORDS` order, comma-separated), then `card.text`, in the body font.
   - **The stats** (medium and large only): a `<dl>` with visible labels, per the table.
   - **The bottom row:** the Durability in a box at the left when the card has one, and the combat box at the right, per the table. Every number carries its label for assistive tech, visible or `.cg-visually-hidden`: "Durability", "Attack", "HP".

   | Type | The type line adds | Stats (medium, large) | Bottom left | Bottom right |
   | --- | --- | --- | --- | --- |
   | unit | — | Attack speed, Speed, Range, Charge | Durability | Attack/HP |
   | leader | — | Attack speed, Speed, Range, Charge, Leader bonus | Durability, when the card has one | Attack/HP |
   | spell | its class | — | — | — |
   | trap | its area, "{w}×{h}" | — | Durability, when the card has one | — |
   | artifact, enchantment | "Attached", or "Free-standing {w}×{h}" | — | Durability, when the card has one | — |
   | resource | — | — | — | what it gives: its pips, "Any" for `'any'`, one grey pip for `[]`; the accessible text "Gives {colors}" |
   | chaos | "Tier {tier} · {kind}" | units: Attack speed, Speed, Range, Points, Amount; emblem: Points, Amount; rule, nothing: Amount | emblem: Durability | units: Attack/HP |

   The frame's color: `data-face-color` is the one color's name (`ember`, `tide`, `earth`, `dark`, `light`), `gold` for several, `grey` for none and `chaos` for a Chaos card; `face.css` colors the border, the name bar and the type line from it. Nothing depends on the color alone: the type line says it, and the pips carry their letters.

2. **Three sizes**, `data-face-size`. The small face is a `<div>`; the medium and the large one are `<article aria-label={card.name}>`, as `CardDetail` is today, so a page that shows tiles and a detail has one article per card. The defaults below are a starting point: the worker tunes them by a few pixels as the fonts need, and the face grows with its text (the panels that hold a medium or large face scroll already).

   | Size | Width | Art (about) | Name | Shows |
   | --- | --- | --- | --- | --- |
   | small | 112 px | ×3, 96 px | pixel font 8 px | the name bar, the art, the type line, the bottom row |
   | medium | 192 px | ×5, 160 px | pixel font 10 px | everything, body text 12 px |
   | large | 320 px | ×9, 288 px | pixel font 12 px | everything, body text 14 px |

3. **Color tokens** in `theme/palette.ts`' `COLORS`: `'card-ember': 0xc9452e`, `'card-tide': 0x2f7fd1`, `'card-earth': 0x3f9a4a`, `'card-dark': 0x6c5a8c`, `'card-light': 0xe8dcb0`, `'card-gold': 0xd4a017`, `'card-grey': 0x8a90a0`; a Chaos frame uses `--cg-chaos`. They reach CSS as `--cg-card-ember` and so on through `CSS_VARIABLES`; `PALETTE` stays as it is, since Pixi draws no card colors yet. The worker may pick other values that keep each frame at 3:1 against `--cg-panel` and apart from the others. `palette.test.ts` checks the new properties as it checks `--cg-chaos`. A `.cg-visually-hidden` utility goes in `theme.css`.

4. **`CardTile`** keeps its props and becomes `<div className="cg-tile">` holding the small face, the count badge and the disabled reason as today, and, when `onClick` is given and the tile isn't disabled, a `<button type="button" aria-label={card.name}>` laid over the face: positioned over the whole tile, transparent, with a visible focus ring. The markup stays valid (a button holds no block content), and the tests' `getByRole('button', { name: /^Candle Bearer/ })` keep finding it. `cg-dimmed` when disabled, as today. The tray's hand, resources, discard pile and Leader, the browser's images view and the editor's pool get faces through it with no change of their own.

5. **`CardDetail` goes.** `CardsPage.tsx` and `DeckEditorPage.tsx` render `<CardFace card={selected} size="medium" />` where they rendered `CardDetail`, and `CardView.tsx` `<CardFace card={shown} size="large" />`.

6. **The Zones panel's piles** list tiles: each pile's `<ol reversed>` holds a `CardTile` per card in a wrapping row, newest first as now, each opening the card view with the same caption. A card the session doesn't know still shows its id.

7. **Text** in `en/cards.json`, under `face.*`: `face.cost` "Cost {cost}", `face.squad` "Squad {squad}", `face.unique` "Unique", `face.attack` "Attack", `face.hp` "HP", `face.attackSpeed` "Attack speed", `face.speed` "Speed", `face.range` "Range", `face.charge` "Charge", `face.leaderBonus` "Leader bonus", `face.durability` "Durability", `face.points` "Points", `face.amount` "Amount", `face.tier` "Tier {tier}", `face.attached` "Attached", `face.freeStanding` "Free-standing {w}×{h}", `face.area` "{w}×{h}", `face.gives` "Gives {colors}", `face.givesAny` "Any", `face.chaosKind.<kind>` ("Units", "Emblem", "Rule", "Nothing"). The type, color, keyword, range and spell class words are the existing keys.

8. **Docs:** `apps/web/README.md` › Folders (`cards/` owns `CardFace` and `CardTile`, not `CardDetail`) and › Rules a change must keep (a bullet: a card in the DOM is always a `CardFace`, through `CardTile` when it's clickable; a page never composes a card's fields); `docs/ART.md` › Stills, the rows of the boxes table for the card view, the card tiles and the resource pool, with the faces' art boxes; `docs/APPS.md` › Web layout and ownership, where `cards/`'s line gains `T-152 CardFace`.

9. **Tests**, finding text by its English:
   - `cards/CardFace.test.tsx`, with real cards from `loadCards()` as `cards.test.tsx` does: the small face shows the name, the cost's accessible text, the type line and the bottom row, and no text box; the medium face adds the keywords line, the text and the stats; an artifact shows no Attack, HP or squad badge; a resource shows what it gives and no cost; a Chaos emblem shows Points and Durability; `data-face-color` for a one-color, a two-color, a colorless and a Chaos card; a two-pip cost renders two pips in order.
   - `cards.test.tsx` › CardTile: as today, plus: the button is named by the card alone, and a tile without `onClick` has no button.
   - `editor.test.tsx`: `tile()` finds a tile by its button's name and climbs to `.cg-tile`.
   - `Zones.test.tsx`: a pile's entries are tiles, newest first, whose button opens the card view with the caption.
   - `CardView.test.tsx`: the view shows a large face (`article`, `data-face-size="large"`).

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test cards editor Zones CardView Tray PlanningPanel palette` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `pnpm test:e2e` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The deck list's tiles (T-126: the Leader at 96 px, the key cards at 32 px), the lobby's deck, the deck panel's list (names with counts and +/−), quick add's candidates and the browser's list and table views: they keep what they show. A later card may put small faces there.
- `HandEntry`'s line under the tile (the live cost and a spell's timing) and `ResourceEntry`'s state words stay.
- A card's back (`ui.cardBack`) for face-down cards, a hover or long-press preview of the large face, the current stats against the printed ones in the match (PLAN.md › M5, combat readability), level unlocks and bot stats on the face, and icons for the stats: later cards.
- The battlefield: Pixi draws no faces.

## Notes

- Defaults: the request named "trophies"; there's no such card type. Prizes and Emblems aren't cards (the card view's `PrizeSubject` stays), and a Chaos Emblem is a Chaos card. The eight types are unit, leader, spell, trap, artifact, enchantment, resource and chaos.
- The look: a Magic: The Gathering face in pixel style. Hard edges, corners rounded 2 px at most, no shadows or gradients. The pixel font at 8 px is the smallest text; the rules text uses the body font. Text on the colored bars keeps 4.5:1: tint the bars with the frame color over `--cg-panel` (`color-mix()` is fine: the e2e runs Chromium, and Vite's target allows it) rather than filling them with it.
- The face takes a `Card` only. What the match knows about an instance (level, current HP, rested, attached) stays in the captions and panels around it.
- A unit with `squad` 1 has no badge. A Leader's squad is usually 1.
- The PR says which keys it added to `en/cards.json` and names the sizes it settled on.
