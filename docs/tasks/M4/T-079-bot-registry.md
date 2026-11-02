---
id: T-079
title: Bot registry in packages/bots
milestone: M4
depends_on: [T-062]
branch: agent/T-079-bot-registry
model: sonnet
effort: low
scope:
  - packages/bots/src/registry.ts
  - packages/bots/src/registry.test.ts
  - packages/bots/src/index.ts
  - packages/bots/README.md
  - tools/sim-cli/src/bots.ts
  - tools/sim-cli/src/seeds.ts
context:
  - docs/tasks/M4/README.md#The match
  - packages/bots/README.md#Using a bot
  - packages/bots/README.md#Files
  - packages/bots/README.md#Adding a bot
---

# T-079 — Bot registry in packages/bots

## Goal

The list of bots a game can name lives in sim-cli today. The web's lobby (T-084) and host (T-080) need the same list, and `apps/web` may import `bots` but never `tools/sim-cli`. After this task, `@chaosgrid/bots` exports the registry (`BOT_NAMES`, `BotName`, `isBotName`, `createBot`) and the per-seat seed rule (`botSeed`), and sim-cli re-exports them, so sim-cli's code and its golden tests don't change.

## Interfaces

What exists (copied from the code on 2026-10-28):

```ts
// tools/sim-cli/src/bots.ts (the whole file, minus imports)
const FACTORIES = {
  random: (random: Random): Bot => createRandomBot({ random }),
  greedy: (random: Random): Bot => createGreedyBot({ random }),
  turtle: (random: Random): Bot => createTurtleBot({ random }),
} satisfies Record<string, (random: Random) => Bot>;
export type BotName = keyof typeof FACTORIES;
/** Every bot `--bots` takes, in the order the usage lists them. */
export const BOT_NAMES = Object.keys(FACTORIES) as BotName[];
export function isBotName(name: string): name is BotName;
/** A new bot, drawing its choices from `random` (D8: bots keep no randomness of their own). */
export function createBot(name: BotName, random: Random): Bot;
// Imported by sim-cli's tournament.ts, stats.ts, game.ts, command.ts and index.ts (and tests).

// tools/sim-cli/src/seeds.ts
/** The seed of the bot in `seat`: each seat draws from its own sequence. */
export const botSeed = (seed: string, seat: number): string => `${seed}/bot/${seat}`;
// game.ts:112: const rng = seedRng(botSeed(seed, seat)); createBot(name, () => nextFloat(rng));
```

What this task adds:

```ts
// packages/bots/src/registry.ts, exported from src/index.ts
export type BotName; // 'random' | 'greedy' | 'turtle', as today
export const BOT_NAMES: readonly BotName[];
export function isBotName(name: string): name is BotName;
export function createBot(name: BotName, random: Random): Bot;
export const botSeed: (seed: string, seat: number) => string; // unchanged rule
```

## Deliverables

1. **`registry.ts`.** Move `FACTORIES`, `BotName`, `BOT_NAMES`, `isBotName`, `createBot` and `botSeed` into it, with their comments. Reword the comments that name `--bots`: the registry is the list of bots any game can name (sim-cli's `--bots`, the web lobby). Export them from `src/index.ts`.
2. **sim-cli.** `tools/sim-cli/src/bots.ts` becomes a re-export of the registry from `@chaosgrid/bots`, and `seeds.ts` re-exports `botSeed` from there. No other sim-cli file changes.
3. **README.**
   - › Using a bot: the example builds the bot with `createBot(name, …)` and `seedRng(botSeed(gameSeed, seat))`.
   - › Files: a row for `src/registry.ts`.
   - › Adding a bot, step 1: add it to `FACTORIES` in `src/registry.ts` (not sim-cli's).
4. **Tests** (`registry.test.ts`): `BOT_NAMES` is `['random', 'greedy', 'turtle']`; `isBotName` accepts each and refuses `'Greedy'` and `'toString'`; `createBot` returns a bot whose `name` is the one asked for; `botSeed('7', 2)` is `'7/bot/2'`.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/sim-cli test` passes with its golden files unchanged
- [ ] `git diff --stat main -- tools/sim-cli` shows only `src/bots.ts` and `src/seeds.ts`

## Out of scope

- New bots, or any change to how a bot plans.
- Moving `gameSeed` or `deckSeed`: they're sim-cli's run rules. The web host makes its own match seed (T-080).

## Notes

- Default: the registry keeps today's order, `random`, `greedy`, `turtle`. The lobby lists bots in this order (T-084).
- `botSeed` moves with the registry so the web host and sim-cli seed a seat's bot the same way: a match replayed in sim-cli with the same seed, decks and bots then plays the same plans.
- This card waits for T-062, the last M3 task with `packages/bots/` in its scope.
