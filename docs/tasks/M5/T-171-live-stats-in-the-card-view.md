---
id: T-171
title: Live stats in the card view
milestone: M5
depends_on: [T-161, T-170]
branch: agent/T-171-live-stats-in-the-card-view
model: sonnet
effort: medium
scope:
  - apps/web/src/match/CardView.tsx
  - apps/web/src/match/CardView.test.tsx
  - apps/web/src/match/MatchScreen.tsx
  - apps/web/src/match/MatchScreen.test.tsx
  - apps/web/src/i18n/en/match.json
context:
  - docs/RULES.md#Units
  - apps/web/README.md#Text (D50)
  - apps/web/README.md#Tests
---

# T-171 — Live stats in the card view

## Goal

The human's playtest (2026-11-04): "on simulation, when clicking permanents show current stats: HP, speed, attack, etc.. not the static MAX HP, etc.. if buffs were applied then stats change".

A click on a unit opens its card in the card view, which shows the printed level-1 stats only. After this task the view also shows the unit's stats now: HP left of its maximum, Attack, Attack speed, Speed, range and keywords, as core last sent them (T-170). They change while the view is open as the round plays.

## Interfaces

What exists (copied on 2026-11-04, and from the T-170 card):

```ts
// apps/web/src/match/CardView.tsx:21
export type CardViewSubject =
  /** `caption`: whose it is, and a unit's level. `attached`: the cards on the unit's squad, listed after it. */
  | { kind: 'card'; card: Card; caption?: string; attached?: readonly Card[] }
  | { kind: 'prize'; seat: Seat; hp: number };
// CardView.tsx:74 PrizeSubject reads useSession().state, which follows playback.

// apps/web/src/match/MatchScreen.tsx:128 subjectOf(pick, state, cards): a battlefield pick's subject;
// for a unit, { kind: 'card', card, caption: "You, level 2", attached }; for a squad's footprint (T-172), the same.

// T-170: UnitModel.stats is LiveUnitStats | null ({ maxHp, attack, attackSpeed, speed, range,
// minRange, damageTaken }, rates per second, ranges in cells) and UnitModel.keywords is Keywords | null.
// apps/web/src/cards/names.ts: keywordName, rangeName.
```

## Deliverables

1. **The subject names its unit.** The `card` subject takes an optional `unit` (a `UnitId`). `subjectOf` passes the picked unit's, and for a squad's footprint its first living unit's, by id.
2. **A "Now" block.** When the subject has a `unit` and the model's `stats` for it aren't null, the view shows a block after the card face, labelled "Now", read from the model on every render so it follows playback. It lists:
   - HP as "7 / 12";
   - Attack;
   - Attack speed per second;
   - Speed in cells per second;
   - range in cells, with the minimum range when it's above 0;
   - damage taken, only when it isn't ×1;
   - the keywords from `UnitModel.keywords`, named with `keywordName`.

   A dead unit's block says it's dead instead. Text goes through `t()`, in `en/match.json` under `match.cardView`.
3. **Tests in `CardView.test.tsx`:**
   - A unit subject whose model stats differ from the card's shows the model's values.
   - Its block changes when the model changes while the view is open.
   - A unit with null `stats` shows no block, and neither does a card subject with no `unit`.
   - Damage taken ×1 shows no line, and ×0.5 shows one.

   In `MatchScreen.test.tsx`: picking a unit opens a subject with its `unit`, and picking a squad's footprint one with its first living unit's.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test CardView MatchScreen` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Marking which stats a buff changed. Levels scale HP and Attack in core, and the web doesn't know the scaling, so the view shows the values beside the printed face.
- Live stats for prizes and other permanents: their HP is already shown.
- The badges on the grid: T-162 and T-166.

## Notes

- Defaults: the block is a `<dl>`, with numbers written as core sends them, up to two decimals.
- Between rounds the model keeps the stats core sent after Cleanup, so the block also shows during Plan.
