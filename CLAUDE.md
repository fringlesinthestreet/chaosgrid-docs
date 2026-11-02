# ChaosGrid plan: for the lead

This repo is ChaosGrid's plan: the milestones (docs/PLAN.md), the cards and the board (docs/tasks/), and the changelog. The code repo is shared with other people, and keeps the rules, the protocol, the decisions, the architecture, the conventions and the art (D53); `crew doc` lists both repos' docs. `crew lead` gives the lead agent this file; workers never read it. The lead and the workers run in the code repo.

- Change anything here only on a lead branch: `crew plan new <slug>`, edit and commit in its worktree, `crew plan check`, then `crew plan ready <slug>`. The human pushes, reviews and merges.
- The code repo's docs change on a lead branch there: `crew plan new <slug> --code`, limited to the globs in `.crew/lead-paths`. Keep them for everyone who works on the code: no crew commands, no cards, no plan.
- A new card: `crew card new "<title>" --milestone M<n>` inside a lead worktree. The card format and the general planning rules are crew's (`~/Documents/AI/skills/crew/TASKS.md`); ChaosGrid's own are in docs/tasks/README.md › Planning rules.
- A running task needs a wider scope: `crew card widen T-NNN <glob>`. It prepares the lead branch and tells the worker to wait; after the human merges it, `crew merged` asks the worker to re-read its card.
- A decision changes: on a `--code` lead branch, mark the old one `Superseded by Dn` and add the new row (DECISIONS.md › How decisions change). On a lead branch here, add a CHANGELOG entry and fix every card that relied on it. Merge the decision first, so no card points to one that isn't on main yet.
- Paths under `docs/` in cards and in the code's comments mean this repo's file when it has one, else the code repo's.
