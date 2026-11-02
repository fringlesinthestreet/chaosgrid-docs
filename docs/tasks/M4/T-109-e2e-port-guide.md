---
id: T-109
title: Guidance when an e2e port is taken
milestone: M4
depends_on: [T-089]
branch: agent/T-109-e2e-port-guide
model: sonnet
effort: medium
scope:
  - apps/web/package.json
  - apps/web/playwright.config.ts
  - apps/web/vitest.config.ts
  - apps/web/e2e/ports.ts
  - apps/web/e2e/ports.test.ts
  - apps/web/e2e/preflight.ts
  - apps/web/README.md
context:
  - docs/tasks/M4/README.md#Ports and the e2e DB
---

# T-109 — Guidance when an e2e port is taken

## Goal

On 2026-10-29 `pnpm test:e2e` stopped with Playwright's "http://127.0.0.1:5999/api/cards is already used, make sure that nothing is running on the port/url or set reuseExistingServer:true in config.webServer." An e2e API left over from an earlier run held 5999, in its own process group, with no parent left. The message doesn't say what holds the port or how to free it, and its advice doesn't fit: a reused API would keep an earlier run's DB. Playwright checks the webServer URLs before `globalSetup` and never runs a command whose URL already answers, so nothing in `playwright.config.ts` can step in. A holder that doesn't answer the URL fails later, with the server's own error. This task adds a check that runs before `playwright test`: when a port is taken, it says what holds it and how to free it, and Playwright doesn't start.

## Interfaces

What exists (copied from the code on 2026-10-29):

```ts
// apps/web/playwright.config.ts:4–8 (T-068, T-074)
// Ports (docs/tasks/M4/README.md › Ports and the e2e DB): CHAOSGRID_WEB_PORT and
// CHAOSGRID_API_PORT when set, else 4999 and 5999, so a run never meets `pnpm dev`.
const webPort = process.env.CHAOSGRID_WEB_PORT ?? '4999';
const apiPort = process.env.CHAOSGRID_API_PORT ?? '5999';
const baseURL = `http://localhost:${webPort}`;
// :11 testDir: 'e2e', with no testMatch, so Playwright would also run an e2e/*.test.ts.
// :16–30 webServer: 'pnpm --filter @chaosgrid/api start' (url http://127.0.0.1:${apiPort}/api/cards,
//   env CHAOSGRID_API_PORT and CHAOSGRID_DB ':memory:') and 'pnpm run dev' (url baseURL, env both
//   ports), both with reuseExistingServer false. Playwright starts each command in its own process group.
```

```jsonc
// apps/web/package.json:10
"test:e2e": "playwright test"
// The root package.json:21 runs it: "test:e2e": "pnpm --filter @chaosgrid/web run test:e2e". Arguments
// after it reach Playwright (`pnpm test:e2e -- m4`). tsx is in the pnpm catalog, not yet in apps/web's
// devDependencies.
```

```ts
// apps/web/vitest.config.ts: include ['src/**/*.test.{ts,tsx}'], environment './test/jsdom-environment.ts',
//   setupFiles ['test/setup.ts'] (Testing Library's cleanup after each test).
// apps/api/src/main.ts:7: HOST = '127.0.0.1'. apps/web/vite.config.ts: server.port is CHAOSGRID_WEB_PORT,
//   with strictPort and no host, so Vite listens on `localhost`, which can resolve to ::1.
// eslint.config.js:43: apps/web outside src/ is Node code, so e2e/ may import node:net and node:child_process.
```

What this task adds:

```ts
// apps/web/e2e/ports.ts
export interface E2ePorts {
  web: number;
  api: number;
}

/** CHAOSGRID_WEB_PORT and CHAOSGRID_API_PORT when set, else 4999 and 5999; throws on a value that isn't a port. */
export function e2ePorts(env: Record<string, string | undefined>): E2ePorts;

/** Whether something accepts a TCP connection on the port, on 127.0.0.1 or ::1. */
export function isPortTaken(port: number): Promise<boolean>;

/** A row of `ps -A -ww -o pid=,ppid=,pgid=,lstart=,command=`. */
export interface Proc {
  pid: number;
  ppid: number;
  pgid: number;
  /** ps's lstart, as "Thu Oct 29 09:25:28 2026". */
  started: string;
  command: string;
}

export interface TakenPort {
  /** What the port is for: 'the web app' or 'the API'. */
  role: string;
  port: number;
  /** The PIDs lsof lists as listening on it; [] when lsof is missing or lists none. */
  pids: number[];
}

/** The text for one taken port. Pure: `procs` is every process, `free` the ports to offer instead. */
export function portGuide(taken: TakenPort, procs: Proc[], free: E2ePorts | null): string;

/** Checks both ports and prints the guide for each taken one; 0 when both are free, else 1. */
export function checkPorts(ports: E2ePorts, print: (text: string) => void): Promise<number>;
```

```ts
// apps/web/e2e/preflight.ts: the CLI that test:e2e runs
process.exitCode = await checkPorts(e2ePorts(process.env), (text) => console.error(text));
```

## Deliverables

1. **The ports in one place.** `e2e/ports.ts` exports `e2ePorts`, and `playwright.config.ts` takes both ports from it; the comment at :4–5 goes with the defaults. The config gets `testMatch: '**/*.spec.ts'`, so Playwright leaves `e2e/*.test.ts` to Vitest, and `vitest.config.ts` adds `'e2e/**/*.test.ts'` to `include`.
2. **The check before Playwright.** `test:e2e` becomes `tsx e2e/preflight.ts && playwright test`, so arguments still reach Playwright, and `tsx` (`catalog:`) joins the devDependencies. With both ports free, the check prints nothing and Playwright runs as before. With a port taken, it prints the guide to stderr, exits 1, and Playwright doesn't start.
3. **What it says.** For each taken port, `portGuide` names the port and what it's for, lists the processes of each process group that holds it (PID, start time, command), says which case it is, and gives the commands to run. The group's top process is found by following the parents while they're in the same group.
   - **Left over from an earlier e2e run:** the top process has no parent left (PPID 1, or a parent `ps` doesn't list), and a command in the group has `@chaosgrid/api` (the API port) or `vite` (the web port). It gives `kill` with the group's PIDs.
   - **Another e2e run:** the top process's parent runs Playwright (its command has `playwright`). It names that process and says to wait for it to end. No `kill`.
   - **Something else:** it names the top process's parent, if there is one, and gives `kill` with the group's PIDs, to run only if that process isn't needed.
   - **Not known:** `pids` is empty (no lsof, or another user's process). It gives `lsof -nP -iTCP:<port> -sTCP:LISTEN` (on Linux, `ss -ltnp`) to find the holder.

   Every case ends with other ports to use when `free` isn't null: `CHAOSGRID_WEB_PORT=<web> CHAOSGRID_API_PORT=<api> pnpm test:e2e`. `checkPorts` finds them by stepping both ports down together (4998 and 5998, then 4997 and 5997, …), at most 10 times, and offers the first pair where both are free. For the 2026-10-29 case it prints about this:

   ```
   pnpm test:e2e: port 5999 (the API) is already in use.
     99804  Thu Oct 29 09:25:28 2026  node …/pnpm --filter @chaosgrid/api start
     99826  Thu Oct 29 09:25:28 2026  node …/tsx src/main.ts
     99832  Thu Oct 29 09:25:29 2026  node … src/main.ts
   It's left over from an earlier e2e run: nothing that started it is still running.
   Stop it:            kill 99804 99826 99832
   Or use other ports: CHAOSGRID_WEB_PORT=4998 CHAOSGRID_API_PORT=5998 pnpm test:e2e
   ```

4. **Tests** in `e2e/ports.test.ts`. They need no DOM, so the file starts with `// @vitest-environment node`:
   - `e2ePorts`: 4999 and 5999 from `{}`, the env values when they're set, and an `Error` naming the variable for a value that isn't a port.
   - `isPortTaken`: true while a `node:net` server listens on 127.0.0.1 (port 0, so the OS picks one), false once it's closed. The same on ::1, skipped where the machine has no IPv6 loopback.
   - `portGuide`, with `Proc` rows written in the test: each of the four cases, with a `kill` line only where the case gives one, and no other-ports line when `free` is null.
   - `checkPorts`: while the test listens on the API port, it returns 1 and the text names that port (and `process.pid`, when lsof lists it). With both ports free, it returns 0 and prints nothing.
5. **The web README.** Its Playwright paragraph says that `pnpm test:e2e` checks both ports first and what it prints when one is taken, and that `e2e/*.test.ts` are Vitest tests of that check.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test -- ports` passes
- [ ] `pnpm --filter @chaosgrid/web exec playwright test --list` lists no test from `ports.test.ts`
- [ ] With both ports free, `pnpm --filter @chaosgrid/web exec tsx e2e/preflight.ts` prints nothing and exits 0
- [ ] `pnpm test:e2e` passes: smoke, auth, replay and m4
- [ ] `pnpm test:e2e -- m4` runs only `m4.spec.ts`

## Out of scope

- Stopping anything: the check only says what to run.
- Why the 2026-10-29 server outlived its run. If a run that ends normally leaves one behind, that's another card.
- `reuseExistingServer` stays off: a reused API would keep an earlier run's DB.
- `pnpm dev`'s ports (`scripts/dev.sh`, the root README's "When something goes wrong").

## Notes

- Default: probe by connecting, not by binding. A test bind on one address can succeed while a server listens on the other (127.0.0.1, ::1). A refused connection, no ::1 or no answer within 500 ms counts as free on that address.
- Default: `lsof -nP -t -iTCP:<port> -sTCP:LISTEN` gives the PIDs and `ps -A -ww -o pid=,ppid=,pgid=,lstart=,command=` the processes, through `node:child_process` with no shell. A missing command or a non-zero exit (lsof exits 1 when it lists nothing) gives [].
- Default: commands are cut to 100 characters, and there are no colors.
- Without sudo, lsof lists only your own processes, so a port another user holds is the "not known" case.
- The check also runs in CI, since `.github/workflows/ci.yml` runs `pnpm test:e2e`. On a fresh runner both ports are free, so it prints nothing.
- `pnpm exec playwright test` skips the check; `pnpm test:e2e` is the way in.
- tsx comes from the catalog, as for the other CLIs (CLAUDE.md › Conventions).
