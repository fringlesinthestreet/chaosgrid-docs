---
id: T-206
title: Balance baseline after the 11-05 rules
milestone: M5
depends_on: [T-201, T-202]
branch: agent/T-206-balance-baseline-after-the-11-05-rules
model: sonnet
effort: medium
scope:
  - docs/balance/**
  - packages/cards/stats/**
context:
  - docs/PLAN.md#M5
  - docs/RULES.md#Balance knobs and open questions
  - docs/RULES.md#Chaos deck and Emblems
  - tools/sim-cli/README.md
  - docs/balance/2026-11-02-baseline.md
  - docs/tasks/M5/T-139-balance-baseline.md
---

# T-206 — Balance baseline after the 11-05 rules

## Goal

The 11-05 playtest changed the game under the 2026-11-02 baseline (T-139): one Chaos card a round, spawned Chaos-factor times (D65), no Durability (D67), no Charge, its cards printing Plan abilities instead (D74), Unique and colorless cards (D66, D69, D70), and the removal cards (T-201). Since T-183, games end in about half the rounds they did, and the human chose to measure before tuning the factor. This task measures where the game stands after wave 42 with T-139's method, and tunes nothing. After this PR, `docs/balance/` holds the two merged reports and a write-up for the new date, and `packages/cards/stats/cards.json` holds fresh per-card counts, the new cards included.

## Interfaces

T-139's card is the method: its Interfaces, its sizing, pilot, runs and merges (Deliverables 1 to 4), its requests (Deliverables 6) and its Notes apply as written, unless this card says otherwise. `crew context T-206` prints it. The 11-02 write-up, `docs/balance/2026-11-02-baseline.md`, is what this one compares with.

```sh
pnpm sim --bots planner,planner,planner,planner --decks starter --seed 1 --games 49 --json .data/baseline-starter-0.json
pnpm sim --merge <the parts> --json docs/balance/<date>-generated.json --card-stats packages/cards/stats/cards.json
```

## Deliverables

1. **The runs and the merges,** as T-139 › Deliverables 1 to 4, at main after T-202, with the bots, styles and point target main has then. Redo the sizing with the Leader and starter deck counts main has then: T-198 adds Brass Arbiter, a colorless Leader.
2. **The write-up**, `docs/balance/<date>-baseline.md`, with T-139's sections: Runs, Done when, Balance knobs, Cards, Requests. Put every figure the 11-02 write-up also gives beside its 11-02 value. In Balance knobs, these replace the Durability 0 paragraph:
   - **The Chaos factor (D65):** the median, p10 and p90 rounds against 11-02's, Chaos kill points as a share of all points against 11-02's, and which tier most games end in. Say whether the factor or the point target is the knob to move toward M5's 12 to 16 rounds, with the numbers behind it.
   - **No Charge (D74):** the plays and the win rate when played of the 13 cards that printed Charge, whose "If charged" abilities became Plan abilities (T-212).
   - **Removal (T-201):** the plays and the win rate when played of each removal and wipe card.
   - **Uniques and colorless (D66, D69, D70):** what stands out in the card lists.
3. **The requests,** as T-139 › Deliverables 6: at most 12, one per finding, each proposing one tuning card.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/cards test` passes: the new `cards.json` parses
- [ ] `pnpm sim --merge docs/balance/<date>-starter.json` and `pnpm sim --merge docs/balance/<date>-generated.json` print their reports. Exit 1 only if a game threw, and then the write-up lists the errors
- [ ] `git diff --name-only main...HEAD` lists only files in `docs/balance/` and `packages/cards/stats/cards.json`
- [ ] `grep -c "^## " docs/balance/<date>-baseline.md` prints 5 or more
- [ ] The lead inbox holds one `request` from T-206 per line of the write-up's Requests section

## Out of scope

- Any tuning: card files, starter decks, `GameConfig`, the Chaos factor, RULES.md and PLAN.md. Tuning cards come from the requests, once the human has played this batch too.
- Code: when sim-cli's report doesn't give a figure above, say so in the write-up and send the lead a `request` for it, without waiting for an answer.
- The 11-02 files: keep them, so the two baselines can be compared.

## Notes

- **Alone in its wave.** The runs take every core but one for hours, so nothing runs beside them: timing tests would fail under that load.
- **Why now.** T-183's worker saw games end in about half the rounds. A default game on seed 1 took 21 rounds at 34a96b8 and 24 on T-189's branch: one seed only, so read nothing into it. The human chose this measurement over tuning the factor first (2026-11-06).
- `pointsByReason`'s `chaos` is signed: read it as the 11-02 write-up does (its Runs › Report check fix).
