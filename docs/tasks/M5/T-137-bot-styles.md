---
id: T-137
title: Bot styles for the starter decks
milestone: M5
depends_on: [T-131, T-135]
branch: agent/T-137-bot-styles
model: sonnet
effort: high
scope:
  - packages/bots/**
  - tools/sim-cli/src/**
  - tools/sim-cli/test/*.ts
  - tools/sim-cli/README.md
  - apps/web/src/host/**
context:
  - packages/bots/README.md
  - tools/sim-cli/README.md#Decks
---

# T-137 — Bot styles for the starter decks

## Goal

Each of the five starter decks gets a bot style: aggro, control, ramp, revive or guard. A style changes how greedy and the planner (T-135) weigh their choices. The revive style fills and uses its discard pile, for example, and the ramp style rests its ramp units early. Whoever creates a bot passes the style: the web host from the seat's deck, sim-cli from the deck it chose. A deck with no style plays `balanced`, which is how the bots play today.

## Interfaces

What exists, copied from main on 2026-10-29. T-130, T-131, T-133 and T-135 change these files before this card starts, so re-read every call site named here:

```ts
// packages/bots/src/registry.ts
export function createBot(name: BotName, random: Random): Bot;    // :24
// T-135 adds the planner bot ('planner' in BOT_NAMES) and the way its creator passes it a
//   Simulator (D49). Read registry.ts and the planner's files first: the style goes in the same way.
// The planner (T-135) previews candidate plans through the Simulator within a budget, scores what
//   each preview reports (the points the seat scores, what it loses, …) and keeps the best plan.
// greedy-bot.ts after T-130 and T-133:
//   - places back-first while chaosPressure > 1;
//   - aims with pickByValue and ValueContext { aimSeat, buff: 'attacker', chaosTarget } (targets.ts);
//   - `others` orders cards by cost and Plan abilities by abilityScore (value.ts), skipping below 0;
//   - chooseDiscards (T-114) discards the cheapest kept cards.
export interface GreedyBotOptions { random: Random }               // greedy-bot.ts:28

// The starter decks (packages/cards/decks), and what @chaosgrid/cards/node exports:
//   starter.ember_aggro  Ember Aggro   starter.tide_control  Tide Control   starter.earth_ramp  Earth Ramp
//   starter.dark_revive  Dark Revive   starter.light_guard   Light Guard
export interface StarterDeck { id: string; name: string; description: string; deck: Deck } // src/node/starter.ts:50
export function loadStarterDecks(): StarterDeck[];

// tools/sim-cli/src
// game.ts: GameOptions (:27-45; T-110 adds pointTarget); the bots are made at :111-114:
//   createBot(name, () => nextFloat(seedRng(botSeed(seed, seat)))) (T-135 adds the Simulator).
// decks.ts:85-100
export function chooseDecks(rng: RngState, seats: number, source: DeckSource, cards: readonly Card[], starters: readonly Deck[]): Deck[];
// command.ts: CommandOptions.starters?: readonly Deck[] (:149);
//   runGame(seed, options, cards, starters: readonly Deck[], onEvents?): PlayedGame (:153-191);
//   simCommand loads loadStarterDecks().map((s) => s.deck) (:222-227).
// tournament.ts: playMatchup(lineup, options, cards, starters) (:43), runTournament (:85).
// T-131 adds PlayedGame.decks: readonly Deck[].
// These build starters with .map((starter) => starter.deck): src/decks.test.ts:17,
//   test/m3-done-when.soak.test.ts:26, test/plan-abilities.soak.test.ts:16,
//   test/snapshot-positions.test.ts:23, test/settle.soak.test.ts:19.
//   T-135 adds test/planner.perf.test.ts and test/planner.soak.test.ts the same way.

// apps/web/src/host/host.ts
export type SeatPlayer = { kind: 'human'; deck: Deck } | { kind: 'bot'; bot: BotName; deck: Deck }; // :27
// The constructor makes the bots at :125-130 with createBot(player.bot, () => nextFloat(rng)).
//   T-116 adds a 'discard' stage and T-135 passes the Simulator: re-read the constructor.
// host.test.ts › "plays the game sim-cli's loop plays" makes its own bots with createBot (:149).
```

What this task adds:

```ts
// packages/bots/src/style.ts (new), exported from the package's index
export const BOT_STYLES = ['balanced', 'aggro', 'control', 'ramp', 'revive', 'guard'] as const;
export type BotStyle = (typeof BOT_STYLES)[number];
/** The style each starter deck plays, by deck id. */
export const STARTER_STYLES: Readonly<Record<string, BotStyle>>;
/** STARTER_STYLES' style for a starter deck's id; 'balanced' for any other id, or for null. */
export function styleForDeck(deckId: string | null): BotStyle;
export interface StyleProfile {
  /** Greedy places back-first while chaosPressure is above this (T-130 uses 1). */
  backAbove: number;
  /** ValueContext.buff. */
  buff: 'attacker' | 'guard';
  /** ValueContext.enemyBy. */
  enemyBy: 'points' | 'threat';
  /** For this many first rounds, greedy uses free ramp abilities (Deliverables › 2). 0: never. */
  rampRounds: number;
  /** Fill the discard pile with units, and revive from it first. */
  pile: boolean;
  /** What the planner multiplies the two parts of T-135's scorePreview by. */
  weights: { scored: number; lost: number };
}
export const STYLE_PROFILES: Readonly<Record<BotStyle, StyleProfile>>;

// packages/bots/src/targets.ts: ValueContext gains
  /** How enemy squads rank: kill points first (T-130's rule), or dps first. */
  enemyBy: 'points' | 'threat';
// GreedyBotOptions and the planner's options gain style?: BotStyle ('balanced' when left out).

// tools/sim-cli/src/decks.ts
export interface ChosenDeck { deck: Deck; /** null for a generated deck */ starterId: string | null }
export function chooseDecks(rng: RngState, seats: number, source: DeckSource, cards: readonly Card[], starters: readonly StarterDeck[]): ChosenDeck[];
// game.ts: GameOptions gains
  /** Each seat's bot style, seat 0 first. Left out: every bot plays 'balanced'. */
  styles?: readonly BotStyle[];

// apps/web/src/host/host.ts
export type SeatPlayer =
  | { kind: 'human'; deck: Deck }
  | { kind: 'bot'; bot: BotName; deck: Deck; /** The deck's id, which picks the bot's style. */ deckId?: string };
```

## Deliverables

1. **style.ts.** `STARTER_STYLES` maps the five starter ids to aggro, control, ramp, revive and guard, in the order above. `STYLE_PROFILES`:

   | Style | backAbove | buff | enemyBy | rampRounds | pile | scored | lost |
   | --- | --- | --- | --- | --- | --- | --- | --- |
   | balanced | 1 | attacker | points | 0 | false | 1 | 1 |
   | aggro | Infinity | attacker | points | 0 | false | 1.5 | 0.5 |
   | control | 1 | attacker | threat | 0 | false | 1 | 1.5 |
   | ramp | 1 | attacker | points | 4 | false | 1 | 1 |
   | revive | 1 | attacker | points | 0 | true | 1 | 1 |
   | guard | 0.5 | guard | points | 0 | false | 0.75 | 2 |

2. **Greedy reads its style's profile.**
   - `backAbove` replaces the 1 in its back-first rule.
   - `buff` and `enemyBy` go into its ValueContext. With `enemyBy: 'threat'`, pickByValue ranks enemy grid squads by dps first, then by kill points. `chaosTarget` still comes first.
   - `rampRounds`: while `snapshot.round <= rampRounds`, a Plan ability that rests its own squad, costs nothing, casts a utility spell and needs no target scores 0 instead of below 0. So greedy uses it. These are the ramp units' "Rest this unit: draw a resource" (Seedling Scout, Root Tender, Elder Mycelium).
   - `pile`: `chooseDiscards` discards unit cards first, dearest first, then the cheapest of the rest. In `others`, every spell and ability whose target is a `discardPileCard` comes before all other options, whatever its score.

   With `balanced`, greedy plans exactly as it did before this card.
3. **The planner reads its style's weights.** T-135's `scorePreview` is `scored − lost`; the planner uses `weights.scored × scored − weights.lost × lost` instead:
   - `scored`: the points the seat scores in the preview;
   - `lost`: what it concedes, plus its prize's damage (T-135's `lost`).

   A round preview (T-129) reports no resources gained and no cards put in the discard pile, so ramp and revive change the planner through greedy's choices, which are its candidates, not through weights. With both weights 1, it plans as before.
4. **createBot takes the style** the same way T-135 passes the Simulator, as an optional `style` that defaults to `'balanced'`. Random and turtle ignore it.
5. **sim-cli.**
   - `starters` becomes `readonly StarterDeck[]` in `CommandOptions`, `runGame`, `playMatchup`, `runTournament` and `chooseDecks`. simCommand passes `loadStarterDecks()`.
   - `chooseDecks` returns `ChosenDeck[]`. `runGame` passes `styles: chosen.map((c) => styleForDeck(c.starterId))` to `playGame`, and `PlayedGame.decks` (T-131) still holds the decks.
   - `playGame` gives seat i's bot `styles?.[i] ?? 'balanced'`.
   - The tests above that map starters to decks pass `loadStarterDecks()` as it is.
   - README › Decks: with `--decks starter`, each bot plays its deck's style.
6. **The host.** The bot `SeatPlayer` gains `deckId?: string`. The constructor passes `styleForDeck(player.deckId ?? null)` to createBot. The lobby fills `deckId` in T-138.
7. **Tests.**
   - bots: `styleForDeck` for a starter id, an unknown id and null. A `balanced` greedy plans the same as a greedy with no style, on the existing fixtures.
   - greedy: aggro doesn't go back-first under a pressure of 2, and guard goes back-first at 0.75. Control's banish goes to the highest-dps squad, not the one with the most kill points. Ramp uses a free ramp ability in round 1 but not in round 5. Revive discards a unit card before a cheaper spell, and casts a revive before a dearer card.
   - planner: with a fake Simulator, as T-135's tests make one, there are two candidates. One scores more and loses more. Aggro takes it and guard doesn't.
   - sim-cli: every deck that `loadStarterDecks()` returns has a style other than `'balanced'`, so a new starter can't be forgotten. `chooseDecks` gives the starter ids, and null for generated decks.
   - host: with `vi.mock('@chaosgrid/bots', …)` wrapping the real createBot, a bot seat with deckId `'starter.dark_revive'` is made with `'revive'`, and one with no deckId with `'balanced'`. Put it in a test file of its own if the mock gets in the way of host.test.ts.
8. **README.** The bots README gets a Styles section: the table, and what each knob does.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/bots test` passes, with the tests above
- [ ] `pnpm --filter @chaosgrid/sim-cli test` passes
- [ ] `pnpm --filter @chaosgrid/web test host` passes
- [ ] `pnpm test:soak` passes
- [ ] `pnpm sim --games 10 --bots greedy,greedy,greedy,greedy --decks starter --target 30 --check` exits 0
- [ ] `pnpm sim --games 4 --bots planner,greedy,planner,greedy --decks starter --target 30 --check` exits 0

## Out of scope

- The lobby's bot levels and suggested decks (T-138), which pass `deckId`.
- Styles for decks players build. A copy of a starter deck plays `balanced`.
- Tuning the profile numbers: T-139's baseline report proposes the tuning cards.
- Styles for the turtle and random bots.
- Protocol changes.

## Notes

- Default: only a starter deck's own id has a style. The lobby gives bots starter decks only, so a player's copy (which has its own id) never reaches a bot there.
- `styleForDeck(null)` is `'balanced'`. That covers generated decks, and host seats with no `deckId`.
- D8: a style is part of a bot's setup, like its seed. sim-cli takes the styles from the decks it chose, so `--seed` still replays a game. In host.test.ts, "plays the game sim-cli's loop plays" has no deck ids, so both sides play balanced bots and still match.
- The numbers in `STYLE_PROFILES` are first guesses. Keep them in one table, so a tuning card changes one file.
- If T-135's planner has a part that no weight names, leave it at weight 1 and say so in the handoff.
- Soaks: m3-done-when's starter-deck tables, settle's starter games and the D33 matchup (greedy against random, starter decks) now play styled greedy. Generated decks play `balanced`. If D33's count drops below 56, report the numbers to `lead`; don't loosen the test.
