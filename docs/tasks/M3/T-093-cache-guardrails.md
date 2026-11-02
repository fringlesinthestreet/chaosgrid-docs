---
id: T-093
title: Cache rule and the fresh-cache test
milestone: M3
depends_on: [T-046]
branch: agent/T-093-cache-guardrails
model: sonnet
effort: high
scope:
  - packages/core/README.md
  - packages/core/src/combat/caches.test.ts
  - packages/core/test/fixtures/caches/**
  - packages/core/src/state/ids.ts
  - packages/core/src/state/lookup.ts
  - packages/core/src/movement/step.ts
  - packages/core/src/effects/sources.ts
  - packages/core/src/effects/scripts/raider_pack.ts
  - packages/core/src/combat/simulate.ts
context:
  - packages/core/README.md#The state
  - packages/core/README.md#Tests
---

# T-093 — Cache rule and the fresh-cache test

## Goal

At 100 ticks per second, combat reads the same derived data thousands of times a round, so T-046 kept or added a few caches. They live outside the state, in module-level `WeakMap`s, so the state stays plain JSON. T-046 asked whether that's safe. The human kept them and asked for two guardrails (D32):

- a written rule in core's README that every cache follows, with a list of the caches
- a test that plays the same rounds twice, once normally and once starting every tick with empty caches, and checks that the events and the final state are the same

## Interfaces

What exists (copied from the code on 2026-10-22):

```ts
// packages/core/src/state/ids.ts:57: counters already parsed, keyed by the id string
const ID_NUMBERS = new Map<string, number>();
// packages/core/src/state/lookup.ts:38: allUnits' list, held until nextId, the units record or an entry changes
const UNIT_LISTS = new WeakMap<GameState, { units; nextId; list }>();
// packages/core/src/movement/step.ts:140: the last search that found no path, per movement entry.
// Only for an area without isOpen. Combat's area has none (combat/board.ts:57), so combat uses it.
const noPathFor = new WeakMap<UnitMovement, number[]>();
// packages/core/src/effects/sources.ts:245, 292 and 324: card instances with abilities, and the
// possible sources of each kind, guarded by nextId, squads, permanents and cards
const CARDS_WITH_ABILITIES = new WeakMap<object, { nextId: number; ids: CardInstanceId[] }>();
const POSSIBLE_WITH = new WeakMap<…>();
const POSSIBLE_SOURCES = new WeakMap<…>();
// packages/core/src/effects/scripts/raider_pack.ts:31: whether a card definition raids
const RAIDERS = new WeakMap<object, boolean>();
// packages/core/src/combat/simulate.ts:46: not a cache. It's per-ctx bookkeeping: which tick
// already emitted its `tick` event
const announced = new WeakMap<Ctx, Ticks>();

// packages/core/src/combat/simulate.ts
export function beginSimulate(ctx: Ctx, spells?): EndReason | null;
export function simulateTick(ctx: Ctx): EndReason | null; // reads ctx.state at the start of the tick
export function endSimulate(ctx: Ctx, reason: EndReason): void;
export function simulate(ctx: Ctx): SimulateResult; // begin, then simulateTick until it returns a reason, then end
// packages/core/src/state/ctx.ts
export interface Ctx { readonly state: GameState; emit(event: GameEvent): void }
// packages/core/test/fixtures/combat/setup.ts: SAMPLE_CARDS, combatState(options), put, queueSpell, run, eventLog
```

D32 (docs/DECISIONS.md): core may cache derived data outside the state, never inside it. A cache lives in a module-level `WeakMap` keyed by the object it comes from (or a `Map` keyed by a plain value), checks everything it reads before it reuses an entry, and never changes a result. A run that starts every tick with empty caches gives the same events and state. Caches never appear in a snapshot or an event. Core's README › Caches lists them.

## Deliverables

1. **README › Caches.** A new section in `packages/core/README.md`, after The state:
   - The rule, as D32 states it, in a short list:
     - a cache is derived only from its key and the things it checks
     - it's keyed by object identity (`WeakMap`) or by a plain value
     - it checks everything it reads before it reuses an entry
     - it's never stored in the state, a snapshot or an event
     - it never changes a result
   - A table of every cache: file, what it holds, its key, what it checks. Include `announced` as per-ctx bookkeeping, not a cache.
   - How to add one: follow the rule, add a row, and make sure the fresh-cache test plays something that reads it.
2. **Comments.** Each cache's doc comment links to README › Caches in one line. Change only comments in the source files: no code changes.
3. **The fresh-cache test**, `packages/core/src/combat/caches.test.ts`:
   - Play each scenario twice from the same starting state. The first run uses `simulate` as usual. The second uses `beginSimulate`, then `simulateTick` until it returns a reason, then `endSimulate`. Before every `simulateTick` it replaces the state with `structuredClone` of it, so every object a cache is keyed on is new and every cache starts empty. Use one ctx object with a getter for `state` (`{ get state() { return current }, emit }`), so `announced` still sees the same ctx.
   - Expect equal events (`toEqual`) and an equal final state.
   - Scenarios, small enough that the whole file runs in a few seconds:
     - deaths and a token or Chaos spawn in the middle of a round (`nextId` moves, units are added)
     - a static aura that changes a stat while units die (the sources caches)
     - a unit with no path that waits while others move (`noPathFor`)
     - Raider Pack (`RAIDERS`)
   - Put any cards or setups the scenarios need in `packages/core/test/fixtures/caches/`.
   - If a scenario doesn't reach the cache it's meant for, say how you checked in the PR.

## Acceptance

- [ ] `scripts/check.sh` is green.
- [ ] `pnpm --filter @chaosgrid/core exec vitest run caches` passes in under 10 seconds.
- [ ] `git diff -U0 main...HEAD -- packages/core/src ':!*.test.ts' | grep '^[+-][^+-]' | grep -v '^[+-]\s*\(//\|\*\|/\*\*\)'` prints nothing: only comments changed in the source files.

## Out of scope

- Any change to a cache or to how core behaves. If the test finds a difference, don't fix it: send `lead` a `question` with the scenario and the first event that differs, and mark the test `it.fails` with a comment that links to your question.
- The perf tests and the soaks (T-092).
- The projectiles module (T-091).

## Notes

- From T-046's open question 2 (2026-10-22). The human chose to keep the caches outside the state and add these guardrails.
- `newGame`, `beginRound` and `playRound` each copy their input, so the caches already start empty every round. Only the ticks inside one `simulate` reuse them, which is what this test covers.
- T-047 may give combat's area an `isOpen` for the gaps between grids. Then `noPathFor` no longer caches in combat. Say so in the README's table ("only for an area without `isOpen`"), so T-047 sees it.
