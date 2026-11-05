---
id: T-194
title: No Durability in the web
milestone: M5
depends_on: [T-189, T-190]
branch: agent/T-194-no-durability-in-the-web
model: sonnet
effort: high
scope:
  - apps/web/src/match/battlefield/scene.ts
  - apps/web/src/match/battlefield/scene.test.ts
  - apps/web/src/match/battlefield/sprites.test.ts
  - apps/web/src/match/battlefield/units-list.ts
  - apps/web/src/match/battlefield/units-list.test.ts
  - apps/web/src/match/planning/SquadPanel.tsx
  - apps/web/src/match/planning/PermanentPanel.tsx
  - apps/web/src/match/planning/PlanGrid.tsx
  - apps/web/src/match/planning/PlanGrid.test.tsx
  - apps/web/src/match/planning/PlanningActions.test.tsx
  - apps/web/src/match/planning/PlanningPanel.test.tsx
  - apps/web/src/art/placeholders.ts
  - apps/web/src/art/manifest-schema.ts
  - apps/web/src/art/*.test.ts
  - apps/web/src/art/*.test.tsx
  - apps/web/src/i18n/en/battlefield.json
  - apps/web/src/i18n/en/planning.json
context:
  - docs/DECISIONS.md#Decision log
  - docs/RULES.md#Units
  - docs/ART.md#Sizes
  - docs/APPS.md#The match
  - apps/web/README.md#Rules a change must keep
---

# T-194 — No Durability in the web

## Goal

D67 took Durability out of the game: core (T-189) sends `durability: null` everywhere and never emits `squad.durabilityChanged` or `permanent.durabilityChanged`, and a Fleeting card (the keyword that replaced printed Durability 0) retires at Cleanup with `squad.retired`. After this PR the web shows no Durability: the battlefield's and PlanGrid's badge becomes a Fleeting badge read from the card's keyword, and the panels and PlanGrid's label drop their Durability lines. The model keeps its Durability fields until T-200 removes them with the protocol's.

## Interfaces

What exists (copied on 2026-11-05):

```ts
// apps/web/src/match/battlefield/scene.ts
const BADGES = ['durability', 'retiring', 'rested', 'flying', 'reach', 'blocker'] as const; // :84
interface SquadCue { badges: (BadgeName | 'level')[]; durability: number | null; level: number; charged: boolean } // :330-:335
// :392  icon.setNumber(badge === 'durability' ? cue.durability : null);
// :1285 if (squad.durability !== null) badges.push(squad.durability > 0 ? 'durability' : 'retiring');
// :1293 durability: squad.durability,
// :1210 a retired squad draws nothing (squad.retired)

// apps/web/src/match/planning/PlanGrid.tsx
// :138-:148 badgesOf(): the 'retiring' badge (ui.retiring) at Durability 0, else 'durability' (ui.durability) with the number
// :447-:452 the block's label: `durability: squad.leader || squad.durability === null ? 'none' : squad.durability === 0 ? 'retiring' : String(squad.durability)`
// en/planning.json "squad.label": "{name}, level {level}{leader, select, yes {, Leader} other {}}{durability, select, none {} retiring {, Durability 0, retires this round} other {, Durability {durability}}}{canLevelUp, …"

// apps/web/src/match/planning/SquadPanel.tsx:42-:47 and PermanentPanel.tsx:25-:30: the <dt>Durability</dt> rows
// apps/web/src/art/manifest-schema.ts:54 'ui.durability' in UI_ART_KEYS; placeholders.ts:205 'ui.durability' pixel rows
// docs/ART.md › Sizes, the state badges (updated by the lead): the badges start with `ui.fleeting` when the card is Fleeting (D67);
//   then `ui.levelUp`, `ui.rested`, the level in digits from level 2, `ui.flying`, `ui.reach` and `ui.blocker`

// packages/cards (after T-189): the keyword `fleeting` in a squad card's `keywords`; no `durability` but on Emblems.
// The web's card lookup: `cards.get(squad.cardId)` (as scene.ts and PlanGrid.tsx use for keywords today).
```

Tests today: `scene.test.ts` :564 "shows Durability, retiring at 0, the card keywords and no level 1", :590; `PlanGrid.test.tsx` :176 "shows the Durability number, or the retiring icon alone at 0", :209, :217-:224 (the label text).

## Deliverables

1. **A Fleeting badge in place of Durability.** `BADGES` loses `'durability'`, and `'retiring'` becomes `'fleeting'`, drawn with `ui.fleeting`: rename the key in `manifest-schema.ts` and the placeholder rows in `placeholders.ts`, and drop `ui.durability`. A squad shows it when its card's keywords have `fleeting`, in the same first position, on the battlefield (`cueOf`) and in PlanGrid (`badgesOf`). `SquadCue.durability` goes. If an art manifest in the repo names `ui.retiring` or `ui.durability`, say so in the PR; the art pack is regenerated outside this task.
2. **Labels and panels.** PlanGrid's `squad.label` says ", Fleeting, leaves at Cleanup" for a Fleeting card and nothing about Durability. `SquadPanel` and `PermanentPanel` lose their Durability rows. The hidden battlefield list (`units-list.ts`) names Fleeting where it named Durability, if it did.
3. **Tests.**
   - `scene.test.ts`: the Fleeting badge from the card's keyword, no Durability icon and no number.
   - `PlanGrid.test.tsx`: the same, and the label text.
   - The panel tests: no Durability row.
   - The art tests: `ui.fleeting` has a placeholder, and `ui.durability` and `ui.retiring` are gone.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test scene PlanGrid Planning units-list art manifest` passes.
- [ ] `pnpm test` passes.
- [ ] `grep -rli durability apps/web/src/match apps/web/src/art --include=*.ts --include=*.tsx --exclude=*.test.ts --exclude=*.test.tsx` lists only `model/apply.ts` and `model/types.ts`.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The model's Durability (`SquadModel.durability`, `PermanentModel.durability`, the two `*.durabilityChanged` handlers), the test literals and the fixtures: T-200 removes them with the protocol's fields. They stay valid data until then.
- `CardView.tsx`, `CardFace.tsx` and `MatchScreen.tsx`: T-192 edits them in this wave. The cards page shows an Emblem's printed Durability, which stays.
- The round log and `model/`: T-193 edits them in this wave.
- `docs/ART.md`: the lead's.

## Notes

- After T-189 every snapshot's `durability` is null, so a Fleeting squad looks like any other in the snapshot: read the keyword, not the number.
- The badge order (ART.md › Sizes) stays otherwise: Fleeting first, then level-up, rested, level digits, flying, reach, blocker.
