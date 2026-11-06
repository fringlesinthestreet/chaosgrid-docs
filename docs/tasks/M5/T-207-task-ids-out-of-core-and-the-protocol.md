---
id: T-207
title: Task ids out of core and the protocol
milestone: M5
depends_on: [T-205, T-206]
branch: agent/T-207-task-ids-out-of-core-and-the-protocol
model: sonnet
effort: medium
scope:
  - packages/core/**
  - packages/protocol/**
  - docs/CORE.md
  - docs/PROTOCOL.md
context: []
---

# T-207 — Task ids out of core and the protocol

## Goal

The code repo is shared, and nothing in it refers to the plan (D73). Core, the protocol and their docs still do, in about 210 lines on 2026-11-06's main: task ids (`(T-016)`, `// T-058. All units are…`), milestones (`the M1 default`, `(M4)`) and `PLAN.md › M<n>`. After this PR none are left, and each comment, test title and doc line says what the code does and why on its own.

## Interfaces

```sh
# What's left (also the acceptance check): every reference in the scope
git grep -n -I -E '(^|[^A-Za-z0-9_])(T-[0-9]{3}|M[0-9])([^0-9A-Za-z]|$)|PLAN\.md|later tasks?|task card' -- packages/core packages/protocol docs/CORE.md docs/PROTOCOL.md

# The mechanical pass: drops task ids from parentheses. " (T-016)" goes with its leading space;
# "(T-158, D58)" and "(D58, T-158)" become "(D58)"; "(the real ones, T-016)" becomes "(the real ones)".
# A tag right after //, * or # stays for the hand edits: the sentence around it needs rewording.
git grep -l -z -I -E 'T-[0-9]{3}' -- packages/core packages/protocol docs/CORE.md docs/PROTOCOL.md \
  | xargs -0 perl -pi -e 's/(?<![\/*#])\((?:T-\d{3}, )+/(/g; s/, T-\d{3}(?=[,)])//g; s/(?<![\/*#]) \(T-\d{3}\)//g'
```

On a copy of 2026-11-06's main, the pass left about 75 lines in 30 files for the hand edits. Examples from this scope:

| Before | After |
| --- | --- |
| `// T-058. All units are one-unit squads; …` | `// All units are one-unit squads; …` |
| ``console.log(`T-129 perf, 120 units, capped at tick ${cap}: …`)`` | ``console.log(`round perf, 120 units, capped at tick ${cap}: …`)`` |
| `it('follows the M1 default: seat 0 stays, …')` | `it('follows the default: seat 0 stays, …')` |
| `This page is the guide for the M1 tasks that build on T-008.` | `This page is the guide for code that builds on core.` |
| `packages/core/README.md`'s folder table, with its `Task` column | the table without the column |

## Deliverables

1. **The pass**, then the hand edits, until the check prints nothing. Read only the lines it prints and a few around them, not whole files.
2. **The hand edits** follow D73 and CLAUDE.md › Conventions › Comments, test titles and docs:
   - Say what the code does now. A pointer to other work ("T-050 adds them", "until a later task") becomes a plain statement of the current behavior, or goes if the code already says it.
   - A plan citation that carries a rule ("a retired card must still load (PLAN.md › M3)") keeps the rule and drops the citation. Cite `docs/RULES.md › <section>` or a decision instead when one states it.
   - A comment left with nothing to say goes.
   - Test titles and log labels change the same way.
3. **Nothing else changes:** no code, no identifiers, no behavior.

## Acceptance

- [ ] `crew check` green
- [ ] `crew check soak` green
- [ ] the first command in Interfaces prints nothing
- [ ] `git diff --stat main...HEAD` lists only files in the scope

## Out of scope

- `docs/DECISIONS.md`: a decision is never rewritten (DECISIONS.md › How decisions change), so its rows keep their ids.
- `CLAUDE.md`: the lead's.
- The web app (T-208), and the other packages, sim-cli and the root files (T-209).
- Any other cleanup you notice: report it in the PR.

## Notes

- Keep decision ids (`D58`), citations of the code repo's docs (`RULES.md › Zone mechanics`, `docs/CORE.md`) and commit hashes: those are the code repo's.
- You run after the whole M5 queue (T-206 waits for every card before it, and T-205 runs on its own), since each of them edits core or the protocol. T-208 and T-209 run beside you, with disjoint scopes.
- docs/ is formatted by hand (`.prettierignore`), so leave a table's padding as it is when a cell gets shorter. `pnpm format` realigns the package READMEs.
- If a test fails after the pass, it read a string you changed. Reword that string by hand so the test passes again, without changing what the test checks.
