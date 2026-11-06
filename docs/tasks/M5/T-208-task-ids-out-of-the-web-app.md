---
id: T-208
title: Task ids out of the web app
milestone: M5
depends_on: [T-205, T-206]
branch: agent/T-208-task-ids-out-of-the-web-app
model: sonnet
effort: medium
scope:
  - apps/web/**
  - docs/APPS.md
  - docs/ART.md
context: []
---

# T-208 — Task ids out of the web app

## Goal

The code repo is shared, and nothing in it refers to the plan (D73). The web app and its docs still do, in about 175 lines on 2026-11-06's main: task ids (`(T-192)`, `// T-087: the planning panel's…`), milestones (`M6's WsTransport`, `M4/README.md › The match`), "later tasks", and an e2e spec named after a milestone, `m4.spec.ts`. After this PR none are left, and each comment, test title and doc line says what the code does and why on its own.

## Interfaces

```sh
# What's left (also the acceptance check): every reference in the scope
git grep -n -I -E '(^|[^A-Za-z0-9_])(T-[0-9]{3}|M[0-9])([^0-9A-Za-z]|$)|PLAN\.md|later tasks?|task card' -- apps/web docs/APPS.md docs/ART.md

# The mechanical pass: drops task ids from parentheses. " (T-192)" goes with its leading space;
# "(T-158, D58)" and "(D58, T-158)" become "(D58)".
# A tag right after //, * or # stays for the hand edits: the sentence around it needs rewording.
git grep -l -z -I -E 'T-[0-9]{3}' -- apps/web docs/APPS.md docs/ART.md \
  | xargs -0 perl -pi -e 's/(?<![\/*#])\((?:T-\d{3}, )+/(/g; s/, T-\d{3}(?=[,)])//g; s/(?<![\/*#]) \(T-\d{3}\)//g'
```

On a copy of 2026-11-06's main, the pass left about 90 lines in 26 files for the hand edits, most of them in `docs/APPS.md`. Examples from this scope:

| Before | After |
| --- | --- |
| `// T-087: the planning panel's spells, targets, …` | `// The planning panel's spells, targets, …` |
| `/** The name bar's cost pips on their own, for T-158's floating mana and T-159's list rows. */` | `/** The name bar's cost pips on their own, for the floating mana and the list rows. */` |
| `/** What the UI holds (M4/README.md › The match). */` | `/** What the UI holds (APPS.md › The match). */`: the M4 README's match section is APPS.md's now |
| `// M6's WsTransport plugs in without changing the screens.` | `// A WebSocket transport plugs in without changing the screens.` |
| `it('sets every custom property later tasks use, from the same colors as PALETTE', …)` | `it('sets every custom property from the same colors as PALETTE', …)` |
| `/* What a later task dims: an illegal deck in the lobby, for one. */` | what dims with it now, or nothing if nothing does yet |

## Deliverables

1. **The pass**, then the hand edits, until the check prints nothing. Read only the lines it prints and a few around them, not whole files.
2. **The hand edits** follow D73 and CLAUDE.md › Conventions › Comments, test titles and docs:
   - Say what the code does now. A pointer to other work ("T-050 adds them", "a later task") becomes a plain statement of the current behavior, or goes if the code already says it.
   - In `docs/APPS.md`, a line that says which task built or owns a file says what the file is instead.
   - A comment left with nothing to say goes.
   - Test titles and log labels change the same way.
3. **`apps/web/e2e/m4.spec.ts` becomes `apps/web/e2e/new-player.spec.ts`** (`git mv`), after its first test, "a new player plays a game". Its mentions in `apps/web/README.md` and `docs/APPS.md` follow.
4. **Nothing else changes:** no code, no identifiers, no behavior.

## Acceptance

- [ ] `crew check` green
- [ ] `CHAOSGRID_WEB_PORT=4208 CHAOSGRID_API_PORT=5208 pnpm test:e2e` passes and runs `new-player.spec.ts`
- [ ] the first command in Interfaces prints nothing
- [ ] `git diff --stat main...HEAD` lists only files in the scope

## Out of scope

- `docs/DECISIONS.md`: a decision is never rewritten (DECISIONS.md › How decisions change), so its rows keep their ids.
- `CLAUDE.md`: the lead's.
- Core and the protocol (T-207), and the other packages, sim-cli and the root files (T-209).
- Any other cleanup you notice: report it in the PR.

## Notes

- Keep decision ids (`D58`), citations of the code repo's docs (`RULES.md › Zone mechanics`, `docs/APPS.md`) and commit hashes: those are the code repo's.
- You run after the whole M5 queue (T-206 waits for every card before it, and T-205 runs on its own), since most of them edit the web app. T-207 and T-209 run beside you, with disjoint scopes.
- docs/ is formatted by hand (`.prettierignore`), so leave a table's padding as it is when a cell gets shorter. `pnpm format` realigns `apps/web/README.md`.
- If a test fails after the pass, it read a string you changed. Reword that string by hand so the test passes again, without changing what the test checks.
