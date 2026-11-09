---
id: T-233
title: Balance baseline after balance v2
milestone: M6
depends_on: [T-232]
branch: agent/T-233-balance-baseline-after-balance-v2
model: sonnet
effort: medium
scope:
  - docs/balance/**
  - packages/cards/stats/**
context:
  - docs/PLAN.md#M6
  - docs/RULES.md#Balance knobs and open questions
  - docs/RULES.md#Chaos deck and Emblems
  - tools/sim-cli/README.md
  - docs/balance/2026-11-08-baseline.md
  - docs/tasks/M5/T-139-balance-baseline.md
---

# T-233 — Balance baseline after balance v2

## Goal

M6 changed the game under the 2026-11-08 baseline: three Chaos cards a round with one squad per target (D80), no traps (D81), one resource a round (D60), cheap units (T-225) and mana artifacts (D83). This task measures where the game stands with T-139's method, and tunes nothing. After this PR, `docs/balance/` holds the two merged reports and a write-up for the new date, and `packages/cards/stats/cards.json` holds fresh per-card counts.

## Deliverables

1. **The runs and the merges,** as T-139 › Deliverables 1 to 4, at `main` after T-232, with the bots, styles and point target `main` has then. Redo the sizing with the Leader and starter deck counts `main` has then.
2. **The write-up**, `docs/balance/<date>-baseline.md`, with T-139's sections: Runs, Done when, Balance knobs, Cards, Requests. Put every figure the 11-08 write-up also gives beside its 11-08 value. In Balance knobs:
   - **The Chaos (D80):** the median, p10 and p90 rounds, Chaos kill points as a share of all points, Emblem points as a share, how often Extra Chaos came, and which tier most games end in.
   - **The economy (D60, T-225, D83):** the mean mana spent a round by round 1, 3, 5 and 10; the plays and win rate when played of the eleven new units, the ten re-costed ones and the six mana artifacts.
   - Which knob to move toward 12 to 16 rounds: the point target, the Emblem points or the Chaos points.
3. **The requests,** as T-139 › Deliverables 6: at most 12, one per finding, each proposing one tuning card.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/cards test` passes: the new `cards.json` parses
- [ ] `pnpm sim --merge docs/balance/<date>-starter.json` and `pnpm sim --merge docs/balance/<date>-generated.json` print their reports. Exit 1 only if a game threw, and then the write-up lists the errors
- [ ] `git diff --name-only main...HEAD` lists only files in `docs/balance/` and `packages/cards/stats/cards.json`
- [ ] `grep -c "^## " docs/balance/<date>-baseline.md` prints 5 or more
- [ ] The lead inbox holds one `request` from T-233 per line of the write-up's Requests section

## Out of scope

- Any tuning: card files, starter decks, `GameConfig`, RULES.md and PLAN.md.
- Code: when sim-cli's report doesn't give a figure above, say so in the write-up and send the lead a `request` for it, without waiting for an answer.
- The earlier baselines: keep them, so the three can be compared.

## Notes

- **Alone in its wave.** The runs take every core but one for hours, so nothing runs beside them: timing tests would fail under that load.
- `pointsByReason`'s `chaos` is signed: read it as the 11-02 write-up does (its Runs › Report check fix).
