---
id: T-145
title: Kill points for Chaos and tokens
milestone: M5
depends_on: [T-144]
branch: agent/T-145-spawned-kill-points
model: opus
effort: medium
scope:
  - packages/protocol/src/snapshot.ts
  - packages/protocol/src/snapshot.test.ts
  - packages/protocol/src/version.ts
  - packages/protocol/test/fixtures/**
  - packages/protocol/README.md
  - docs/PROTOCOL.md
  - packages/core/src/scoring/points.ts
  - packages/core/src/scoring/points.test.ts
  - packages/core/src/view/units.ts
  - packages/core/src/view/snapshot.test.ts
  - packages/core/test/fixtures/**
  - packages/bots/src/value.ts
  - packages/bots/src/value.test.ts
  - packages/bots/src/targets.ts
  - packages/bots/src/targets.test.ts
  - packages/bots/src/greedy-bot.test.ts
  - packages/bots/src/placement.test.ts
  - packages/bots/test/fixtures/**
  - packages/bots/README.md
  - apps/web/test/fixtures/planning/*.json
context:
  - docs/RULES.md#Scoring and winning
  - docs/PROTOCOL.md#Snapshot
  - docs/PROTOCOL.md#Versioning
  - packages/bots/README.md#The greedy bot
---

# T-145 — Kill points for Chaos and tokens

## Goal

A Chaos squad's kill points are printed on its Chaos card, and a token's come from its card's cost (RULES.md › Scoring and winning). The snapshot carries neither, so since T-130 the bots count both as 0: a spell goes to an opponent's grid squad even when a Chaos squad would score more, and a token is aimed at by level alone. On 2026-11-02 the human asked for the value in the snapshot, so the bots aim by it.

After this task each `SpawnedSquadSnapshot` says what killing one of its units scores, the protocol is version 27, and the bots rank Chaos squads and opponents' tokens by kill points next to the grid squads.

## Interfaces

What exists (copied from the code on 2026-11-02):

```ts
// packages/protocol/src/snapshot.ts:345
export const SpawnedSquadSnapshot = z.strictObject({
  squad: SquadId, owner: Owner, card: CardInstanceId, cardId: CardId,
  kind: z.enum(['chaos', 'token']),
  stats: UnitStats, // the printed stats of the unit it was spawned as
  keywords: Keywords, // that unit's printed ones
  level: Level,
});
// Points (:65, :96) is the schema PlayerSnapshot's and SeatScore's points use: fractions allowed.
// packages/protocol/src/version.ts:6
export const PROTOCOL_VERSION = 26;

// packages/core/src/scoring/points.ts
export function costValue(cost: string): number; // :45
export function unitKillPoints(cost: number, level: number, unitsPerSquad: number): number; // :53: cost × level ÷ units
export function killGains(state: GameState, { unit, killer }: Kill): Gain[]; // :71
//   a Chaos card: 'chaosKill', card.points / card.squad (:78-80)
//   else 'kill', unitKillPoints(costValue(card.cost), squad.level, card.squad) + the killer's
//   pointsPerOpponentUnitKilled, and 'leaderKill', a Leader's leaderBonus / card.squad
// packages/core/src/view/units.ts:49
export function spawnedSquads(state: GameState): SpawnedSquadSnapshot[];

// packages/bots/src/value.ts:36
/** What killing the whole squad scores: cost × level, plus max(3, cost) for a Leader. */
export function killPoints(squad: SquadSnapshot): number;
// packages/bots/src/targets.ts
export function looseSquadsOf(snapshot: Snapshot): LooseSquad[]; // :66: spawned squads with a living
//   unit, as { squad, owner, level, warded }
function aimable(spec, view): LooseSquad[]; // :121: loose squads of other owners, not warded ones for 'opponent'
function pickEnemySquad(spec, view, context): Target | null; // :262
//   1. context.chaosTarget when aimable lists it
//   2. bestBy the opponents' grid squads that allows() passes:
//      [killPoints, dps, the owner's points, -seat]
//   3. else bestBy(aimable, level)
```

Web fixtures that pin the version: `apps/web/test/fixtures/planning/snapshot.json`, `snapshot-zones.json` and `snapshot-actions.json` (`"protocolVersion": 26`, each with an empty `spawned`).

What this task adds:

```ts
// packages/protocol: SpawnedSquadSnapshot gains
/** What killing one of its units scores the killer now, before the killer's own scoring modifiers:
 *  a Chaos card's points ÷ its squad size, else the card's cost × level ÷ its squad size. */
pointsPerKill: Points,
// PROTOCOL_VERSION = 27

// packages/core/src/scoring/points.ts
/** What killing one unit of `squad` scores before the killer's modifiers and a Leader's bonus:
 *  killGains' 'chaosKill' amount for a Chaos squad, its base 'kill' amount otherwise. */
export function unitKillValue(state: GameState, squad: SquadId): number;

// packages/bots/src/value.ts
/** What killing a spawned squad's living units scores: pointsPerKill × those units in snapshot.units. */
export function spawnedKillPoints(snapshot: Snapshot, squad: SpawnedSquadSnapshot): number;
```

## Deliverables

1. **Protocol.** `pointsPerKill` on `SpawnedSquadSnapshot`, `PROTOCOL_VERSION` 27, and the samples and tests. `docs/PROTOCOL.md`: the title's version, the `SpawnedSquadSnapshot` paragraph, `PROTOCOL_VERSION` in Versioning, and a row 27 in its table.
2. **Core.** `unitKillValue`, and `killGains` computes its 'chaosKill' and base 'kill' amounts with it, so the two can't drift. `spawnedSquads` fills `pointsPerKill` with it.
3. **Bots.** `LooseSquad` carries its kill points (`spawnedKillPoints`). `pickEnemySquad` keeps `chaosTarget` first. Then one ranking of the opponents' grid squads that `allows` passes and the loose squads `aimable` lists: kill points, dps, the owner's points (a Chaos squad's owner has 0), grid squads before loose ones, then the lowest seat. The README's greedy Other row says Chaos squads and tokens count their kill points.
4. **Fixtures.** The three web planning fixtures say `"protocolVersion": 27`. Every test or fixture that builds a `SpawnedSquadSnapshot` gets a `pointsPerKill`.
5. **Tests.** Core: `unitKillValue` equals `killGains`' amount for a Chaos unit, a token at level 2 and a player's unit; a snapshot's Chaos squad and token show those values. Bots: an opponent's token worth more than every grid squad is picked; a Chaos squad worth less than a grid squad isn't; with no grid squad, the loose squad worth the most beats one of a higher level.

## Acceptance

- [ ] `crew check` is green, and `pnpm test:soak` passes.
- [ ] `grep -c "PROTOCOL_VERSION = 27" packages/protocol/src/version.ts` prints 1, and `grep -c '"protocolVersion": 27' apps/web/test/fixtures/planning/*.json` prints 1 for each file.
- [ ] `pnpm --filter @chaosgrid/core test points snapshot`, `pnpm --filter @chaosgrid/bots test` and `pnpm --filter @chaosgrid/web test planning` pass.
- [ ] `pnpm --filter @chaosgrid/core test` passes with `scoring/points.test.ts`'s existing tests unchanged.

## Out of scope

- A row's kill points (Scorch Line's row, `targets.ts`:304): it sums grid squads only.
- Showing the value in the web, and prize points (`PRIZE_VALUE` stays 2, T-130).
- Replays saved under version 26: they stop parsing, as with every bump.

## Notes

- The human's pick, 2026-11-02. The lead had suggested waiting; the human chose to do it now.
- Default: the field is per unit, not per squad. A squad's living units change during a round, and `units` already lists them.
- Default: the value leaves out the killer's own modifiers (`pointsPerOpponentUnitKilled`) and a Leader's bonus. A spawned squad is never a Leader, and the bots' `killPoints` for grid squads ignores modifiers too.
- Default: a token is scored like any opponent's unit, from its card's cost. A token whose card has no cost is worth 0, which is what core awards.
- The soaks' counts can move: give D33's greedy-versus-random count before and after in the PR, and report a failure to `lead` instead of loosening it.
- T-135 waits for this card: its planner ranks targets with these functions.
