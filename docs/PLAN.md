# ChaosGrid — Milestones

What we build and in what order. The code repo holds what every task follows (D53): the layout and the runtime shape (`docs/ARCHITECTURE.md`), the decisions (`docs/DECISIONS.md`) and the conventions (`docs/CORE.md`, `docs/APPS.md`). Changes to this plan are logged in [CHANGELOG.md](CHANGELOG.md), and the progress is in this repo's [README](../README.md#status).

## Milestones

Each milestone ends with something runnable and a short demo. Items are sized for agent hand-off: one PR each, tests included.

### M0 — Skeleton (1–2 days)

Task cards: [`docs/tasks/M0/`](tasks/M0/). They run in three waves: 1 agent, then 2, then 4 in parallel.

- [ ] pnpm monorepo, TS strict, ESLint import rules, Vitest. (Playwright moves to M4, where the first UI appears.)
- [ ] `packages/protocol` with `Command`, `Event`, `Snapshot` stubs and `PROTOCOL_VERSION`.
- [ ] `packages/cards` with the RULES.md sample cards in JSON + Zod schema + `validate` script in CI.
- [ ] `packages/db`: SQLite + Drizzle, `players` (row `0`) and `cards` tables, `pnpm db:seed` reseeds the cards from JSON (D10–D12).
- [ ] CI: lint, typecheck, test, validate cards, seed smoke test (`.github/workflows/ci.yml`), plus the agent scope guard (`.github/workflows/agent-scope.yml`).
- **Done when:** `pnpm test` is green, `pnpm cards:validate` rejects a malformed card, and a second `pnpm db:seed` in a row changes nothing.

### M1 — Core simulation, headless (1–2 weeks)

Task cards: [`docs/tasks/M1/`](tasks/M1/), 27 tasks in eight waves, with shared conventions in `docs/CORE.md` (in the code repo).

- [ ] State model: players, grids (15×15 then, footprints), units, squads, non-unit permanents, resources, points, round number.
- [ ] Round loop: Reveal → Plan (collect plans) → Simulate (ticks) → Cleanup (scoring, respawn, durability, trap expiry).
- [ ] Tick loop per RULES.md: triggers → abilities → attack/move → damage/death.
- [ ] Movement: grid pathing (A* or flow field) across the shared arena; speed in cells/s → cells/tick.
- [ ] Targeting: nearest enemy permanent; Blocker taunt with range; Flying/Reach rules; Artillery min range.
- [ ] Projectiles: Ranged and Artillery attacks fly as projectiles (kind, speed, position) and deal damage when they land; Trample projectiles splash where they land. Units stop moving once their target is in range.
- [ ] Effect DSL v1: damage, heal, buff/debuff stat for N ticks, push, spawn, reveal, draw, ramp, level, trample splash.
- [ ] Scoring per RULES.md incl. per-unit squad fractions, kept fractional and shown rounded (RULES.md › Shown points).
- [ ] Chaos deck: tiers, per-tier draw counts, spawn-in-front-of rule, rule-changing cards as round modifiers.
- [ ] Seeded RNG; `simulate()` is pure given (state, plans, seed).
- [ ] `tools/sim-cli`: run N games with random plans, print win rates, average round count, points per round; dump event log as JSON.
- [ ] `docs/PROTOCOL.md` written from the real types.
- [ ] Spells: sorceries and permanents' abilities cast utility spells (resolve during Plan), defensive and offensive spells (tick 0, defensive first). Rituals are merged into sorceries (T-033, T-034).
- [ ] More sample cards (utility sorceries, enchantments, Emblem seekers, big squads), so the sims exercise every mechanic.
- [ ] Pulled forward from M4 (then M3): deck rules, the two starter decks, and the `decks` tables (T-030 to T-032).
- **Done when:** 100 headless games between 4 random-plan bots finish without errors, and golden-file tests lock the event stream of two scripted rounds.

### M2 — First bots (3–5 days)
- [ ] `RandomBot` (already used in M1).
- [ ] `GreedyBot`: casts the highest-cost affordable unit, places in front row nearest the point leader, attaches to the highest-Charge unit, levels when unlocked.
- [ ] `TurtleBot`: Blockers + static units + Artillery, attaches to Blockers.
- [ ] Bot vs bot tournament in `sim-cli`; use it to sanity-check the balance knobs.
- **Done when:** the M2 bots are fit to be M4's opponents. Over games at 4 seats (2 and 3 seats too until T-047 made every game 4 players, D22), with starter and generated decks: no game throws, tables of one bot (all greedy, all turtle) have no rejected plan actions, and at most 5% of their games hit the round cap. GreedyBot beats RandomBot in more than 55 of 100 head-to-head games (65 until the prize, D33), which shows that deliberate play pays off in the game. Win rates between bots, game length and points by reason are reported but not gated. These bots are placeholders, and better ones come later.

### M3 — Rules v2 (2–3 weeks)

Task cards: [`docs/tasks/M3/`](tasks/M3/). The rules change before the first UI, so M4 builds on the game's final shape. Most tasks change a shared contract (protocol, card schema, core), so they run one after another. The card-content tasks run alongside them.

- [ ] Names: sorceries become spells (card type `spell`) and the graveyard becomes the discard pile, in rules, card data, protocol and code (D24).
- [ ] Traps are free-standing only: attached traps leave the rules, the card schema and core, and Backdraft and Riptide are removed (RULES.md › Non-unit permanents).
- [ ] Five colors: Earth (`E`), Dark (`D`) and Light (`L`) join Ember and Tide, and Ember's pip becomes `R` (D21). Each new color gets a basic resource.
- [ ] Card colors: usage cost, card color (or Colorless) and the Leader's color allowance, plus effects that check colors and change costs (D23, RULES.md › Card colors).
- [ ] Plan abilities and rested units: permanents with abilities used during Plan, often at the price of resting the unit, and effects that rest enemy units (RULES.md › Units).
- [ ] 100 ticks per second (D18): Simulate runs 10,000 ticks by default, and movement counts in subcells.
- [ ] The battlefield: exactly 4 players, 30 × 30 grids on the four sides of a 50 × 50 Chaos Grid with a 10-cell gap, free space everywhere else. Its measures are config (D20, D22). Chaos units spawn on the Chaos Grid edge facing their player and target the nearest player permanent.
- [ ] The prize: a 2×2 permanent in the middle of every grid that scores for whoever destroys it (D25).
- [ ] The battle timeline: core plays out Simulate once plans lock, and the round's events form a timeline with `tick` events only where something happens, closed by `simulate.ended` (D19).
- [ ] The void zone and five zone mechanics: banish, sacrifice, discard, dump and revive (RULES.md › Zone mechanics).
- [ ] Light's keywords: Shield, Extra life and Ward (RULES.md › Keywords).
- [ ] Fear and copy: fear makes a unit run from its source and stop attacking for a time; copy uses a spell or ability again, with new targets (RULES.md › Simulation rules, › Non-unit permanents and spells).
- [ ] Content: each color reaches at least 30 main-deck cards and colorless at least 20. Thirteen new Leaders (one for each new color, one for each new pair of colors, and one whose Plan ability widens its color allowance), and a dual resource for each new pair. Cards in every color rest, fear, copy and check colors.
- [ ] Unique cards and 100-card main decks (at most 4 copies of a card, 1 of a Unique card, and 30 resources; D26): deck rules, five starter decks (one per color, with Ember aggro and Tide control rebuilt), and 100-card generated decks in `sim-cli`.
- **Done when:** the M2 bots, on the new rules, still meet M2's bars. Over 4-seat games, with starter and generated 100-card decks across all five colors: no game throws, one-bot tables get no rejected plan actions, and at most 5% of their games hit the round cap. Every round's events form a valid timeline. Golden files lock scripted rounds that use every new mechanic, the prize, rest, fear, copy and color checks included. The report gives seconds per game and the tick of the first contact; neither is gated.

### M4 — Decks + playable web UI, solo vs 3 bots (3–4 weeks)

The deck rules, the decks tables and the starter decks were pulled forward into M1 and updated in M3.

Decks:
- [ ] Deck rules as a pure function in `packages/cards`: 100-card main deck (40 until M3) with at most 4 copies of a card and 1 of a Unique card (2 copies until M3), 30 resources, 1 Leader, every card within the Leader's color allowance (D23 since M3). It reports every problem, not just the first. Moved to M1 (T-030).
- [ ] `decks` and `deck_cards` tables, owned by player `0` (D12). A retired card makes a deck illegal but never breaks it. Moved to M1 (T-032).
- [ ] Starter decks as JSON next to the cards, seeded by `db:seed`. Moved to M1 (T-031, T-032); one per color since M3.
- [ ] `apps/api`: local accounts with a session cookie (D40); the card list; create, read, update and delete a player's decks. Saving never refuses an illegal deck: it stores it with its problems. Every body follows `packages/http` (D28). Player `0` is the seeded superadmin `admin`, which holds the starter decks, and sign-ups get ids from 1. Nothing sends mail: a later flow that needs it starts with a mock.
- [ ] Login and sign-up pages in `apps/web`.
- [ ] Deck builder in `apps/web`, pixel-art theme from the start: browse and filter cards, assemble the main deck, resources and Leader, see deck legality as you build, save and load, copy a starter deck.

Match:
- [ ] Solo lobby: the player picks one of their legal decks or a starter deck. The 3 bot seats are always filled, each with a kind and a deck the player can change (the bot registry moves from sim-cli to `packages/bots`). Then `apps/web` runs the match with `GameHost` + `MockTransport`.
- [ ] Battlefield: Pixi scene for the 4 grids around the Chaos Grid, with the free space between them (D22); unit sprites (colored rectangles are fine), HP bars, footprints, prizes, Emblems, rested and feared units. It plays the round's timeline back in real time at 1×/2×/4× (D19): the battle is already simulated when it starts, its settle included (D38).
- [ ] Planning panel (React, in the DOM): hand, resource pool, pick a card then a cell with a footprint preview, attach resources, level-up buttons, set trap face-down, cast spells and use Plan abilities (utility ones resolve at once), copy, move Leader, Ready button + a 60 s timer in the UI. Core checks the plan after every change (`plan.checked`, D29); the UI judges no rule itself. The plan only grows: no Undo and no Clear (D37).
- [ ] Art seam (D39): every art key has a placeholder drawn in code, and the web loads real art from a manifest in cloud storage when `VITE_CHAOSGRID_ART_URL` is set, else the placeholder. The repo never holds the real art.
- [ ] Reveal screen for the Chaos card; scoreboard; round log (from events).
- [ ] Event-driven only: the UI never reads core state (enforced by import rule).
- [ ] Replay viewer: load an event-log JSON from `sim-cli` and watch it. Doubles as the UI test fixture.
- [ ] Playwright for `apps/web` (moved from M0).
- **Done when:** a person can sign up, build and save a legal deck, and play a full game to 30 points with it, offline, against 3 bots in the browser, to test the game, and a Playwright test walks that path from sign-up to the end of a game (T-089).
- [ ] Playtest fixes (the human's first games, 2026-10-29; T-110 to T-118):
  - The clocks and the target are config (D41): Plan has no limit offline, Plan waits for a 10 s Chaos pause, rounds last 180 s, and games go to 100 points (tests to 30).
  - Nobody discards at will: a Discard step at the end of Cleanup trims a hand over the limit (D42).
  - A lone survivor's round goes on while a prize or an Emblem stands (D44).
  - On the match screen: the round clock in seconds, a horizontal tray (hand, resources, discard pile) shown through playback, a card view in front, and anything on the battlefield clickable for its card.
  - One battlefield to plan on (D43).

### M5 — Balance pass (ongoing, 1–2 weeks first pass)
- The human's priorities after playing M4 (2026-10-29): gameplay, the UI, card balancing and the bots. Online play, deploys, email and other platforms wait.
- [ ] Tune the M3 card pool from `sim-cli` reports: numbers first, then retire cards that never make a deck. Expand Chaos to 30 cards.
- Where to start: T-062's report (PR #79, starter decks, the M2 bots). Games end in about 3.5 rounds at 30 points, against the 12 to 15 that RULES aims for, so the Chaos tiers after round 5 are almost never seen. Prizes are about 5% of points, and first contact comes at about tick 300 to 350, so the round timer never binds. Vask Pyre Marshal won 8 of 12 seats in a 20-game sample: rerun it bigger before acting on it.
- [ ] Card versioning: bump `version` in every changed card file; `packages/cards/CHANGELOG.md` per release.
- [ ] Balance report from `sim-cli` committed per release (win rate per Leader, average game length, Chaos kill share). T-131 adds JSON, the median and spread of game length, intervals on the Leader win rates, per-card numbers, and what players leave unspent; T-139 commits the first baseline at 100 points, with the planner bot, and proposes the tuning cards.
- [ ] Discard-pile decks (D48, T-132): a card at Durability 0 retires at every Cleanup, and the first cheap Durability 0 units and revive payoffs.
- [ ] Bots (D49): they aim for prizes and Emblems and pick targets by value (T-130), use traps, Leader moves and Rest (T-133), and look ahead through round previews within a budget (T-129, the planner T-135). Each starter deck gets a bot style (T-137), and the lobby offers Easy, Normal and Hard bots and game-length presets (T-138).
- [ ] Language files (D50, T-124): the web's text goes through `t()` and ICU messages in `apps/web/src/i18n/en/`. English only for now; adding a language means adding files.
- [ ] Deck building and cards: deck problems with fixes and quick add (T-125), deck list tiles (T-126), the card browser's sorting, groups, views and filter chips (T-127), bot-game stats on card pages (T-134).
- [ ] The match: a playback timeline with event markers (T-128), a squad's attached cards in the card view (T-140), and the battlefield behind the whole screen, with the panels over it (D51, T-136).
- [ ] Carded once the code they build on has merged: a standings strip; planning aids (unaffordable cards dimmed, footprint and range while placing, the cost previewed); a rules drawer with a keyword glossary; one card face in three sizes; seat identity (an icon or pattern per seat, colorblind-safe); combat readability (shield segments, changed stats against the printed ones, merged damage numbers); settings (reduced motion, text size, high contrast, default speed); after the baseline, the Chaos and starter-deck items above; moving each area's remaining text into the language files; and a lint rule against hard-coded UI text.
- [ ] Starter decks: retune the five from M3, and add two-color ones.
- [ ] Art (D45 to D47 and D52, `docs/ART.md`; T-119 to T-123): animated sprites at 16 px a cell, attacks that wind up from playback's look-ahead, projectile and effect sprites, spell casts, and the art pack that checks the files, stitches Fable's one-PNG-per-frame export into strips and writes their manifest. The first real sprites go to cloud storage; the repo keeps only the placeholders. Skins are variants under a card's art key (D52), with no code before players can pick them.
- **Done when:** no Leader wins > 35% in a 4-bot tournament and median game is 12–16 rounds.

### M6 — Multiplayer (later)
- [ ] `apps/server`: Node, one `core` per room, `WsTransport` with the same interface as `MockTransport`. The server plays out each round and sends every seat its own filtered timeline (D19).
- [ ] Multiplayer lobby: rooms and seats, bots filling empty seats (M4 has the solo lobby), reconnect via Snapshot.
- [ ] Hidden information enforced server-side (plans, hands, face-down traps).
- [ ] Accounts move to the server with the DB: M4's local accounts (D40) become server accounts, and the server enforces the Plan and Discard deadlines and the Chaos pause (D41).
- [ ] The DB moves to Postgres for the server (D11).
- **Done when:** two browsers and two bots finish a game with the server authoritative.

### M7 — Desktop (later)
- [ ] Tauri wrapper of `apps/web`, auto-update, offline solo play.

