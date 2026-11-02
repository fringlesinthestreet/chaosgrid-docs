# ChaosGrid notes for crew workers

`crew context` prints these after your card. They fill in what crew's worker playbook (`~/Documents/AI/skills/crew/WORKER.md`) leaves to the project. The rules for anyone working on the code are in the code repo's CLAUDE.md: where it says to ask the lead, send `crew send lead --from T-NNN --question …`.

- **Install:** in a fresh worktree, run `pnpm install --reporter=silent` before anything else: each worktree has its own node_modules. Run it again after a rebase that changed dependencies.
- **Commits:** Conventional Commits with `git commit -q`. The scope is the package folder, and every commit ends with a `Task: T-NNN` trailer, which status tracking reads (D16):

  ```
  feat(cards): add cost parser

  Why, if it isn't obvious.

  Task: T-003
  ```

  The types are `feat`, `fix`, `test`, `refactor`, `docs`, `chore`, `build` and `ci`.
- **Tests while you work:** one package at a time, `pnpm --filter @chaosgrid/<pkg> test 2>&1 | tail -n 30`. Before handoff, `crew check` runs lint, format, typecheck and test.
- **Soaks before handoff:** when your scope touches `packages/core/src/**`, `packages/bots/src/**`, `packages/cards/data/**` or `tools/sim-cli/**`, also run `crew check soak`. It takes a few minutes: give the shell command a timeout of 600000 ms, or run it in the background.
- **Lockfile conflicts** in a rebase: `git checkout --ours pnpm-lock.yaml && pnpm install && git add pnpm-lock.yaml`. During a rebase, "ours" is the base, and `pnpm install` adds your dependencies back.
- **Isolation:** your worktree has its own DB at `.data/chaosgrid.db`. A server you start uses port `4000 + N` for the web and `5000 + N` for the API, where N is your task number: `CHAOSGRID_WEB_PORT=4061 CHAOSGRID_API_PORT=5061` for T-061.
- **Docs:** a path under `docs/` in your card or in a code comment is in this plan repo (the milestones, the cards) or in the code repo (the rules, the protocol, the decisions, the architecture, the conventions, the art). `crew doc "<path>#<heading>"` reads either.
