---
id: T-084
title: Solo lobby
milestone: M4
depends_on: [T-076, T-079, T-080]
branch: agent/T-084-lobby
model: sonnet
effort: medium
scope:
  - apps/web/src/lobby/**
context:
  - docs/tasks/M4/README.md#Accounts
  - docs/tasks/M4/README.md#Web layout and ownership
  - docs/tasks/M4/README.md#Routes
  - docs/tasks/M4/README.md#The match
---

# T-084 — Solo lobby

## Goal

Before a match the player picks their deck and the bots they'll face. After this task `/play` shows the player's decks (illegal ones dimmed) and the starters, the three bot opponents with a bot kind and a deck each, and an optional seed and point target. The three bots are always there, prefilled: every game has 4 seats (D22), and an M4 match is offline, the human against bots in the browser. Start opens `/match` with a `MatchSetup` (T-080) in the router state.

## Interfaces

What exists (T-068, T-075, T-076, T-079, T-080):

```ts
// apps/web/src/decks (T-076), imported from '../decks'
export function useDecks(): DecksState; // listDecks as a hook; ready: { decks: DeckSummary[] }
export function getDeck(id: string): Promise<DeckDetail>; // DeckDetail { deck: Deck, problems, … }
// DeckSummary { id, name, leader, starter, legal, … }: own decks most recently updated first, then the starters by name

// apps/web/src/cards (T-075), imported from '../cards'
export function useCards(): CardsState; // ready: { cards, byId, retired }

// apps/web (T-068): CardArt({ cardId, size }) (src/art), the class cg-dimmed (src/theme),
//   stubApi(routes) (test/fixtures/api.ts)

// @chaosgrid/bots (T-079): the lobby reads only these (createBot is the host's, T-080)
export type BotName; export const BOT_NAMES: readonly BotName[]; // 'random', 'greedy', 'turtle'
export function isBotName(name: string): name is BotName;

// apps/web/src/host (T-080), import the types only
export type SeatPlayer = { kind: 'human'; deck: Deck } | { kind: 'bot'; bot: BotName; deck: Deck };
export interface MatchSetup { seats: readonly SeatPlayer[]; seed: string; pointTarget?: number } // core's default when left out

// apps/web/src/lobby/index.tsx (T-068 placeholder): LobbyPage
```

What this task adds (`apps/web/src/lobby/`):

```ts
// lobby.ts (pure, no React)
export interface Opponent { bot: BotName; deck: string | 'random' } // deck: a legal starter's id, or 'random'
export interface LobbyChoice {
  deck: string | null;                       // the player's deck id
  opponents: readonly [Opponent, Opponent, Opponent]; // seats 1-3 (D22)
  seed: string;                              // '' means a new random one at Start
  pointTarget: number | null;                // null means core's default
}
export const DEFAULT_CHOICE: LobbyChoice;    // deck null; opponents greedy, turtle, random, each deck 'random'; seed ''; pointTarget null
export function choiceProblems(choice: LobbyChoice, decks: readonly DeckSummary[]): string[]; // [] when Start can go
/** The saved choice when it has 3 opponents passing `isBotName` and every deck in it exists and is legal; else DEFAULT_CHOICE. */
export function restoreChoice(saved: unknown, decks: readonly DeckSummary[]): LobbyChoice;
/** Resolves 'random' decks and an empty seed with `random`, then reads each deck. */
export function buildSetup(choice: LobbyChoice, decks: readonly DeckSummary[], load: (id: string) => Promise<Deck>, random: () => number): Promise<MatchSetup>;

export function LobbyPage(): JSX.Element;
```

## Deliverables

1. **Your deck.** A list of the player's decks and the starters (`useDecks`), each with its Leader and the deck name. The Leader shows its `CardArt` and its name from `useCards().byId` (its id when the card is missing). Decks that aren't legal show dimmed (`cg-dimmed`) with "Not legal" and a link to edit them, and can't be picked. When the choice's `deck` is `null` (as in `DEFAULT_CHOICE`), the page picks the most recently updated legal deck of the player's own, else the first legal starter. The page waits for both hooks; an error in either shows its `error.message` with a Retry button.
2. **Opponents.** One row per bot seat (seats 1, 2, 3), prefilled from the starting choice (item 5): the bot kind (a select over `BOT_NAMES`) and its deck (Random starter, or a starter by name; the select lists legal starters only). Always three rows: D22 fixes 4 seats, and core refuses any other count. The table is drawn "You · seat 0" first, then the bots.
3. **Options.** Under "More options", collapsed: the seed (text, empty means random) and the point target (empty means core's default, `null` in the choice; else a whole number from 5 to 100). The 5 to 100 range is the lobby's own limit, not a core rule.
4. **Start.** Enabled when `choiceProblems` is empty. It calls `buildSetup` (a random seed is 8 base-36 characters; a random deck is one of the legal starters, picked with the same `random`; `pointTarget` goes into the setup only when it isn't `null`), then `navigate('/match', { state: { setup } })`. A failed `getDeck` shows `error.message` and keeps the choices.
5. **Last choice.** The page remembers the last `LobbyChoice` in `localStorage` (`cg:lobby`, wrapped in try/catch) and starts from `restoreChoice(saved, decks)`: the saved choice only when it has exactly 3 opponents whose `bot` passes `isBotName` and every deck in it still exists and is legal, else `DEFAULT_CHOICE`.
6. **Tests:**
   - `choiceProblems`: no deck; an illegal deck; a deck id that isn't in the list; an opponent deck that isn't a legal starter; a point target of 4 or 101 or 30.5 (`null` passes)
   - `restoreChoice`: two or four opponents, a bot that fails `isBotName` (`'Greedy'`), a deck that's gone or not legal, or a value that isn't an object each give `DEFAULT_CHOICE`; a good saved choice is kept
   - `buildSetup`: the human is seat 0 and the bots follow in order; 'random' picks a legal starter with the given `random`; an empty seed becomes 8 base-36 characters; a given seed is kept; `pointTarget` is passed through, and left out when `null`
   - the page with `stubApi`: illegal decks are dimmed and can't be picked; a bot's deck select lists only legal starters; there are always three prefilled opponent rows, with no Add or Remove; a Leader the cards don't have shows its id; Start navigates to `/match` with the setup in the state (check it with a test route that prints `location.state`)

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test -- lobby` passes
- [ ] With the API on 5084 and the web on 4084: sign up, `/play` picks a starter (no own decks yet), Start opens `/match` (still T-068's placeholder until T-085)

## Out of scope

- The match itself (T-085). Multiplayer seats, invites and a server lobby (M6).
- Bot difficulty beyond the three bot kinds.

## Notes

- Default: a bot plays only legal starter decks, so a bot never sees the player's own decks.
- Default: the seed is a string, as the host takes it. The same `MatchSetup` plays the same game, as long as the human's plans are the same.
- Import `MatchSetup` and `SeatPlayer` with `import type` from `../host`. The lobby never names a core type.
- Import `useDecks` and `getDeck` from `../decks` and `useCards` from `../cards`: folders import each other only through their index.
- From `@chaosgrid/bots` the lobby reads only `BOT_NAMES`, `BotName` and `isBotName`. `createBot` is the host's (T-080): the lobby names a bot, the host builds it.
