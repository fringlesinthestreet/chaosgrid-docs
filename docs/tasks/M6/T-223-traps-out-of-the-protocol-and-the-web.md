---
id: T-223
title: Traps out of the protocol and the web
milestone: M6
depends_on: [T-219, T-220, T-222]
branch: agent/T-223-traps-out-of-the-protocol-and-the-web
model: sonnet
effort: high
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - docs/ART.md
  - apps/web/src/**
  - apps/web/test/**
  - apps/web/art-pack/**
  - apps/web/README.md
context:
  - docs/DECISIONS.md#Decision log
  - docs/PROTOCOL.md#Versioning
  - docs/PROTOCOL.md#Visibility
  - apps/web/README.md#Tests
---

# T-223 — Traps out of the protocol and the web

## Goal

After T-219 nothing produces a trap. This PR takes them out of the contract and the screens (D81): protocol version 39 has no trap card or permanent type, no trap events and no face-down permanents, and the web draws, lists and logs none.

## Interfaces

On `main` (grep `trap`, the lines move):

- `packages/protocol/src/card.ts`: `'trap'` in the card types; `PermanentType = z.enum(['trap', 'artifact', 'enchantment'])` becomes `['artifact', 'enchantment']`.
- `event.ts`: `TrapSetEvent` (`trap.set`), `TrapRevealedEvent` (`trap.revealed`), `TrapFiredEvent` (`trap.fired`), in the event union and `index.ts`; the private "it was a face-down trap" fields on the permanent events; the comments that list traps among killers, sources and permanents.
- `snapshot.ts`: the face-down trap only its owner's snapshot has, and the comment on non-unit permanents; `primitives.ts` and `plan.ts` comments.
- `version.ts`: `PROTOCOL_VERSION = 38` becomes 39; `docs/PROTOCOL.md`'s title and every trap passage follow.
- The web: `battlefield/scene.ts` (face-down drawing), `planning/PlanGrid.tsx`, `planning/HandCardActions.tsx`, `model/types.ts` and `model/apply.ts`, `overlays/log.ts`, `cards/CardFace.tsx`, `art/manifest-schema.ts` (`fx.trap`), `i18n/en/cards.json` and `en/deckEditor.json` (the type's name and filter), and their tests (`pick.test.ts`, `sprites.test.ts`, `log.test.ts`, `apply.test.ts`, `PlanningActions.test.tsx`).
- `docs/ART.md`: the `fx.trap` key and the `trap.set`, `trap.revealed` and `trap.fired` rows.

## Deliverables

1. Everything in Interfaces removed, with the version bump.
2. The web's recorded logs in `apps/web/test/fixtures/logs/` regenerated as their README says, if they hold trap events or no longer parse.
3. Tests: a `trap.fired` event and a permanent of type `trap` fail to parse; the protocol's lists of event types drop the three.
4. `grep -rniwE "traps?" packages/protocol apps/web/src apps/web/test apps/web/art-pack docs/PROTOCOL.md docs/ART.md --exclude-dir=node_modules` prints nothing.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check perf` green
- [ ] `crew check soak` green
- [ ] The grep of deliverable 4 prints nothing

## Out of scope

- Core, the bots, the cards and sim-cli: T-219 left no trap in them. If one still names a protocol trap type, stop and ask the lead.

## Notes

- The art for the removed cards stays in the main checkout's `Art/`, outside the repo. If the art pack fails on a folder whose key is no card any more, ask the lead.
- "Face-down" also describes card backs on the piles: keep those.
