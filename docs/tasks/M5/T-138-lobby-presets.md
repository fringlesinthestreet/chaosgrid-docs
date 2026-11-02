---
id: T-138
title: Lobby presets and bot levels
milestone: M5
depends_on: [T-110, T-124, T-137]
branch: agent/T-138-lobby-presets
model: sonnet
effort: medium
scope:
  - apps/web/src/lobby/**
  - apps/web/src/i18n/en/lobby.json
context:
  - docs/tasks/M4/README.md#Web layout and ownership
  - apps/web/README.md#Text (D50)
  - apps/web/README.md#Tests
---

# T-138 — Lobby presets and bot levels

## Goal

The lobby asks two questions a player understands: how long the game should be, and how strong each bot is.

- Game length: Quick (50 points), Standard (100) or Long (150). A custom point target stays possible.
- Each opponent: Easy, Normal or Hard instead of a raw bot name. Each seat suggests a starter deck that fits its level, using T-137's styles.

The lobby's text moves into `lobby.json` and goes through `t()` (D50).

## Interfaces

What exists, copied from main on 2026-10-29. T-110 changes the lobby, so re-read lobby.ts, index.tsx and both test files when you start:

```ts
// apps/web/src/lobby/lobby.ts
export interface Opponent { bot: BotName; /** A legal starter's id, or 'random'. */ deck: string } // :8-12
export interface LobbyChoice {
  deck: string | null;                                  // the player's deck id
  opponents: readonly [Opponent, Opponent, Opponent];   // seats 1 to 3 (D22)
  seed: string;                                         // '' means a new random one at Start
  pointTarget: number | null;                           // null means core's default
}                                                       // :14-23
export const DEFAULT_CHOICE: LobbyChoice; // :25: greedy, turtle, random, all on 'random' decks; pointTarget null
export const POINT_TARGET_MIN = 5; export const POINT_TARGET_MAX = 100; // :36-37; T-110 makes the max 200
export const legalStarters: (decks: readonly DeckSummary[]) => DeckSummary[];  // :39
export function defaultDeckId(decks: readonly DeckSummary[]): string | null;   // :43
/** [] when Start can go. */
export function choiceProblems(choice: LobbyChoice, decks: readonly DeckSummary[]): string[]; // :49: English strings
/** The saved choice when it has 3 opponents passing isBotName and every deck in it exists and is legal; else DEFAULT_CHOICE. */
export function restoreChoice(saved: unknown, decks: readonly DeckSummary[]): LobbyChoice; // :82
export async function buildSetup(choice, decks, load: (id: string) => Promise<Deck>, random: () => number): Promise<MatchSetup>; // :113
//   resolves 'random' decks and an empty seed with `random`; leaves pointTarget out when it's null

// apps/web/src/lobby/index.tsx
// STORAGE_KEY 'cg:lobby' (:19): loadSaved, and save on every change. LobbyForm (:43) renders:
//   h2 "Your deck": a radio per deck (aria-label: the deck's name), "Starter", "Not legal", "Edit";
//   h2 "Opponents": "You · seat 0" with the deck's name or "No deck", then per seat "Seat N" with
//     two selects: "Seat N bot" (BOT_NAMES) and "Seat N deck" ("Random starter", then each legal starter);
//   details "More options": "Seed" (placeholder "Random") and "Point target" (placeholder "Default");
//   the "Start" button, the problems, and "Can't start the match." when Start throws something
//     that isn't an Error.
// LobbyPage (:222): h1 "Play", "Loading…", "Retry".

// apps/web/src/host/host.ts after T-137
export type SeatPlayer =
  | { kind: 'human'; deck: Deck }
  | { kind: 'bot'; bot: BotName; deck: Deck; deckId?: string }; // deckId picks the bot's style
// MatchSetup { seats, seed, pointTarget?: number }

// @chaosgrid/bots after T-135 and T-137
// BOT_NAMES: 'random', 'greedy', 'turtle', and T-135's 'planner'.
export type BotStyle = 'balanced' | 'aggro' | 'control' | 'ramp' | 'revive' | 'guard';
export function styleForDeck(deckId: string | null): BotStyle; // a starter's style, else 'balanced'

// apps/web/src/i18n (T-124): t(id: MessageId, values?: MessageValues): string;
//   en/lobby.json exists and is {}.

// apps/web/e2e/m4.spec.ts (out of scope): checks the radio "E2E deck", opens "More options", fills "Seed",
//   fills "Point target" with 30 (T-110) and clicks "Start". Its strings must keep working.
```

What this task adds:

```ts
// apps/web/src/lobby/lobby.ts
export const BOT_LEVELS = ['easy', 'normal', 'hard'] as const;
export type BotLevel = (typeof BOT_LEVELS)[number];
/** The bot each level plays. */
export const LEVEL_BOTS: Readonly<Record<BotLevel, BotName>> = { easy: 'random', normal: 'greedy', hard: 'planner' };
/** The styles a level's suggested deck tries, in order. */
export const LEVEL_STYLES: Readonly<Record<BotLevel, readonly BotStyle[]>>;
export const GAME_LENGTHS = { quick: 50, standard: 100, long: 150 } as const;
export type GameLength = keyof typeof GAME_LENGTHS | 'custom';
/** The preset with this point target, else 'custom'. */
export function gameLengthOf(pointTarget: number): GameLength;
export interface Opponent {
  level: BotLevel;
  /** 'suggested', 'random', or a legal starter's id. */
  deck: string;
}
// LobbyChoice.pointTarget becomes `number`: from POINT_TARGET_MIN to POINT_TARGET_MAX.
/**
 * Each seat's suggested starter id, seat 1 first: the first of its level's styles with a legal
 * starter that neither the player nor an earlier seat plays (by id or by suggestion). Failing
 * that, any legal starter not taken yet; failing that, the first legal starter. Null with none.
 */
export function suggestedDecks(choice: LobbyChoice, decks: readonly DeckSummary[]): (string | null)[];
```

## Deliverables

1. **Levels.**
   - `LEVEL_STYLES`:
     - easy: aggro, guard, ramp, revive, control;
     - normal: guard, ramp, aggro, revive, control;
     - hard: control, revive, ramp, guard, aggro.
   - A starter's style is `styleForDeck(starter.id)`.
   - `DEFAULT_CHOICE`: Normal, Normal and Easy, all on `'suggested'`, and `pointTarget` 100. With the real starters and a deck of the player's own, the suggestions are Light Guard, Earth Ramp and Ember Aggro.
2. **The model.**
   - `choiceProblems`: `'suggested'` and `'random'` both need a legal starter (the "there is no legal starter deck" problem). The point target must be a whole number from 5 to 200.
   - `buildSetup` resolves `'suggested'` with `suggestedDecks` and `'random'` with `random`. Every bot seat gets `bot: LEVEL_BOTS[level]` and the resolved starter's id as `deckId`. The setup always carries `pointTarget`.
3. **Old saves.** `restoreChoice` reads the old shape too:
   - an opponent's `bot` becomes a level: random → easy, greedy and turtle → normal, planner → hard;
   - the deck values stay as they were;
   - a `pointTarget` of null (core's default) becomes 100.

   Anything else that isn't valid falls back to `DEFAULT_CHOICE`, as today. The key stays `'cg:lobby'`, and the page saves the new shape.
4. **The page.**
   - Each seat row has a "Seat N level" select (Easy, Normal, Hard) in place of "Seat N bot".
   - The "Seat N deck" select starts with "Suggested: {deck}", the suggestion's name, or "Suggested: none". Then come "Random starter" and the legal starters, as now.
   - A "Game length" fieldset with the radios "Quick (50 points)", "Standard (100 points)", "Long (150 points)" and "Custom" goes between Opponents and More options. The checked radio is `gameLengthOf(pointTarget)`.
   - Picking a preset sets the target and the "Point target" field. Picking Custom keeps the target and opens More options.
   - "Point target" stays under More options with the same label, and with no placeholder. Typing a number that isn't a preset checks Custom. An empty field or one that isn't a number is a problem, and Start stays disabled.
5. **Text.** Every string the lobby shows goes into `en/lobby.json` and through `t()`, with the English as it is now. That covers the page's text, `choiceProblems` (which runs at render) and the new text above. Messages take their numbers as arguments, for example `"Seat {seat}: pick a legal starter deck."` and `"Quick ({points} points)"`.
6. **Tests.**
   - lobby.test.ts:
     - `suggestedDecks`: the defaults with starters under their real ids; it skips the player's deck; ids with no style fall back to free legal starters; null with no legal starter.
     - `gameLengthOf`: 50, 100, 150 and 30.
     - `restoreChoice`: an old save with `turtle`, a `'random'` deck and a null target restores as Normal, `'random'` and 100; `planner` restores as Hard; an unknown bot gives `DEFAULT_CHOICE`; a new save round-trips.
     - `buildSetup`: the level's bot and `deckId` on each seat, `'suggested'` resolved, the target always there.
     - `choiceProblems`: 4, 201 and 30.5 are flagged; 5 and 200 pass.
   - page.test.tsx:
     - the three level selects start at Normal, Normal and Easy;
     - the deck select shows the suggestion;
     - Quick puts 50 in "Point target", and typing 30 checks Custom;
     - Start sends the target and the bots' `deckId`s.

     The existing tests move to the new labels (`/level$/` for the selects). A test that types into "Point target" clears it first: the field now starts at 100.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test lobby` passes, with the tests above
- [ ] `grep -rn -E "Your deck|Opponents|More options|Point target|Random starter|Not legal|You · seat|No deck|Can't start|Loading…|whole number" apps/web/src/lobby --exclude='*.test.ts' --exclude='*.test.tsx'` prints nothing
- [ ] `grep -c "BOT_NAMES" apps/web/src/lobby/index.tsx` prints 0
- [ ] `pnpm test:e2e` passes

## Out of scope

- The styles, the planner and the host's `deckId` (T-135, T-137).
- `apps/web/e2e/m4.spec.ts`: its strings keep working. If the new default opponents break it, ask `lead`.
- Text outside `src/lobby/`, and `common.json`.
- Choosing a raw bot name in the lobby. The turtle bot stays in `BOT_NAMES` for sim-cli, but no level plays it.

## Notes

- "A fitting deck" default: the random bot casts whatever it can, so aggro suits Easy. Greedy plays straightforward decks well: guard and ramp for Normal. The planner can look ahead with the decks that need it: control and revive for Hard.
- Default: no Hard seat by default. The planner previews rounds, and a new player starts against the strength the old default had (greedy, turtle, random).
- Old saves keep their decks: a saved `'random'` stays random, and only new choices start on `'suggested'`. Turtle becomes Normal, the level that plays greedy.
- A suggestion updates at render, as the player changes their deck or another seat's.
- `buildSetup`'s thrown Errors stay developer text (README › Text): Start is disabled while `choiceProblems` lists a problem, so a player doesn't see them.
- Ids built from a level, `` t(`lobby.level.${level}`) ``, type-check once every level has its key.
- Tests find text by its English, never through `t()` (README › Text).
- A target that isn't a number is saved as JSON `null`, so it comes back as 100.
- Only `lobby/` and `host/` import `@chaosgrid/bots` (M4 README › Web layout and ownership).
