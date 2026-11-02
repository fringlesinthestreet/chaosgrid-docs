---
id: T-144
title: Bot draft reuse and Rest-safe attaches
milestone: M5
depends_on: []
branch: agent/T-144-bot-draft-reuse
model: sonnet
effort: medium
scope:
  - packages/bots/src/draft.ts
  - packages/bots/src/draft.test.ts
  - packages/bots/src/random-bot.ts
  - packages/bots/src/random-bot.test.ts
  - packages/bots/src/greedy-bot.ts
  - packages/bots/src/greedy-bot.test.ts
  - packages/bots/src/turtle-bot.ts
  - packages/bots/src/turtle-bot.test.ts
  - packages/bots/README.md
context:
  - packages/bots/README.md#The random bot
  - packages/bots/README.md#The greedy bot
  - packages/bots/README.md#The turtle bot
---

# T-144 — Bot draft reuse and Rest-safe attaches

## Goal

Two follow-ups from T-133's handoff, which the human approved on 2026-11-02:

- The random bot keeps its own `moveLeader` and `useResources` (`random-bot.ts`:142, :171), which repeat what `PlanDraft.moveLeader` and `PlanDraft.useResource` (`draft.ts`:130, :147) do since T-133. After this task the random bot uses PlanDraft's, and every plan it makes stays the same.
- Greedy and turtle attach the pool's first resources (`pool().slice(0, room)`) before they decide their Rest uses. So a resource with a Rest ability can go to a squad while a plain one stays in the pool, and the Rest is lost. After this task they attach plain resources first.

## Interfaces

What exists (copied from the code on 2026-11-02):

```ts
// packages/bots/src/draft.ts
export class PlanDraft {
  pool(): readonly Payer[]; // :107: resources that can still pay; a Payer has `card`
  setAside(cards: readonly CardInstanceId[]): void; // :120
  /** Moves the own Leader to the first of `spots` that fits its footprint as it stands, with its own
   *  cells free while it looks. Null, and nothing changes, with no Leader on the grid or when the first
   *  spot is where it stands. */
  moveLeader(spots: (size: Size) => readonly Spot[]): PlanAction | null; // :130
  /** Rests `resource` for its Rest ability (setAside, addSpell, reserveTarget). Null, and nothing changes,
   *  when it has no ability, `forbids` its class, it isn't in the pool, or `aim` finds no target. */
  useResource(resource: PoolResource, aim: (spec: TargetSpec) => Target | null): PlanAction | null; // :147
  //   :148 `if (resource.spell === null || this.forbids(resource.spell)) return null;`
  //   :149 `if (!this.payers.some((payer) => payer.card === resource.card)) return null;`
}

// packages/bots/src/random-bot.ts, class RandomPlanner
private moveLeader(): PlanAction[]; // :142: no Leader on the grid → [], and no number drawn; then
//   chance(this.random, ODDS.moveLeader); frees the Leader's cells; pickOne over this.free(size, false)
//   without the cell it stands on; marks the cells again; [{ action: 'moveLeader', cell }] or []
private free(size: Size, rotated: boolean): Spot[]; // :159: every free spot for a footprint turned one way
private useResources(): PlanAction[]; // :171: for each of snapshot.resources: skip when spell is null,
//   forbids, or not in the pool (no number drawn); then chance(this.random, ODDS.useResource); then the
//   target (`resource.target && this.target(resource.target)`, skip on null); setAside, reserveTarget,
//   addSpell
private attach(): PlanAction[]; // :209: random squads, sample() from pool(): stays as it is

// packages/bots/src/greedy-bot.ts:367 and turtle-bot.ts:349, private attach(): AttachAction[]
const resources = this.draft.pool().slice(0, room).map((payer) => payer.card); // turtle: pool.slice(0, room)
// greedy-bot.ts:150 restsLeft(), and the same in turtle: the Rest uses, decided after the attaches
```

What this task adds:

```ts
// packages/bots/src/draft.ts, in PlanDraft
/** Whether `resource` can rest for its ability now: it has one, `forbids` lets its class through, and
 *  it's in the pool. `useResource` checks this first. */
canUse(resource: PoolResource): boolean;
/** The pool for attaching: the resources without a Rest ability first, then the others, each part in
 *  pool order. */
attachPool(): readonly Payer[];
```

## Deliverables

1. **PlanDraft.** `canUse` and `attachPool`. `useResource` starts with `if (!this.canUse(resource)) return null;`, and behaves as before.
2. **The random bot's Leader move.** `moveLeader` returns `[]` without drawing when no Leader is on the grid, draws `chance(this.random, ODDS.moveLeader)` as now, then calls `this.draft.moveLeader(spots)`. Its `spots` returns at most one spot: `pickOne` over `this.free(size, false)` without the Leader's cell, so the numbers drawn and their order don't change.
3. **The random bot's Rest uses.** `useResources` skips a resource when `!this.draft.canUse(resource)` before it draws, then draws its chance, then calls `this.draft.useResource(resource, (spec) => this.target(spec))` and keeps a non-null action. Delete the private copies.
4. **Attaches.** Greedy's and turtle's `attach` take their resources from `attachPool()` instead of `pool()`. The random bot keeps `pool()`: it samples at random.
5. **Tests.** `draft.test.ts`: `canUse` for each reason it's false, and `attachPool`'s order. Greedy and turtle: a squad with room for one resource, and a pool with a Rest-ability resource first and a plain one second, gets the plain one, and the plan rests the other when its ability has a target.
6. **README.** Greedy's and turtle's Attach rows say resources without a Rest ability go first.

## Acceptance

- [ ] `crew check` is green, and `pnpm test:soak` passes.
- [ ] `pnpm --filter @chaosgrid/bots test` passes, and `git diff origin/main...HEAD -- packages/bots/src/random-bot.test.ts` prints nothing.
- [ ] `grep -n "private moveLeader\|private useResources" packages/bots/src/random-bot.ts` prints nothing.
- [ ] The PR says the parity check below passed.

## Out of scope

- Which squads get attaches, and how many: only which resources.
- `keepAttaches` and `keepRests` in `pool.ts`, and the random bot's attaches.
- The planner bot (T-135).

## Notes

- **Parity check.** Before deleting the random bot's copies, plan with the old and the new methods side by side for seeds 1 to 200 on every snapshot in `packages/bots/test/fixtures/`, and check the plans are equal. Don't commit the check; give its result in the PR.
- Default: a resource has a Rest ability when its `PoolResource.spell` isn't null, as `useResource` reads it. `attachPool` doesn't check whether that ability could be used now: plain resources first is enough, and `keepRests` decides the rest.
- The soaks' counts can move, D33's greedy-versus-random count and plan-abilities' `ownRests` among them. Give them before and after in the PR, and report a failure to `lead`; don't loosen a soak (as T-133).
- T-145 and T-135 edit `packages/bots` after this card.
