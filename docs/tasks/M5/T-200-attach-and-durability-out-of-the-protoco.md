---
id: T-200
title: Attach and Durability out of the protocol
milestone: M5
depends_on: [T-194, T-195, T-196, T-197, T-198]
branch: agent/T-200-attach-and-durability-out-of-the-protoco
model: sonnet
effort: high
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/core/**
  - packages/bots/**
  - tools/sim-cli/**
  - apps/web/src/**
  - apps/web/test/**
  - apps/web/README.md
context:
  - docs/DECISIONS.md#Decision log
  - docs/PROTOCOL.md#Plans
  - docs/PROTOCOL.md#Snapshot
  - docs/PROTOCOL.md#Versioning
  - apps/web/test/fixtures/logs/README.md#Regenerate
---

# T-200 — Attach and Durability out of the protocol

## Goal

D67 and D68 end with this PR. Since T-189 every Durability field is null and no `*.durabilityChanged` event is sent; since T-196 and T-197 nobody plans `attach`. The transitional types go, and the optional fields that replaced them become required, so a snapshot, an event and a plan say only what the game still has. Nothing changes for a player.

## Interfaces

What exists (copied on 2026-11-05; line numbers moved since, so grep the names):

```ts
// packages/protocol/src/plan.ts: AttachAction ({ action: 'attach', squad, resources }), in PlanAction and PlanActionType
// packages/protocol/src/event.ts: ResourcesAttachedEvent ('resources.attached'), ResourcesDetachedEvent ('resources.detached'),
//   SquadDurabilityChangedEvent, PermanentDurabilityChangedEvent, `durability` on SquadPlacedEvent and SquadLeveledEvent;
//   the event union and packages/protocol/src/index.ts export them; visibility.ts has a case for each
// packages/protocol/src/snapshot.ts: PoolCard.attachedTo and PoolResource.attachedTo (SquadId.nullable()),
//   SquadSnapshot.attached (Count) and .durability, PermanentSnapshot.durability, the unit HandCard's durability (nullable since T-189)
// packages/protocol/src/primitives.ts:42 Durability = z.int().min(0)
// Optional until now: SquadSnapshot.charged (T-193); payable on HandCard, LeaderCard and AbilityUse,
//   SquadSnapshot.levelUpPayable and .chargePayable (T-195). SquadSnapshot.levelUpCost stays optional: another seat's
//   squads leave it out.
// packages/core: the `attach` step (plan/apply.ts), zones/resources.ts attachResources / detachResources / spendAttached and
//   Cleanup's detach, Squad.attached, isCharged's attached clause (effects/sources.ts), effects/rules.ts's case,
//   view/board.ts `attached`, view/seats.ts `attachedTo`, round/rebuild.ts
// packages/bots: random-bot.ts attach() and ODDS.attach; test/referee.ts's attach case; fixtures and test literals
// tools/sim-cli/src/game.ts:291 counts "unrested and unattached" resources; test/golden-script.ts:171 an `attach`
// apps/web/src/match/model: SquadModel.durability, PermanentModel.durability, the durabilityChanged handlers and the
//   ignored resources.* cases (T-194 and T-197 kept them for this PR); test literals across apps/web/src;
//   apps/web/test/fixtures/planning/*.json (durability, attached, attachedTo) and the two logs in test/fixtures/logs/
```

Attached permanents (equipment and auras: `mode: 'attached'`, `castPermanent` with `mode: 'attached'`, `PermanentSnapshot`'s `squad`) are a different thing and stay. The Emblem's printed `durability` stays on its card (packages/cards) and becomes its HP, as `emblem.placed`'s `hp` says.

## Deliverables

1. **The protocol.** Remove everything listed above, the `Durability` primitive with them unless an Emblem field still uses it. Make `charged`, the `payable` fields, `levelUpPayable` and `chargePayable` required. Bump `PROTOCOL_VERSION` (35), with docs/PROTOCOL.md's title, its field types, Plans, Planning and Board events, Visibility and Snapshot sections, and a Versioning row naming D67 and D68. In `plan.ts`, `RestForManaAction`'s doc comment cites D58, which D64 replaced: make it D64.
2. **Core** stops building and reading what's gone: the `attach` step and its zone functions, `Squad.attached` and the resources' attached state, isCharged's attached clause (a squad is charged only by `charge`), the views' fields, the rebuild's reads.
3. **The bots.** The random bot stops attaching (its every-type test follows `PlanActionType`). The referee loses its attach case. Fixtures and literals drop the gone fields and gain the required ones.
4. **sim-cli.** `game.ts` counts unrested resources. The golden script charges where it attached (the squad it attached to, if its card has Charge; else say what you picked), and its fixture cards follow; regenerate the golden streams as `golden.test.ts` says, and say why in the PR.
5. **The web.** The model drops its Durability and attach leftovers. Every test literal and the planning fixtures drop the gone fields and gain the required ones. Regenerate the two event logs with the commands in `apps/web/test/fixtures/logs/README.md`, then Prettier, and update that README's table; the old logs no longer parse.
6. **Tests.** `plan.test.ts` refuses an `attach` action as an unknown action; the event tests have no attach or Durability event; the snapshot tests require the new fields. Everything that passed before passes.
7. **The preview table.** The core README's "What a preview costs" table predates the Chaos factor (D65): the busiest scripted snapshot is no longer round 8 with 178 units. You run alone, so rerun `round/perf.test.ts` (`pnpm --filter @chaosgrid/core exec vitest run src/round/perf.test.ts --silent=false`) and put the times it prints in the table, with the snapshot's round and unit count. T-204 measured 371 units, about 1.3 s for 1,000 ticks and about 2.2 s for 3,000, beside other workers.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm test` passes.
- [ ] `pnpm test:soak` passes.
- [ ] `pnpm test:e2e` passes, or the PR says why it couldn't run.
- [ ] `grep -rn "attachedTo\|'attach'\|resources\.attached\|resources\.detached\|durabilityChanged" packages apps tools --include=*.ts --include=*.tsx` finds nothing.
- [ ] `grep -rli durability packages/protocol packages/bots tools/sim-cli/src apps/web/src/match` finds nothing.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Any behavior change: if a test needs one to pass, stop and say which.
- `packages/cards`: the Emblem's `durability` stays, and the cards page shows it.
- The planning surface (T-199, T-202) and the removal cards (T-201): next wave.

## Notes

- This PR runs alone in its wave because it touches every package's literals. Rebase on main just before you start.
- The planning fixtures are hand-made snapshots: edit them, don't regenerate them.
