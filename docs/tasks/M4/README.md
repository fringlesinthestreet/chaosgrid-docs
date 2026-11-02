# M4 — What it adds

What the M4 cards built, for the cards that link here. The conventions they share (accounts, the HTTP API, the web layout and its owners, routes, ports, the match) live with the code, in the code repo's `docs/APPS.md` (D53).

## What M4 adds

- `packages/http` (`@chaosgrid/http`, T-069, D28): the HTTP contract between `apps/api` and `apps/web`. Zod schemas for every request and response body, the error codes and the route paths. It imports only `cards` and `zod`, and runs in the browser.
- `apps/api` (`@chaosgrid/api`, T-071 to T-073): a local Fastify server over `db`. Accounts and sessions (D40), the card list, and decks.
- `apps/web` (`@chaosgrid/web`, T-068 and later): Vite + React + PixiJS. Login and sign-up, the card browser, the deck list and editor, the lobby, the match and the replay viewer.
- In `core`: `checkPlan` and a `plan.checked` event (T-078, D29), the round end that settles what's in flight, with a `simulate.ending` event (T-101, D38), and the `emblem.placed`, `prize.placed` and `permanent.healed` events (T-090). In `protocol`: `extendsPlan`, so a seat's plan only grows (T-078, D37). In `cards`: `costTotal` and `offColors` (T-102). In `bots`: the bot registry, moved from sim-cli (T-079).

