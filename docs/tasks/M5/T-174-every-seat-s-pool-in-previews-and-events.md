---
id: T-174
title: Every seat's pool in previews and events
milestone: M5
depends_on: [T-170, T-173]
branch: agent/T-174-every-seat-s-pool-in-previews-and-events
model: opus
effort: high
scope:
  - packages/core/src/**
  - packages/core/test/**
  - packages/core/README.md
  - packages/protocol/src/preview.ts
  - packages/protocol/src/event.ts
  - docs/PROTOCOL.md
  - packages/bots/src/**
  - packages/bots/test/fixtures/**
  - packages/bots/README.md
  - tools/sim-cli/test/**
context:
  - docs/DECISIONS.md#Decision log
  - packages/core/README.md#Previews
  - packages/bots/README.md#The planner bot
  - docs/PROTOCOL.md#Round previews
  - docs/RULES.md#Resources and attaching
---

# T-174 — Every seat's pool in previews and events

## Goal

Two follow-ups to the public pools (D57), from T-157's review. The human picked the first on 2026-11-04.

- **Previews (D63, which replaces D55).** A bot's preview rebuilds only its own pool, and every guess borrows copies of it: before D57 the other pools were hidden. After this task a preview rebuilds every seat's pool from the snapshot, and the planner's guess for a seat pays with that seat's own resources.
- **A missing event.** D57 says "Every change to a pool is an event that everyone sees". But when Overclock spends a squad's attached resources, they come off the squad at once with no event, so clients show them attached until Cleanup. That leaves T-162's Charge glow on a squad whose Charge is off. After this task core sends `resources.detached` for them.

## Interfaces

What exists (copied on 2026-11-04):

```ts
// packages/core/src/round/rebuild.ts:27, on stateFromSnapshot (:38): "What the snapshot doesn't show
// isn't there: decks, other seats' hands, pools and face-down traps, ..."; :172 rebuilds only the
// seat's own pool: own.resourcePool.push(...snapshot.resources.map((resource) => resource.card)).
// packages/core/src/round/preview.ts:98 lendCards(state, snapshot, seat, guess): "Gives seat its own
// copies of the snapshot's hand cards and resources (D55), and returns guess with the copies' ids."

// packages/bots/src/planner-bot.ts:82 guessOthers: greedy for each other seat on asSeat(snapshot, seat),
// "as if it held the planner's hand and pool (their own are hidden)":
function asSeat(snapshot: Snapshot, seat: Seat): Snapshot {
  return { ...snapshot, seat, leader: null,
    resources: snapshot.resources.map((resource) => ({ ...resource, attachedTo: null })) };
}

// packages/protocol/src/snapshot.ts:110 PlayerSnapshot { ..., resourceCount, pool: PoolCard[] }:
// "The seat's pool in pool order, attached resources included. Public (D57)."
// packages/protocol/src/preview.ts:49 GuessedPlans: "A guess may play the previewing seat's own hand
// cards and resources: each guessed seat plays copies of them."

// packages/core/src/effects/handlers/spendAttachedResources.ts: "each target squad's attached
// resources come off it at once, which switches its 'If charged' abilities off, and go to the bottom
// of the resource deck at Cleanup". Overclock is the only card that uses it.
// packages/protocol/src/event.ts:170 resources.detached { seat, squad, resources }: "the squad was banished".
// resources.spent { seat, resources }: at Cleanup, to the bottom of the resource deck.

// packages/bots/test/fixtures/turtle.ts:132 and snapshots.ts:65: `pool: []` with a resourceCount above 0.
```

## Deliverables

1. **D63 in core.**
   - `stateFromSnapshot` rebuilds every seat's pool from `players[].pool`, keeping each resource's id, whether it's rested, and its attachment.
   - A guess pays with its own seat's resources, by those ids. `lendCards` copies only the previewing seat's hand cards.
   - The rebuild's comment and the packages/core README's › Previews follow: pools are known now, while hands aren't.
2. **D63 in the bots.**
   - `asSeat` gives the guessed seat its own pool from the snapshot, in place of the planner's.
   - `guessOthers`' comment and the bots README's Guesses paragraph follow.
3. **The citations.** The `GuessedPlans` comment and docs/PROTOCOL.md › Round previews cite D63 and say what a guess may name. A preview isn't a message, so `PROTOCOL_VERSION` stays.
4. **The spend is an event.** When `spendAttachedResources` takes a squad's resources off it, core sends `resources.detached` for them in that tick. The event's comment and its row in PROTOCOL.md name both causes: a banish, and a spend, whose resources still go to the bottom of the resource deck at Cleanup (`resources.spent`). The payload doesn't change, so neither does the version.
5. **Cleanup in PROTOCOL.md.** The `round.ended` row says what Cleanup did without events of its own: every resource and permanent is unrested, and every attached resource that wasn't spent is back in its pool, unattached. The web model already applies both at `round.ended`.
6. **The bots' fixtures** list as many resources in each `pool` as its `resourceCount` says.
7. **Tests:**
   - core: a preview's state has every seat's pool with its ids and rested resources;
   - core: a guess that pays with a resource of a color only its seat has is applied;
   - core: a guess that names one of the previewing seat's resources doesn't pay with it;
   - core: Overclock sends `resources.detached` for its target's resources in the tick it resolves, then `resources.spent` at Cleanup;
   - bots: `asSeat` for another seat carries that seat's pool;
   - bots: a seat holding Light resources gets a guess that casts a Light card the planner's own pool couldn't pay for.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm test:soak` passes, the planner's soak against greedy included. The PR gives its numbers before and after.
- [ ] `pnpm test:perf` passes, and the PR gives `round/perf.test.ts`'s preview times before and after.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Guessing other seats' hands, or the resources they draw this round: both stay hidden until their plans apply.
- The web: its model already reads `resources.detached` and applies Cleanup at `round.ended`.
- An event for each of Cleanup's resets.

## Notes

- During Plan the snapshot shows the other pools as Plan opened, before this round's 2 draws (D57). A guess therefore plans with 2 resources fewer than its seat has, and D63 accepts that.
- At Plan's start no resource is attached, since Cleanup returned them all, so the rebuild's attachments only matter to a snapshot taken later.
