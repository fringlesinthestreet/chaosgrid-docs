---
id: T-NNN
title: <short, human-readable; the PR title is "T-NNN <title>">
milestone: M?
depends_on: []
branch: agent/T-NNN-<slug>
model: sonnet
effort: medium
scope:
  - path/to/dir/**
  - path/to/one-file.ts
context:
  - docs/RULES.md#<Section>
  - docs/DECISIONS.md#<Section>
  - packages/<package>/README.md#<Section>
---

# T-NNN — <title>

## Goal

<1–3 sentences: what exists after this PR that didn't before, and why it matters.>

## Interfaces

<The exact names this task uses and provides: functions with their signatures, types, files and
events. Copy them from the code or the docs, so the worker doesn't have to search for them.>

## Deliverables

1. <concrete thing, with the names other tasks will rely on>

## Acceptance

- [ ] `crew check` green
- [ ] <a command anyone can run that proves it works>

## Out of scope

- <tempting work that belongs to another task, and which one>

## Notes

<Defaults for known ambiguities, and hints.>
