---
id: T-099
title: Round rules in the snapshot, bots respect them
milestone: M3
depends_on: [T-060, T-064]
branch: agent/T-099-bots-respect-rules
model: sonnet
effort: medium
scope:
  - packages/protocol/**
  - docs/PROTOCOL.md
  - packages/core/src/view/**
  - packages/core/src/effects/rules.ts
  - packages/core/src/effects/rules.test.ts
  - packages/bots/src/**
  - packages/bots/test/**
  - packages/bots/README.md
context:
  - docs/PROTOCOL.md#Snapshot
  - packages/cards/README.md#Spell classes
  - packages/cards/README.md#Rules
  - packages/bots/README.md#Files
---

# T-099 — Round rules in the snapshot, bots respect them

## Goal

Fog of War (`packages/cards/data/chaos/fog_of_war.json`) turns `noSpells` on for every player for the round. Core then rejects a defensive or offensive spell as `forbidden`. But neither the snapshot nor the bots know the rule is on, so bots cast anyway and lose the action.

T-060's cards changed what the generated decks draw, and since its merge the M2 soak is red on `main`: `tools/sim-cli/test/m2-done-when.soak.test.ts`, "4 turtle seats, generated decks, seed 4: rejected {forbidden:2}". Both rejections are `castSpell`/`forbidden` on seat 0 under Fog of War.

Put the rules that are on for the viewing seat in the snapshot, and make every bot respect `noSpells`, so the soak is green again.

## Interfaces

What exists (copied from the code on 2026-10-27, after T-064's merge):

```ts
// packages/cards/src/dsl.ts:240
export const RULES = ['noSpells', 'trampleHitsFriendlyUnits', 'noHandSizeLimit'] as const;
export type Rule = (typeof RULES)[number];
// protocol imports nothing, so it has no Rule enum yet.

// packages/core/src/effects/rules.ts (imports ../view/cards, so view/cards.ts must not import it back: D35)
export interface ActiveRule { rule: Rule; seat: Seat; source: EntityId | null; cardId: CardId | null }
export function activeRules(state: GameState): ActiveRule[];  // statics in play, then lasting ones; duplicates possible
export function ruleActive(state: GameState, rule: Rule, seat: Seat | 'chaos'): boolean;
export function forbiddenByRules(state: GameState, seat: Seat, action: PlanAction): boolean;
// spellClassOfAction: null or 'utility' → false, else ruleActive(state, 'noSpells', seat).
// Covers castSpell, useResource (a Rest ability) and useAbility.
// round/play.ts:45 wires it: forbidden: (seat, action) => forbiddenByRules(state, seat, action)

// packages/core/src/view/snapshot.ts
export function snapshotFor(state: GameState, seat: Seat): Snapshot;

// packages/core/src/projectiles/kinds.test.ts:9: the enum sync pattern to copy
expect(ProjectileKind.options).toEqual([...PROJECTILE_KINDS]);

// packages/protocol/src/snapshot.ts
// Snapshot: protocolVersion, seat, round, phase, tick, settings, players, arena, hand, leader,
//           resources, squads, units, spawned, permanents, chaos, emblems, prizes (snapshot.ts:356)
// HandCard (spell): spell: SpellClass; PoolResource: spell: SpellClass.nullable();
// AbilityUse: ability, cost, rest, spell: SpellClass, target?, usable
// packages/protocol/src/card.ts:109  SpellClass = z.enum(['utility', 'defensive', 'offensive'])
// packages/protocol/src/version.ts:6 PROTOCOL_VERSION = 19 (T-064's)

// packages/bots/src/draft.ts, class PlanDraft(snapshot)
castCard(card: HandCard, choices: CastChoices): PlanAction | null;  // :137, castSpell at :234-236
useAbility(holder, use, target);                                    // :167
addSpell<T extends PlanAction>(action: T): T;                       // :185
// packages/bots/src/random-bot.ts:165 useResources(): the only useResource builder (draft.addSpell at :175, :179)
// greedy-bot.ts and turtle-bot.ts build every spell through PlanDraft.
// packages/bots/test/referee.ts: case 'castSpell' :259, 'useResource' :266, 'useAbility' :275
```

Hand-built `Snapshot`s that need the new field: `packages/protocol/test/fixtures/samples.ts`, `packages/bots/test/fixtures/{snapshots,turtle}.ts`, `packages/bots/src/{random-bot,greedy-bot,placement,grid}.test.ts`.

## Deliverables

1. **Protocol.** A `Rule` enum in `packages/protocol/src/` with the same values in the same order as the cards' `RULES`. A core test, next to `effects/rules.test.ts`'s others, checks `Rule.options` equals `[...RULES]`, the way `kinds.test.ts` does.
2. **`Snapshot.rules: z.array(Rule)`.** The rules on for the viewing seat right now: each rule once, in `RULES` order, `[]` when none is. Other seats' rules stay out (see Notes). Bump `PROTOCOL_VERSION` by one and add the row to docs/PROTOCOL.md › Snapshot.
3. **Core.** `snapshotFor` fills it with `ruleActive(state, rule, seat)` for each rule, or a small helper in `effects/rules.ts`. No new import cycle: `view/snapshot.ts` may import `effects/rules.ts`, `view/cards.ts` may not.
4. **Bots.** Under `noSpells`, no bot plans a defensive or offensive spell. Utility spells stay allowed.
   - Default: `PlanDraft` checks it in one place. `castCard` and `useAbility` return `null` for such a spell, and `random-bot`'s `useResources` skips such a resource.
   - Bots that pick among options must pick something else, not give up the action.
5. **Referee.** `packages/bots/test/referee.ts` rejects a defensive or offensive `castSpell`, `useResource` or `useAbility` when `snapshot.rules` has `noSpells`, as core does.
6. **Docs.** `AbilityUse.usable` keeps its meaning. Its PROTOCOL.md line says it doesn't look at round rules: read `Snapshot.rules`. One line in packages/bots/README.md says the bots respect `noSpells`.

## Acceptance

- [ ] `scripts/check.sh` is green.
- [ ] `scripts/check.sh soak` is green, including "4 turtle seats, generated decks, seed 4".
- [ ] For each of the random, greedy and turtle bots, a test gives it a snapshot with `rules: ['noSpells']` and a hand with a defensive, an offensive and a utility spell. Over many seeds it plans neither of the first two, and the referee passes the plan. The random bot also plans the utility spell at least once.
- [ ] A referee test rejects an offensive `castSpell` under `noSpells` and passes it with `rules: []`.
- [ ] A core test: with Fog of War in play, every seat's snapshot has `rules` `['noSpells', 'trampleHitsFriendlyUnits']`. Without it, `[]`.

## Out of scope

- Making a soak tolerate `forbidden` rejections, or skipping a seed or a card in it (see Notes: the human ruled it out).
- Other seats' rules in the snapshot.
- Changing what `AbilityUse.usable` means, or adding a per-card "forbidden" flag.
- Card data, and core's rules logic (`forbiddenByRules` stays as it is).
- Bot strategy for `trampleHitsFriendlyUnits` and `noHandSizeLimit`: they're in the snapshot, but no bot has to act on them.
- Mirror Snare as a copy plus a counter (it stays a script).

## Notes

- From T-060's handoff (2026-10-27): the red soak appears only because the new cards change what the generated decks draw. It's green with the mechanics set filtered out, and it isn't a card bug (`ember_forgehand` and `dawn_attendant` were ruled out). Lead decision: T-060 was handed off and merged with this soak red. This task turns it green.
- Decision (human, 2026-10-27). T-064 hit the same failure on `main` and asked: "should a bots task make the bots avoid spells under `noSpells` (or should the test tolerate it)?" The answer: a bots task makes the bots avoid them, and this is that task. PLAN.md › M2 and › M3 already allow no rejected plan action at a one-bot table, so the soak stays as strict as it is.
- Why only the viewing seat's rules: Old Library's `noHandSizeLimit` comes from a card in its owner's resource pool, and other seats' pools aren't in the snapshot (`PlayerSnapshot` has only `resourceCount`). Listing their rules would leak it.
- Today `noSpells` comes only from Fog of War, a Chaos card, so it's already on when Plan starts. A Plan-time snapshot therefore shows what `applyPlans` will check.
- It runs after T-064, whose scope holds all of this one's, and T-065 waits for it, because both edit the protocol and `packages/core/src/**`. Until it merges, every soak run on `main` and on other branches shows the same `forbidden:2`. A worker who sees only that failure says so in the handoff and doesn't chase it.
- If the soak fails for another reason after the fix, don't widen the scope: send `lead` the seed and the rejection.
