---
id: T-209
title: Task ids out of the other packages
milestone: M5
depends_on: [T-205, T-206]
branch: agent/T-209-task-ids-out-of-the-other-packages
model: sonnet
effort: medium
scope:
  - packages/bots/**
  - packages/cards/**
  - packages/db/**
  - packages/http/**
  - apps/api/**
  - tools/**
  - docs/ARCHITECTURE.md
  - docs/RULES.md
  - docs/balance/**
  - eslint.config.js
  - pnpm-workspace.yaml
context: []
---

# T-209 — Task ids out of the other packages

## Goal

The code repo is shared, and nothing in it refers to the plan (D73). The bots, the cards, the DB, the HTTP and API code, sim-cli, three docs and two root files still do, in about 95 lines on 2026-11-06's main: task ids (`(T-017, T-024)`, `for T-001`), milestones (`for the API (M4)`, `M1's done-when`), `PLAN.md › M<n>`, "your task card", and two soak tests named after milestones. After this PR none are left, and each comment, test title and doc line says what the code does and why on its own.

## Interfaces

```sh
# What's left (also the acceptance check): every reference in the scope
git grep -n -I -E '(^|[^A-Za-z0-9_])(T-[0-9]{3}|M[0-9])([^0-9A-Za-z]|$)|PLAN\.md|later tasks?|task card' -- packages/bots packages/cards packages/db packages/http apps/api tools docs/ARCHITECTURE.md docs/RULES.md docs/balance eslint.config.js pnpm-workspace.yaml

# The mechanical pass: drops task ids from parentheses. " (T-148)" goes with its leading space;
# "(T-017, T-024)" goes whole; "(T-158, D58)" and "(D58, T-158)" become "(D58)".
# A tag right after //, * or # stays for the hand edits: the sentence around it needs rewording.
git grep -l -z -I -E 'T-[0-9]{3}' -- packages/bots packages/cards packages/db packages/http apps/api tools docs/ARCHITECTURE.md docs/RULES.md docs/balance eslint.config.js pnpm-workspace.yaml \
  | xargs -0 perl -pi -e 's/(?<![\/*#])\((?:T-\d{3}, )+/(/g; s/, T-\d{3}(?=[,)])//g; s/(?<![\/*#]) \(T-\d{3}\)//g'

# A fact dated by a task ("against T-062's 3.5 rounds") can name the task's commit instead
git log -1 --format='%h %as' -E --grep '^T-062 |\(T-062\)' main
```

On a copy of 2026-11-06's main, the pass left about 75 lines for the hand edits, a third of them in `packages/cards/README.md` and `packages/cards/src/dsl.test.ts`. Examples from this scope:

| Before | After |
| --- | --- |
| `// retired card must still load (PLAN.md › M3).` | `// retired card must still load.` |
| `// Accounts and sessions (D40), for the API (M4).` | `// Accounts and sessions (D40), for the API.` |
| `// Not in the DECISIONS.md table yet; set by the lead for T-001.` | `// Not in the DECISIONS.md table yet; set by the lead.` |
| `# M4 (T-068): the web app, its tests and the API server` | `# The web app, its tests and the API server` |
| `// Nor do When played and the discard pile targets (T-050 adds them).` | what the test checks now; if they exist by now, the comment is wrong: reword it for what's true |
| `changing it needs the lead's OK, unless your task card is about it` | `changing it needs the lead's OK, unless your change is about it` |

## Deliverables

1. **The pass**, then the hand edits, until the check prints nothing. Read only the lines it prints and a few around them, not whole files.
2. **The hand edits** follow D73 and CLAUDE.md › Conventions › Comments, test titles and docs:
   - Say what the code does now. A pointer to other work ("T-050 adds them", "a later task") becomes a plain statement of the current behavior, or goes if the code already says it.
   - A plan citation that carries a rule keeps the rule and drops the citation. Cite `docs/RULES.md › <section>` or a decision instead when one states it.
   - A comment left with nothing to say goes.
   - Test titles and log labels change the same way.
3. **The soak tests named after milestones** take the names of what they check (`git mv`):
   - `tools/sim-cli/test/done-when.soak.test.ts` becomes `random-games.soak.test.ts`, and its `describe('M1 done when')` becomes `describe('RandomBots')`.
   - `tools/sim-cli/test/m3-done-when.soak.test.ts` becomes `bot-skill.soak.test.ts`, and its `describe('M3 done when')` becomes `describe('the bots against each other')`.
   - `tools/sim-cli/README.md`'s list of tests follows.
4. **Nothing else changes:** no code, no identifiers, no behavior.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check soak` green, with the renamed soaks in its output
- [ ] the first command in Interfaces prints nothing
- [ ] `git diff --stat main...HEAD` lists only files in the scope

## Out of scope

- `docs/DECISIONS.md`: a decision is never rewritten (DECISIONS.md › How decisions change), so its rows keep their ids.
- `CLAUDE.md`: the lead's.
- Core and the protocol (T-207), and the web app (T-208).
- Any other cleanup you notice: report it in the PR.

## Notes

- Keep decision ids (`D33`), citations of the code repo's docs (`RULES.md › Zone mechanics`) and commit hashes: those are the code repo's.
- You run after the whole M5 queue (T-206 waits for every card before it, and T-205 runs on its own), since most of them edit these packages, and T-206 writes the next report in `docs/balance`. T-207 and T-208 run beside you, with disjoint scopes.
- `eslint.config.js` and `pnpm-workspace.yaml` are root files (planning rule 4): change only their comments, as above.
- docs/ is formatted by hand (`.prettierignore`), so leave a table's padding as it is when a cell gets shorter. `pnpm format` realigns the package READMEs.
- If a test fails after the pass, it read a string you changed. Reword that string by hand so the test passes again, without changing what the test checks.
