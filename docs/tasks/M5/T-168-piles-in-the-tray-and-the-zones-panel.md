---
id: T-168
title: Piles in the tray and the zones panel
milestone: M5
depends_on: [T-152, T-158, T-160]
branch: agent/T-168-piles-in-the-tray-and-the-zones-panel
model: sonnet
effort: medium
scope:
  - apps/web/src/match/planning/Pile.tsx
  - apps/web/src/match/planning/Pile.test.tsx
  - apps/web/src/match/planning/Tray.tsx
  - apps/web/src/match/planning/Tray.test.tsx
  - apps/web/src/match/planning/ZonesPanel.tsx
  - apps/web/src/match/planning/Zones.test.tsx
  - apps/web/src/theme/theme.css
  - apps/web/src/i18n/en/planning.json
context:
  - docs/ART.md#Stills
  - apps/web/README.md#Text (D50)
  - apps/web/README.md#Tests
---

# T-168 — Piles in the tray and the zones panel

## Goal

The human's playtest (2026-11-04): "discard pile is not that important: should be shown as a different section: deck/discard/void piles and only expand when focused/clicked. When unfocused should be shown as piled up cards."

Today the tray gives the viewer's discard pile a section of its own, with every card in it, and the zones panel lists each seat's discard pile and void card by card. After this task the tray has one Piles section: the main deck, the resource deck, the discard pile and the void, each drawn as a pile of cards with its count, all collapsed until clicked. The zones panel shows the other seats' discard piles and voids the same way.

## Interfaces

What exists (copied on 2026-11-04, and from the T-152, T-158 and T-160 cards):

```tsx
// apps/web/src/match/planning/Tray.tsx: sections "Hand", "Resources" (T-158 adds floating mana to
// it) and "Discard pile" (<DiscardPile view={view} />).
// apps/web/src/match/planning/ZonesPanel.tsx: "Discard piles and voids", one <details> per seat, the
// viewer's own open: another seat's discard pile ("As of the start of Plan") and every seat's void.
// T-152: each pile is an <ol reversed> of CardTile, newest first, whose button opens the card view
// with the pile's caption.

// The snapshot: PlayerSnapshot { deckCount, resourceDeckCount, discardPile: { card, cardId, size, cost }[],
// void: CardId[] }, for every seat. Others' are as Plan opened, before its draws (D57, T-157).
// T-152: CardTile, the small face, 112×154 px. T-160: CardBack({ width, height }) from apps/web/src/art,
// whose 112×154 box draws the small back ×7.
```

## Deliverables

1. **`Pile`**, in `planning/Pile.tsx`: a pile of cards in the small face's box, with its name and count under it.
   - A hidden pile, a deck, draws `CardBack`. A public pile draws its newest card's small face on top.
   - Under the top card, one more card shows from 2 cards and two more from 6, each offset 3 px up and to the right, so the pile looks thicker as it grows. An empty pile draws its outline and "0".
   - A public pile is a button with `aria-expanded`. A click lists its cards as tiles, newest first, and opens each in the card view as today; another click folds it. A deck isn't a button: its cards are hidden.
2. **The tray's Piles section** replaces "Discard pile". It holds four piles: the main deck, the resource deck, the discard pile and the viewer's void. All start folded, and an open one lists its tiles under the row.
3. **The zones panel** lists the other seats only, each with its discard pile and void as folded piles. "As of the start of Plan" stays. The viewer's void has moved to the tray.
4. **Text** in `en/planning.json`: "Piles", "Main deck", "Resource deck", "Discard pile", "Void", and a count with an ICU plural. Show and hide labels name the pile.
5. **Tests:**
   - `Pile.test.tsx`: a deck shows a back and its count, and isn't a button. A public pile is folded, a click lists its tiles newest first, and a second click folds it. The thickness follows the count, and an empty pile shows 0.
   - `Tray.test.tsx`: the four piles, folded, with the snapshot's counts. The old Discard pile section is gone.
   - `Zones.test.tsx`: another seat's discard pile folds and opens. The viewer's seat isn't listed.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test Pile Tray Zones` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `pnpm test:e2e` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The piles behind each grid on the battlefield: T-161.
- Discarding during Cleanup's Discard step (`DiscardHand`): it keeps its own view.

## Notes

- Defaults: the resource deck is a pile too, since its size is public (D57), and the request's "deck" covers both. Every pile starts folded, every round.
