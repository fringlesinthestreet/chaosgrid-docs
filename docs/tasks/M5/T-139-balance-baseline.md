---
id: T-139
title: Balance baseline
milestone: M5
depends_on: [T-132, T-137]
branch: agent/T-139-balance-baseline
model: sonnet
effort: medium
scope:
  - docs/balance/**
  - packages/cards/stats/**
context:
  - docs/PLAN.md#M5
  - docs/RULES.md#Balance knobs
  - tools/sim-cli/README.md
---

# T-139 — Balance baseline

## Goal

M5 is done when no Leader wins more than 35% of a 4-bot tournament and the median game runs 12 to 16 rounds (PLAN.md › M5). This task measures where the game stands, with the final M5 bots and at the real point target, and tunes nothing. After this PR, `docs/balance/` holds:

- two merged sim-cli JSON reports, one with starter decks and one with generated decks;
- a write-up that answers the Done when, the open balance knobs and the card outliers.

`packages/cards/stats/cards.json` holds the per-card counts the card pages show (T-134). Each finding goes to lead as a `request` that proposes a tuning card.

## Interfaces

What exists when this task starts (planned in T-110, T-131, T-132, T-134, T-135 and T-137; re-read the sim-cli README and those cards for the exact flags and names):

```sh
# T-110: the point target is 100 by default; --target N changes it. Rounds last 180 s. --rounds N caps
#   a game (default 100).
# T-131: --json FILE writes a version 1 report of counts; --merge A.json,B.json,… adds reports of one
#   setup up, prints the text report and, with --json, writes the merged report. Game i of --seed S plays
#   seed S + i, so parts with contiguous seeds merge into exactly one long run. The text report prints
#   the median, p10 and p90 rounds, each Leader's win rate with its seats and a 95% Wilson interval,
#   round ends per reason, first contact, unspent resources, opening hands, and the card lists.
# T-134: --card-stats FILE writes the card pages' stats, after a run or a --merge.
# T-135: the planner bot (default name: planner). T-137: a bot style for each starter deck.
# The run prints its time: use it to time the pilot.
pnpm sim --bots planner,planner,planner,planner --decks starter --seed 1 --games 49 --json .data/baseline-starter-0.json
```

## Deliverables

1. **Sizing.** A Leader's win rate p from n seat-games has a 95% half-width of about 1.96 √(p (1 − p) / n). At p up to 0.35, ±5% needs n ≈ 350.
   - Starter decks: each seat picks one of 5, so a Leader gets about 4N/5 seat-games in N games: N ≥ 438, and step 3 plays 441.
   - Generated decks: each picks one of 18 Leaders, so 4N/18: N ≥ 1,575, and step 3 plays 1,584.
2. **A pilot.** Play 8 games with each deck source, `--seed 900001`, with the lineup below, and take the seconds per game from the run time. Estimate each run's wall time: N × seconds per game ÷ parts ÷ 3,600. Expect 20 to 60 s a game, so about 1.3 to 3.8 hours for both runs in 9 parts. Parts running side by side are slower than the pilot alone, so allow for it.
   - If both runs together would take more than 4 hours, send lead a `question` with the estimate, and start the starter run meanwhile.
   - Without an answer, play the generated run with as many games as fit in 4 hours, and give the interval width that leaves.
3. **The runs.** Split each run into parts with contiguous seeds, one process per part, as many parts as the machine has cores minus one (`sysctl -n hw.ncpu`). With 9 parts:
   - starter: 9 × 49 games (441), seeds 1, 50, 99, …;
   - generated: 9 × 176 games (1,584), seeds 1, 177, 353, ….

   Each part writes `--json .data/baseline-<source>-<k>.json`. Run them in the background and wait for them to exit. Rerun any part that died without writing its file, with the same seeds.
4. **The merges.**
   - Starter: `pnpm sim --merge <the 9 parts> --json docs/balance/<date>-starter.json`.
   - Generated: the same, into `docs/balance/<date>-generated.json`, plus `--card-stats packages/cards/stats/cards.json`.
5. **The write-up**, `docs/balance/<date>-baseline.md`, with these sections:
   - **Runs:** the commit, the commands, the bots and styles, N, the seeds, the run times, the machine (cores), and the errors and capped games of both runs.
   - **Done when:** every Leader's win rate with its seats and interval, in both runs, and the median, p10 and p90 rounds. Say whether each half of the Done when holds. A Leader whose interval contains 35% is "not settled".
   - **Balance knobs:** one paragraph each, with the numbers behind it, comparing with T-062's report where PLAN.md gives a number:
     - the point target: the median against 12 to 16, and the target that would move it to 14 (100 × 14 ÷ median, a first-order guess);
     - the round timer: first contact (median and p90) against 180 s, and the share of rounds that end at `timeUp`;
     - the battlefield: what first contact says about the distance;
     - the prize: its share of all points;
     - resources per round: resources left unspent per Plan, and opening hands with nothing castable;
     - Durability 0: T-132's seven cards and the older revive cards, from the generated run. The starter decks hold no Durability 0 card.
   - **Cards:** the generated run's card lists, and what stands out.
   - **Requests:** one line per request sent.
6. **The requests.** One `request` to lead per finding, in WORKER.md › 5's heredoc form. Each one gives the numbers and proposes one tuning card: a title of at most 40 characters, what it changes, and the run that would check it. Send one when:
   - the median is outside 12 to 16 rounds;
   - a Leader's interval lies wholly above 35%, or wholly below 15%;
   - more than 20% of rounds end at `timeUp`, or the median first contact is before second 3 or after second 20;
   - prizes give more than 15% or less than 2% of all points;
   - more than 1 resource a Plan goes unspent on average, or more than 10% of opening hands have nothing castable;
   - a card played in at least 30 seat-games wins above 45% or below 10% of them when played. Group these by color, one request a color;
   - a card drawn in at least 30 seat-games is played in fewer than 20% of them. Group these too: it may be a bot gap rather than a card problem, so say which you think it is.

   Send at most 12, the ones that matter most for the Done when first, and list the rest in the write-up.

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/cards test` passes: the new `cards.json` parses
- [ ] `pnpm sim --merge docs/balance/<date>-starter.json` and `pnpm sim --merge docs/balance/<date>-generated.json` print their reports. Exit 1 only if a game threw, and then the write-up lists the errors
- [ ] `git diff --name-only main...HEAD` lists only files in `docs/balance/` and `packages/cards/stats/cards.json`
- [ ] `grep -c "^## " docs/balance/<date>-baseline.md` prints 5 or more
- [ ] `redis-cli XRANGE cg:inbox:lead - +` shows one `request` from T-139 per line of the write-up's Requests section

## Out of scope

- Any tuning: card files, starter decks, `GameConfig`, RULES.md and PLAN.md. Tuning cards come from the requests.
- Code: if sim-cli can't do what this card needs, send lead a `request` and wait.
- A web page for the reports.

## Notes

- **Default lineup.** The planner at all four seats, at its default budget. With starter decks each bot plays its deck's style (T-137). Generated decks have no style, so the bot uses its default. "A 4-bot tournament" means four bot seats, not `--tournament`, which plays matchups between different bots.
- **Defaults for the rest of the setup.** The point target stays at 100 and `--rounds` at 100. If more than 1% of games hit the cap, say so under Done when: a capped game counts at the cap in the median.
- **Ties** count as wins for every tied seat, as the report counts them, so the win rates of a game can add up to more than 100%.
- **The card stats come from the generated run**, which holds every card. The starter decks hold only their own cards.
- **The date** is the day of the runs, typed out as `YYYY-MM-DD`. Don't use `$(date)`: it stops for a permission prompt.
- **Formatting.** Prettier skips `docs/`, so the reports go in as sim-cli writes them. It checks `packages/cards/stats/cards.json`, which sim-cli already writes in Prettier's format.
- **Waiting.** Start each part with the Bash tool's `run_in_background`. Wait for the parts to exit with the Monitor tool or the completion notices, not by polling or with a foreground sleep.
- The merged reports hold counts only, so a later run with the same setup can be merged into them.
