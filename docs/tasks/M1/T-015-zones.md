---
id: T-015
title: Decks, hands and resources
milestone: M1
depends_on: [T-008]
branch: agent/T-015-zones
scope:
  - packages/core/src/zones/**
  - packages/core/test/fixtures/zones/**
---

# T-015 — Decks, hands and resources

## Goal

Handle everything about cards that aren't on the board: setting up a game from decks, shuffling, drawing, hands and the hand limit, the resource pool, paying costs, resting, and attaching resources.

## Read first

- docs/CORE.md and packages/core/README.md
- docs/RULES.md: Components and setup (Setup), Round structure (draws during Plan, Cleanup), Resources and attaching, the sample Resources table
- `packages/cards/src/cost.ts` (pip strings)

## Deliverables

1. `createGame({ seats: [{ seat, leader, main, resources }], seed, config? }, cards)`:
   - creates a card instance for every card in every deck
   - shuffles the decks with the seeded RNG
   - draws 5 cards and 2 resources for each seat (RULES.md › Setup)
   - puts each Leader in its command zone
   - initializes every module slice, building on `createState()` (T-008)
   - fills `GameState.catalog` from `cards`, tokens included, so later phases read card data from the state
2. A `zones` slice with each seat's main deck, hand, graveyard ("used cards"), resource deck, resource pool (each resource rested or not) and command zone.
3. Draws: `drawCards` and `drawResources`, which accept modifiers for effects like "draw one more" and "no resource draw". Drawing from an empty deck does nothing and says so in the return value.
4. Costs: `canPay(state, seat, cost)` and `pay(…)`:
   - colored pips come from matching resources first, then two-color resources, then Prism ("any")
   - generic pips come from whatever is left, colorless resources first
   - payment is deterministic, and where possible it leaves resources that keep later colored costs payable
5. Resources in play:
   - resting, with everything unresting at Cleanup
   - a resource's ability rests that resource; Underwater Volcano arrives already rested
   - attaching resources to squads (Charge); at Cleanup they return to the pool, or to the bottom of the resource deck when an ability spent them
6. The hand limit at Cleanup: discard down to 8 (CORE.md default), unless an effect removes the limit (Old Library).
7. Tests for each of the above, including payment edge cases with Prism and two-color resources.

## Acceptance

- [ ] `pnpm lint && pnpm typecheck && pnpm test` green

## Out of scope

- Casting and placing cards (T-021) and deck legality rules (M3).
