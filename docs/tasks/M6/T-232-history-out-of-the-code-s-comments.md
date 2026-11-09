---
id: T-232
title: History out of the code's comments
milestone: M6
depends_on: [T-226, T-229, T-230, T-231]
branch: agent/T-232-history-out-of-the-code-s-comments
model: sonnet
effort: medium
scope:
  - packages/*/src/**
  - packages/*/test/**
  - apps/*/src/**
  - apps/web/e2e/**
  - apps/web/art-pack/**
  - tools/*/src/**
  - tools/*/test/**
context:
  - CLAUDE.md#Conventions
  - docs/DECISIONS.md#Decision log
---

# T-232 — History out of the code's comments

## Goal

The code says what it does now, and its comments carry no history (D79): no "no longer", "used to", "was renamed", dates or playtests, and no citation of a decision number that's retired. After this PR the comments that are left say what the code can't, and a test's title does the job of its comment.

## Interfaces

- The retired numbers and the decisions that hold their rules now are in `docs/DECISIONS.md`, in the line under the table: D7 → D18, D12 and D27 → D40, D25 → D44, D31 → D75, D39 → D45, D48 → D67, D49 and D55 → D63, D58 → D64, D61 → D62, D65 and D76 → D80, D68 → D74.
- The rules for comments: CLAUDE.md › Conventions.

## Deliverables

1. Every citation of a retired number becomes the number that holds its rule, or goes when the comment doesn't need it.
2. Every comment that tells history is rewritten to say what holds now, or removed. Find them with `grep -rniE "no longer|used to|formerly|previously|was renamed|anymore|playtest|2026-|the old |since D[0-9]|before D[0-9]|until D[0-9]"` over the scope; a hit that describes behavior ("a unit that no longer has a target") stays.
3. A comment in a test that only repeats the test's title, or restates the next line, goes.
4. Only comments and test titles change: no code, no test logic, no fixture.

## Acceptance

- [ ] `crew check` green
- [ ] `grep -rnwE "D7|D12|D25|D27|D31|D39|D48|D49|D55|D58|D61|D65|D68|D76" packages apps tools --include='*.ts' --include='*.tsx' --exclude-dir=node_modules` prints nothing
- [ ] The PR lists the hits of deliverable 2's grep that stay, each with a few words on why

## Out of scope

- The docs (`docs/`, the READMEs): the lead keeps them current.

## Notes

- Alone in its wave: every package is in its scope.
