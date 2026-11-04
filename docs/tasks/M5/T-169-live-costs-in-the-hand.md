---
id: T-169
title: Live costs in the hand
milestone: M5
depends_on: [T-159, T-164]
branch: agent/T-169-live-costs-in-the-hand
model: sonnet
effort: medium
scope:
  - apps/web/src/cards/CardFace.tsx
  - apps/web/src/cards/CardFace.test.tsx
  - apps/web/src/cards/CardTile.tsx
  - apps/web/src/match/planning/HandEntry.tsx
  - apps/web/src/match/planning/HandEntry.test.tsx
  - packages/cards/data/enchantments/tidal_ledger.json
  - packages/cards/data/artifacts/dark_toll.json
  - docs/RULES.md
  - apps/web/src/i18n/en/cards.json
  - apps/web/src/cards/face.css
context:
  - docs/RULES.md#Resources and attaching
  - apps/web/README.md#Tests
---

# T-169 — Live costs in the hand

## Goal

The human's playtest (2026-11-04): "abilities that reduce card costs should make the shown cost on hand reduced. e.g. tidal ledger totem reduces 1 Tide (T) but then I got rejected cast cause the resources didn't reduce when trying to play them".

The lead's diagnosis: core charges what RULES.md › Cost changes says. A cost change counts only the permanents on the grid when Plan starts, so a Tidal Ledger cast in this Plan lowers costs from the next round. With the Ledger already on the grid, the snapshot's hand cost is lowered and core accepts the cheaper cast. Two things mislead the player:

- The hand's card face shows the printed cost even when core charges less.
- The card says nothing about when its change starts.

After this task the hand's face shows the cost core charges, marked when it differs from the printed one, and the two cost-changing cards say "from the next round".

## Interfaces

What exists (copied on 2026-11-04, and from the T-152 and T-159 cards):

```tsx
// apps/web/src/match/planning/HandEntry.tsx:60-73
<CardTile card={card} onClick={() => cardView.show({ kind: 'card', card })} />
<span data-cost="">{formatCost(entry.cost)}{entry.type === 'spell' ? `, ${timingText(entry.spell)}` : ''}</span>
// entry: the snapshot's HandCard; entry.cost is the cost core charges now. formatCost is in planning/cost.ts.

// T-152: CardFace({ card, size }) draws card.cost in the name bar with CostPips({ cost }), whose
// accessible text is t('cards.face.cost', { cost }), "Cost {cost}". CardTile({ card, count?, onClick?,
// disabled? }) wraps the small face.

// packages/cards/data: tidal_ledger.json "Static: your Tide spells cost 1 less"; dark_toll.json
// "Static: opponents' Light spells cost 1 more". Both are `costChange` statics. Cards have "version".
```

## Deliverables

1. **`CardFace` takes an optional `cost`**, a cost string as card data writes it, the cost core charges now. When it differs from `card.cost`, the name bar shows it instead, marked `data-cost-changed="lower"` or `"higher"` with a visible cue that isn't color alone. Its accessible text names both, "Cost T, printed 1T". When it's absent or equal, the face is as today.
2. **`CardTile`** passes `cost` through.
3. **`HandEntry`** passes `formatCost(entry.cost)`. Its line under the tile keeps a spell's timing and drops the cost, which the face now shows.
4. **The two cards say when the change starts:** Tidal Ledger "Static: your Tide spells cost 1 less, from the next round", and Dark Toll "Static: opponents' Light spells cost 1 more, from the next round". Bump each `version`. If RULES.md's sample tables quote either text, they change with it.
5. **Tests:**
   - `HandEntry.test.tsx`: a hand card whose snapshot cost is lower than its printed one shows the lower cost, marked lower, and names both. One with an equal cost shows it unmarked, with no second cost on the line.
   - `CardFace.test.tsx`: `cost` higher than printed is marked higher, and an equal `cost` changes nothing.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm cards:validate` passes.
- [ ] `pnpm --filter @chaosgrid/web test CardFace HandEntry cards` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Applying a cost change within the Plan that casts its permanent: that changes RULES.md › Cost changes and needs the lead. Plans are hidden and apply in seat order, so an opponent's Dark Toll can't change costs mid-Plan.
- The "Can't afford it" rejection text: it stays.
- Costs elsewhere (the card browser, the deck editor): they show printed costs, which is right there.

## Notes

- Defaults: the marked cost uses `--cg-text` on an outline in the frame's color, with "▼" or "▲" before the pips.
- `formatCost` writes the protocol's `Cost` as the card files do ("2RR"), which is what `CostPips` draws.
- A cost change cuts only the generic part and never a colored pip (RULES.md › Cost changes): under Tidal Ledger a 1T spell costs T, and a TT spell stays TT. The face shows what core charges, so it follows.
