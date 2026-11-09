---
id: T-230
title: Bots and the web use ability mana
milestone: M6
depends_on: [T-225, T-228]
branch: agent/T-230-bots-and-the-web-use-ability-mana
model: sonnet
effort: high
scope:
  - packages/bots/**
  - apps/web/src/match/planning/FloatingMana.tsx
  - apps/web/src/match/planning/FloatingMana.test.tsx
  - apps/web/src/i18n/en/planning.json
  - apps/web/test/fixtures/planning/**
  - packages/cards/decks/**
  - packages/cards/src/node/starter.test.ts
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Resources and mana
  - docs/PROTOCOL.md#Snapshot
  - packages/bots/README.md
---

# T-230 — Bots and the web use ability mana

## Goal

T-228 added artifacts whose Plan ability adds one floating mana (D83). After this PR the bots use them to pay, the planning UI shows that mana beside the resources' floating mana, and each one-color starter deck plays its color's artifact.

## Interfaces

- T-228's snapshot field: the seat's pool part has `abilityMana?: { source; gives }[]`, absent meaning none (`docs/PROTOCOL.md` › Snapshot). The ability is an ordinary Plan ability (`useAbility`) with `effect: "addMana"`.
- The bots rest resources for mana before they pay (`packages/bots/src/pool.ts`, and each bot's plan drafting in `draft.ts`); grep `restForMana`.
- `apps/web/src/match/planning/FloatingMana.tsx` shows the floating mana from the pool's `floating` resources.
- The artifacts: `artifact.ember_brazier`, `artifact.tide_font`, `artifact.verdant_idol`, `artifact.bone_reliquary`, `artifact.sun_altar`, `artifact.clockwork_dynamo`.

## Deliverables

1. **Bots.** Every bot counts an unrested own artifact with an `addMana` ability as a payer. When a cost needs it, it uses that ability before paying, as it rests a resource; it uses resources first and ability mana after.
2. **Web.** `FloatingMana` shows each ability mana as a pip of the colors it gives (generic for Clockwork Dynamo), named by its source card for screen readers.
3. **Starter decks.** Each one-color starter deck plays its color's artifact (one copy, it's Unique) in place of one card of its choice, and stays 100 legal cards.
4. **Tests:** a bot with an Ember Brazier on its grid and one Ember resource casts a `1R` card; a bot never uses an `addMana` ability it doesn't need; `FloatingMana` renders one Ember pip for a Brazier's mana.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check perf` green
- [ ] `crew check soak` green

## Out of scope

- Core, the protocol and the card files (T-228).
