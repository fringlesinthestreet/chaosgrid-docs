---
id: T-218
title: The e2e tests green again
milestone: M5
depends_on: []
branch: agent/T-218-e2e-green-again
model: sonnet
effort: high
scope:
  - apps/web/e2e/**
  - apps/web/src/replay/**
  - apps/web/README.md
context:
  - docs/APPS.md#Ports and the e2e DB
  - docs/APPS.md#The match
  - apps/web/README.md#Tests
---

# T-218 — The e2e tests green again

## Goal

Three of the ten Playwright tests fail on `main`, and did before T-199: `m4.spec.ts`'s "a new player plays a game" and both tests in `replay.spec.ts`. The planning UI changed under them (the Plan, Piles and Zones sections went, the tray holds the hand and the Leader's slot, the card view has the actions, resources rest from the strips and an action the floating mana can't pay shows inactive: D71, D72), and so did round 1 (nobody starts with resources, D60, and nothing is paid for you, D64). After this PR `pnpm test:e2e` passes 10 of 10 on `main`, and each test still checks what its title says.

## Interfaces

What failed when T-200 ran the e2e on an unmodified `main`, before T-199 and T-202 changed the planning UI again. Run it first and note what fails now:

- `apps/web/e2e/m4.spec.ts`, "a new player plays a game" (line 175). It stops at step 5 (around line 246), which places the Leader on the plan layer and then reads the line from `page.getByRole('region', { name: 'Plan', exact: true })`, expecting it struck through with `data-rejected="unaffordable"`. That region is gone (D71), and an action the floating mana can't pay now shows inactive (D72). The step has to follow the planning flow as it is now: the tray, the card view's actions (a tile, then Place in the card view), and resting a resource on its strip for mana.
- `apps/web/e2e/replay.spec.ts`, both tests. They load `apps/web/test/fixtures/logs/starter-2-rounds.json`, and T-200's run saw round 1 play through instantly. The first test expects units in the Units list at the end of round 1, the second a round clock that loses about two seconds in two seconds at 1×.

## Deliverables

1. **Each failure's cause**, found on `main`: the PR says whether it's the test (written for a UI or a round 1 that no longer exists) or the app (a bug). Use Playwright's trace or a headed run where the message isn't enough.
2. **The fix, where the cause is.** A test written for the old UI follows the current one and keeps its journey and its checks: m4 still signs up, builds a deck, plays a game to 30 points, and checks that the page shows an action the seat can't pay for (inactive, or rejected). A replay test that needs a round with units uses one the fixture has, such as round 2, or the PR says why it can't. A bug in the replay page is fixed in `apps/web/src/replay/`, with a unit test that fails without the fix.
3. **The web README's Tests section** still describes the e2e journey truthfully: update it if a step changed.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm test:e2e` passes 10 of 10, and the PR gives its summary line
- [ ] The PR names each of the three failures' cause and fix

## Out of scope

- Regenerating `apps/web/test/fixtures/logs/starter-2-rounds.json`: eight web unit tests read it. If a replay test can't pass with it, stop and ask the lead.
- The planning UI itself (two clicks to place a unit, the card view staying open after Place or Cast): the human judges it in play.
- New e2e tests.

## Notes

- Playwright starts the API, on an in-memory DB, and the dev server itself, on ports 4999 and 5999 unless `CHAOSGRID_WEB_PORT` and `CHAOSGRID_API_PORT` are set (docs/APPS.md › Ports and the e2e DB), and `pnpm test:e2e` checks both ports first. The human's `pnpm dev` uses 4000 and 5000, so the defaults don't clash with it.
- Find elements by role and accessible name, and wait on what the page shows, never on a sleep (the web README › Tests).
- If a cause is a bug outside `apps/web/src/replay/`, stop and tell the lead, who widens the scope (`crew card widen`).
- T-208 waits for this card, since its scope is the whole web app.
