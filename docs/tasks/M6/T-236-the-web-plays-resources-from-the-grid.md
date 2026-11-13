---
id: T-236
title: The web plays resources from the grid
milestone: M6
depends_on: [T-235, T-238]
branch: agent/T-236-the-web-plays-resources-from-the-grid
model: opus
effort: high
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - docs/ART.md
  - apps/web/src/**
  - apps/web/test/**
  - apps/web/e2e/**
  - apps/web/art-pack/**
  - apps/web/README.md
  - tools/sim-cli/src/**
  - packages/core/**
  - packages/bots/**
  - packages/cards/README.md
  - tools/sim-cli/test/**
context:
  - docs/RULES.md#Resources and mana
  - docs/DECISIONS.md#Decision log
  - docs/APPS.md#The match
  - docs/PROTOCOL.md#Snapshot
  - docs/ART.md
  - apps/web/README.md
---

# T-236 — The web plays resources from the grid

## Goal

The match screen plays by D85 and D86: a resource in the hand is placed on the grid like an artifact, the hand window shows the round's mana, a search opens a panel of the deck's basic resources, and the strips show piles only. The protocol loses the pool messages T-235 left inert.

## Interfaces

After T-235 and T-238 (grep the names, the lines move).

- Protocol 40 has `mana: { source, gives }[]`, `searches`, `deckBasicResources`, `searchResource`, `PermanentKind` `resource` and the `noResources` rule, beside the inert `resources: []`, `usable`, `restForMana`, `useResource`, `resource.drawn`, `resource.played` and `resource.rested`.
- The web's pool code: `battlefield/pools.ts` (`poolStacks`, `stripLayout` with `StackSpot`s), `planning/OwnPool.tsx`, `planning/ResourceActions.tsx` (`stackOf`, `nextToRest`), `planning/draft.ts` and `targets.ts` build `restForMana` and `useResource`; `model/apply.ts` keeps `model.pools` from the resource events; `planning/FloatingMana.tsx` reads the pool's `floating` resources; `cards/CardFace.tsx` and `HandEntry.tsx` show a resource card.
- `host.ts` splits the deck for core since T-234; `host.test.ts`.
- The hand window (T-238) holds the hand, the floating mana, Ready and the clock.

## Deliverables

1. **Protocol 41.** `resources` on the seat snapshot, `PoolResource`, `PoolCard`, `SeatPoolCard`, `usable`, `restForMana`, `useResource`, `ResourceRestReason` and the three `resource.*` events go; `docs/PROTOCOL.md` follows, and the event logs under `apps/web/test` are regenerated where they hold them.
2. **Casting.** A resource in the hand is placed like a free-standing artifact (`castPermanent`), and the plan accepts any number a round; while `noResources` is on, the hand shows resources greyed with that reason. The host passes the deck whole: `SeatSetup.resources` goes (T-235 left it optional).
3. **Mana.** `FloatingMana` reads `mana` and draws one pip per unit, colored by `gives` (generic grey, Prism rainbow), named by its source for screen readers; the hand window shows it (T-238).
4. **Searches.** When `searches` is above 0 during Plan, a panel over the hand window lists `deckBasicResources` as card faces with counts; a click adds `searchResource { cardId }` to the plan and the card shows in the hand after `plan.checked`; with an empty list the panel says there is nothing to search and offers Close. The panel is `planning/SearchPanel.tsx`.
5. **Resources on the grid.** The battlefield draws a resource permanent as a 1×1 permanent with its art key (`resource.*`, idle 16×16, D46), rested ones darker, and the card view shows its Rest ability as an action. `docs/ART.md` lists resources with the permanents' strips (idle, hurt, die, enter, ability where listed) in place of the pool's cast; the art pack follows. `ui.cardBack` has no `idle` or `enter` strip (ART.md): `art-pack/kinds.ts`, `art/manifest-schema.ts` and `scene.ts`'s fallback for a permanent without a card follow.
6. **Strips.** The pools go from the strips and the model: a strip shows the deck, the hand, the discard pile and the void; the "Pools and piles" list becomes "Piles". The strings in `battlefield.json` and `match.json` name the deck, not a main deck and a resource deck.
7. **sim-cli.** Nothing but what the protocol removal breaks.
8. **Tests:** a resource card in the hand places on a click like an artifact; the mana pips follow `mana`; the search panel lists, picks and closes; the strip draws no stacks; the model ignores no event it still receives; the e2e game plays round 1 by casting a resource and a unit.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm test:e2e` green
- [ ] `grep -rn "restForMana\|useResource\|PoolResource\|resource\.rested" packages apps tools --exclude-dir=node_modules` prints nothing

## Out of scope

- The hand window itself (T-238), the deck editor (T-234), the bots (T-235), the mana artifacts' pips (T-228).

## Notes

- Lead default: the search panel opens by itself when a search becomes pending and stays until resolved or closed; closing doesn't lose the search, locking does.
- Art for resources on the grid doesn't exist yet: the placeholder draws (ART.md); list the keys that need strips in the PR for the next art batch.
