# Changelog

Changes to the plan, the decisions and the way we work, newest first. The code's own history is in git. Merged tasks show up in the Status section of this repo's README and in `crew status`.

When you change [PLAN.md](PLAN.md), the code repo's `docs/DECISIONS.md`, [WORKFLOW.md](WORKFLOW.md) or the agent workflow, add an entry here on a lead branch of this repo (D36, D53). Say what changed and why, and name the decisions and tasks it touches.

## 2026-11-04 — Playtest fixes, public pools and floating mana (D57 to D59, T-153 to T-163)

The human played the game and asked for eleven changes. Two are rules. Resources in play are public and lie behind each grid, outside it (D57): every seat sees every pool, and during Plan the other seats show as they were when Plan opened, before its draws. Costs are paid with floating mana, so a player chooses which resources pay for each card, and auto-pay covers what's left (D58). The card backs the human drew become `ui.cardBack`'s `back` role (D59). The decisions, RULES.md, ART.md and the README change on the code repo's `lead/pools-and-mana`, which merges first.

- **Bugs:** the planning grid covered the HUD's tray, a stacking context (T-153). `pnpm dev` served no art, so permanents stayed blocks of color, and PlanGrid shrank the art box by 6 px (T-156).
- **Core and protocol:** floating mana and `restForMana`, version 28 (T-155), then public pools and their events, version 29 (T-157).
- **Web:** rest for mana in the tray (T-158), the pools in the match model and the round log (T-163), the pools and piles behind each grid (T-161), rested and charged cues (T-162), card backs (T-160), card list views and the deck editor's side panel (T-159), and a confirmation before leaving a match (T-154).
- **T-152 changes:** its small face is a fixed 112×154 px, and it exports `CostPips`, which T-158 and T-159 use.
- **Lead defaults the human hasn't confirmed:** auto-pay stays as a fallback; one `resource.rested` event with a reason, not two event types; a target kind for resources waits for the first card that needs one; "charge abilities" means Charge, not every usable ability; the card browser keeps its Table view; a click in the editor's pool still adds a copy.

## 2026-11-04 — One card face in three sizes (T-152)

The human wants cards drawn as cards everywhere in the web (the hand, the card view, the resources, the discard piles, the deck editor and the card browser), in the style of a Magic: The Gathering face: a frame in the card's color, the cost at the top right, the art, a type line, the text, the numbers at the bottom right and the Durability at the left, with each card type showing only what it has. PLAN.md › M5 listed "one card face in three sizes" among the items to card once the code they build on had merged; T-152 cards it as one component, `CardFace`, that replaces `CardDetail` and the inside of `CardTile`, so every page that draws a card gets the face through them.

## 2026-11-03 — Bots plan in a Web Worker (D56, T-150, T-151)

Planning runs on the page's thread, and three Hard bots hold up a round's start by about 1 s on average and up to 1.8 s. T-135's default of 250 ms a decision and a 0.75 s freeze a round was never met. The human chose a Web Worker over accepting the freeze, and asked whether the bots need a queue: they don't, because each bot has its own RNG and reads only its seat's snapshot, and a worker takes its messages one at a time (D56, T-150).

T-151 doubles sim-cli's test limits, the human's call as with T-143.

The human will play the game before T-139's nine requests get tuning cards, so none are written yet. Squad abilities keep the rule T-120 chose: each unit with an `ability` animation plays it, the others flash, and the squad flashes once if none played.

## 2026-11-02 — The code repo names neither crew nor this repo (D54)

People who work on the shared code repo without crew would wonder what its mentions of the plan repo, crew and lead branches mean. And a session the human started by hand didn't know it was the lead: it made a branch in the main checkout instead of a lead branch.

- D14–D17, D36 and D53 moved to the new [WORKFLOW.md](WORKFLOW.md), with their numbers. The code repo's DECISIONS.md keeps a `Withdrawn` row for each, and its CLAUDE.md no longer mentions the plan repo. A new decision takes the next number that's free on both pages.
- crew's session hook (`crew setup` writes it to the code repo's untracked `.claude/settings.local.json`) tells every session started in the code repo that it's the lead and gives it this repo's CLAUDE.md. It also says how changes reach main: the docs and the cards go on lead branches, and anything else gets a task card first.
- The Agent scope workflow and its deploy key are gone from the code repo. `crew pr` runs the same scope check against this repo's main before it pushes.
- Workers' PR bodies no longer name the card or `crew check`.

## 2026-11-02 — The web's Node-run files may import the cards package's Node entry (T-123)

T-123 widened ESLint's web zone for the files outside `apps/web/src/` (config files, `e2e/`, `art-pack/`), which Node runs, so they may import `@chaosgrid/cards/node`. Its card planned that as a stated exception to planning rule 4. The code repo's import tables now say the same: DECISIONS.md › Import boundaries, rules 1 and 6, and CLAUDE.md › Architecture rules. No decision changed.

The merged art pack also took Fable's whole export without a problem: 285 keys, 1,058 strips stitched from frames, 264 portraits and 39 icons, and the same output on a second run.

## 2026-11-02 — Follow-ups from the M5 handoffs (T-143 to T-147)

The lead went through the open notes in the handoffs of T-119 and T-124 to T-140, and the human picked what to do with them. Five became cards, and the rest stay as the merged code has them.

- **Test limits (T-143, wave 22).** Core's round perf test and the web's `host.test.ts` get twice the time, not cheaper bot planning: the capped preview took about 0.85 s of its 1 s.
- **Bots (T-144, wave 22; T-145, wave 23).** The random bot reuses PlanDraft's Leader move and Rest use, with the same plans. Greedy and turtle attach resources without a Rest ability first, so a Rest isn't lost to an attach. Then each `SpawnedSquadSnapshot` carries `pointsPerKill` (protocol v27), and the bots rank Chaos squads and opponents' tokens by kill points next to the grid squads, instead of counting them 0 (T-130).
- **Web (T-146, wave 22; T-147, wave 23).** The replay keeps the match's stored speed under one key, since the playback controls already overrode its own. The cost sort keeps ties A to Z when descending, like the other sorts, and "More filters" can close with a filter set.
- **Waves.** T-135 waits for T-143 to T-145 and moves to wave 24, so T-137 is 25, and T-138 and T-139 are 26. T-120 waits for T-146. T-135's Interfaces tell its worker to re-read the files these cards change.
- **Kept as merged.** T-128's markers: one per sustained attack on a prize or an Emblem. T-127's sort: ties ascending. T-131's nine stats defaults, confirmed. T-132 accepts `at` on Pale Summoner, so that default needs no fallback.
- **Other changes.** Planning rule 11: no two paths that differ only in case (T-125's `quickAdd.ts`, the `Art/` ignore line the human anchored as `/Art/`). In the code repo, ART.md says the art bucket must send `Access-Control-Allow-Origin`, since T-119 loads images with `crossOrigin` set.

## 2026-11-02 — The plan moves to chaosgrid-docs, the code repo is shared, and the agents run on crew (D53)

The code repo is going to be shared with other people, so it keeps the code and the docs anyone working on it needs, and the plan moved to this private repo. The lead and worker tooling moved to the shared `crew` command (`~/Documents/AI`). How waves, cards, lead branches and reviews work doesn't change.

- Here: the milestones (docs/PLAN.md), the task cards and the board (docs/tasks/), this changelog, the README's status block, the workers' notes (docs/agents/CREW.md) and crew's settings (`.crew/`). `scripts/dev.sh` and `docker-compose.yml` came too: running ChaosGrid with Redis and the DB viewer.
- In the code repo: docs/RULES.md, PROTOCOL.md, DECISIONS.md and ART.md, plus three that came out of the plan. ARCHITECTURE.md has PLAN.md's layout, runtime shape and card JSON sketch; CORE.md is the M1 README's conventions; APPS.md is the M4 README's, without "What M4 adds", which stays in docs/tasks/M4/README.md. Card context entries and code comments use the new names. CLAUDE.md is for anyone working on the code, and `pnpm dev` runs only the game.
- Lead branches here: `crew plan new <slug>`, `crew card new`, and `crew card widen T-NNN <glob>` for a wider scope. For the code repo's docs: `crew plan new <slug> --code`, limited to `.crew/lead-paths`. A decision change is two PRs: the decision in the code repo, merged first, then this changelog and the cards here.
- `scripts/*.sh` are gone: each is a crew command (`crew help`). Workers no longer type `redis-cli`: `crew claim`, `crew read`, `crew wait`, `crew send lead --from T-NNN`, `crew scope` and `crew handoff`. `crew context` and `crew doc` read the docs from either repo. crew's permission rules live in each clone's untracked `.claude/settings.local.json`, which `crew setup` writes, so the code repo's `.claude/settings.json` keeps only the deny rules and the project's own commands.
- The Agent scope check in the code repo reads the cards and the lead paths from this repo's main, with a read-only deploy key.
- `crew merged` commits the status block here, so the code repo's history holds only merged PRs. Fixed on the way: after a lead branch merged, the old status block counted no merged tasks until the next task merged.
- The cards' "`scripts/check.sh` green" acceptance lines say `crew check` now.

## 2026-10-31 — Fable's sprites: stitched frames in the art pack, and skins (D52)

Fable's full sprite export sits in the human's gitignored `Art/` folder: every key ART.md lists, at the sizes and with the `art.json` D45 and D46 ask for, but each animation as one PNG per frame (`idle1.png`, `idle2.png`, …) instead of a strip, which the art pack would reject. Its seven extra folders are T-132's new cards, which merge before the pack. The human chose to have the pack accept that form, and to decide skins now so the art cards don't fix a layout skins would break.

- **Art pack (T-123, wave 21).** An animation is a `<animation>.png` strip or numbered frames of one size. The pack decodes frames with `pngjs` (a devDependency of apps/web at an exact version, like T-124's `intl-messageformat`), stitches them left to right into an 8-bit RGBA strip and lists that strip in the manifest, so the game still loads strips only and T-119's art module doesn't change. A gap in the numbering, a frame of another size, an animation in both forms, a frame that doesn't decode or an `art.json` `frames` that isn't the count is a problem. Strips, portraits and icons are still copied byte for byte, so frames are the only files decoded. ART.md › Art pack says the same.
- **Skins (D52).** A card's art stays keyed by its id, with no card field and no DB column. The art under `<in>/<key>/` is the default skin; a variant goes in `<in>/<key>/skins/<skin>/` with the same files and rules, and a version 3 manifest lists it under the key's `skins`, each role falling back to the default's. None of this is code in M5: the pack rejects a `skins` folder until then, and who owns or picks a skin is decided when players can.
- **Other changes.** PLAN.md › M5's art item names D52 and the stitching. The `Art/` folder is in `.gitignore`, committed by the human.

## 2026-10-30 — The M4 follow-ups and a squad's attached cards in the card view (T-140 to T-142)

After the playtest cards (T-110 to T-118) merged, the lead collected the questions their handoffs left open, and the human answered them. Two M4 cards take the fixes, and an M5 card takes the human's request to see the equipment and auras on a squad.

- **Tests (T-141, wave 16).** The host's human-seat game gets its own timeout. The protocol's plan test gets a row for v25's `discard`. Core's combat perf test allows 20 s instead of 10 s, and its header names the 18,000-tick worst case.
- **The match screen (T-142, wave 20).** The first Escape closes the card view and the second cancels the selection. The Zones panel drops the player's own discard pile, since the tray lists it. The Discard step starts with the cards D42's rule would discard already ticked, so a player who does nothing sees what goes, and the clock discards what's ticked when it runs out.
- **Attached cards (T-140, wave 21).** A click on a unit opens a list in the card view: the unit's card first and shown, then every card attached to its squad, each one a click away. The card is in M5 because its text goes through T-124's `t()` (D50). T-136 moves to wave 22, T-120 to 23, T-121 to 24 and T-122 to 25.
- **Confirmed.**
  - The discard pile keeps core's order for now.
  - A target on the viewer's own grid uses the own-grid layer, as T-118's default says.
  - D42's automatic rule stays, and T-142's ticks show it.
  - The four defaults of the M4 and M5 card fixes stand. T-120 doesn't snap the framed zoom to a whole multiple of 16 px, which the 2026-10-29 entry below said it would. The Discard clock reads "No limit" above D41's limit. ART.md lists the cases where T-121 cuts a wind-up. The lead updates the import tables in CLAUDE.md and DECISIONS.md when T-123 merges.
- **Other changes.**
  - The board's planning rule 10: write test filters without `--`, since Vitest runs every file after it. The cards' filters follow it.
  - T-135 also waits for T-141, since both edit `host/host.test.ts`.
  - T-136's Interfaces are refreshed from main after T-118. Its notes keep `Overlays` outside the keyed `PlanProvider`, which remounts its children every round, and put the tray and the planning panel in the HUD through portals.
  - PROTOCOL.md says a snapshot's `hand` is oldest first, and that the automatic Discard rule takes its last `discardCount` cards.
  - M4/README.md's folder tree names the new owners, and PLAN.md › M5 names T-140.
- **Lead defaults:**
  - T-140 heads the list "This squad's cards", keeps the shown card in local state, leaves out a dead attached card and lists only for a unit;
  - T-142 ticks the hand's last `discardCount` cards. At 0 the clock sends the ticked cards when exactly that many are ticked, and `ready` otherwise or when core refuses its choice.

## 2026-10-29 — The M5 cards: language files, deck building, the backdrop, bots that look ahead, balance tools (D48–D51, T-124 to T-139)

After playing M4, the human set M5's priorities: gameplay, the UI, card balancing and the bots. Online play, deploys, email and other platforms wait. The lead compared how card sites show cards and decks and how other games lay out a battlefield, and proposed changes. The human dropped deck stats (curve, colors, types), import and export, a maybe zone, sample hands and a sandbox. They chose a battlefield that stays behind the whole match screen, with the options over it, and agreed to the rest.

- **Discard-pile decks (D48, T-132).** A unit card at Durability 0 goes to the discard pile at Cleanup even when its squad survived, so a card printed with 0 stays one round and is cheap for it. Durability still drops when the whole squad dies, and leveling up still resets it. This answers RULES.md › Balance knobs' open question. T-132 adds the rule to Cleanup and the first such units and revive payoffs.
- **Bots that look ahead (D49, T-129, T-135).** Core's `previewRound` plays a round from a bot's own snapshot, where other seats play nothing because their plans are hidden. Whoever runs the bot passes it in as a `Simulator`, so `packages/bots` still imports only `protocol`. The budget counts previews per decision and ticks per preview, never wall-clock time, so sim-cli runs stay reproducible and the game isn't slowed. T-129 builds the previews with no protocol bump, and T-135 the planner bot. Before it, T-130 makes bots aim for prizes and Emblems and pick targets by value, and T-133 makes them use traps, Leader moves and Rest. After it, T-137 gives each starter deck a bot style.
- **Language files (D50, T-124).** The web's text becomes ICU messages in `apps/web/src/i18n/en/`, one file per folder, read through a typed `t()`. English is the only language; another one adds a folder. Every web card from T-124 on puts its text in the files. The cards planned before it (T-110 to T-123) keep theirs in code, and later cards move each area over. Core, protocol and the API send codes, never sentences, and card names and text stay in the card files.
- **The battlefield behind the match (D51, T-136).** The canvas fills the match screen in every phase. The top bar, the tray, the card view, the playback bar and the overlays float over its edges and fold, and T-117's camera frames the grid into the part they leave free.
- **Deck building and cards.** T-125 adds a validation chip that lists a deck's problems with their fixes, and quick add ("3 Cinder Grunt"). T-126 shows each deck as a tile with its Leader and key cards. T-127 adds sorting, groups, views and filter chips to the card browser, and T-134 bot-game stats to each card's page.
- **Playback (T-128).** A timeline with markers for kills, prizes, Emblems and Chaos, which seeks within the round. One playback speed is remembered for the match and the replay.
- **Balance tools (T-131, T-139).** T-131's report adds JSON, the median and spread of game length, intervals on the Leader win rates, per-card numbers and what players leave unspent. T-139 commits the first baseline to `docs/balance/`, at 100 points with the planner bot, and proposes the tuning cards. It changes no code.
- **The lobby (T-138).** Easy, Normal and Hard bots (random, greedy and the planner), and game lengths of 50, 100 and 150 points beside a custom target.
- **Later.** PLAN.md › M5 lists what gets carded once the code it builds on has merged: a standings strip, planning aids, a rules drawer with a keyword glossary, one card face in three sizes, seat identity, combat readability, settings, the Chaos and starter-deck work after the baseline, moving each area's remaining text into the language files, and a lint rule against hard-coded UI text.
- **Other changes.**
  - T-119 now waits for T-124. T-120 waits for T-136, which edits the battlefield and `MatchScreen.tsx` first, and snaps the framed zoom down to a whole multiple of 16 px when sprites draw (D46).
  - T-113's scope gains the replay tests that read "tick" from the playback label.
  - T-121 also cuts a wind-up on a seek and when a rewatch ends.
  - ART.md's stills gain a 96 px Leader for the deck tile, and its 32 px row names the tile's key cards.
  - RULES.md states D48 in Cleanup, the stats table, Respawn and the balance knobs. M4/README.md's folder tree names the new owners, and its Placeholders line lets `Overlays` take optional props. CLAUDE.md's index says D1–D51.
  - The board's M5 section places the new cards in waves 14 to 21, beside the playtest cards.
- **Lead defaults:**
  - `intl-messageformat` 10.7.16, pinned in the web's `package.json`; a missing message id has no fallback, since the tests keep every locale's ids equal to `en`'s;
  - a deck tile fetches its deck, one request per deck, and its key cards are the three non-resource cards with the most copies;
  - bot stats show on the cards page only;
  - the planner starts from 6 previews of 3,000 ticks per decision and cuts them until a decision takes at most 250 ms. The host plans bots synchronously, so three planners block the page for about 0.75 s once a round, until a Web Worker comes;
  - the lobby's default opponents are Normal, Normal and Easy, with no Hard seat, and turtle leaves the lobby;
  - only a starter deck's own id has a bot style;
  - Pale Summoner revives at second 5, or on death if core refuses `at` on a unit.

## 2026-10-29 — Animated art, sizes per cell and the M5 art cards (D45–D47, T-119 to T-123)

The human asked which sprites the game needs for each kind of card and each event, then for a simple animation format, sizes that scale with the grid, and attacks with a start and a finish, Ranged ones included. The art cards are the only M5 cards planned: the balance cards stay on hold until the human has tested M4.

- **The art format (D45, superseding D39).** Art keys gain `projectile.<kind>` and `fx.<name>`. A key has up to three roles: a `sprite` of named animations, each a horizontal PNG strip of equal frames, a 32×32 portrait and an 8×8 icon. The manifest goes to version 2. An event shows the thing's own animation, else the event's `fx` sprite, else today's code effect, so every key stays playable while its art is missing. The repo still holds only placeholders.
- **Sizes (D46).** Art is drawn at 16 px per grid cell and at whole multiples only, so a bigger grid or a new footprint needs no new art. A unit's idle frame stays 16×16, its cell, and the status icons grow from 6 to 8 px.
- **Attack timing (D47).** Core's attacks stay instant. Playback tells the battlefield which steps come in the next 50 ticks, and the battlefield starts the attack strip early, so its hit frame shows on the step of `unit.attacked`. A start event in core would change every replay and the balance, so it waits until gameplay needs an attack that can be interrupted (protocol v27).
- **[ART.md](ART.md) is new.** It fixes the keys, the roles, the sizes, the animations and the events each one plays on, spell casts, playback, the fallbacks, the manifest and the art pack, and says which card builds what.
- **The cards (T-119 to T-123).** T-119 builds the art module and the version 2 manifest, T-120 animates units and permanents, T-121 adds the wind-ups and projectile sprites, T-122 the `fx` sprites and the spell casts, and T-123 the art pack: it checks a folder of PNGs, writes the bucket's files and their manifest, and serves them on this machine. Nothing uploads yet. The board gets an M5 section, waves 20 to 23, with a stated exception to planning rule 4 for T-123's one line of `eslint.config.js`.
- **Docs.** DECISIONS.md's import rule 6 names the art pack as Node code. M4/README.md's folder tree names the art cards' owners, and its Art note points at D45 to D47. PLAN.md's M5 art item cites them, and its playtest list says T-110 to T-118, not T-119. CLAUDE.md's index lists ART.md.
- **Lead defaults:**
  - a Plan ability shows nothing on the battlefield, and a copied spell plays the copier's cast on the original's target;
  - a utility cast on the viewer's own grid stays under the planning layer;
  - the art pack serves on 127.0.0.1 only.

## 2026-10-29 — Playtest fixes: clocks, the Discard step, prizes, one battlefield (D41–D44, T-110 to T-118)

The human played M4 by hand and asked for rules and screen changes. Their answers to the lead's questions settled the rest. M5 stays on hold.

- **Clocks and numbers (D41, T-110, T-113).**
  - The Plan clock, the Chaos pause and the Discard clock become game config that core carries and never counts. The defaults are 120 s, 10 s and 30 s; the solo host sets Plan and Discard to 9999 s, which reads "No limit".
  - Plan waits for the Chaos pause, while the round banner shows; closing the banner ends the pause.
  - The round timer goes from 100 s to 180 s, and the round clock shows seconds left, not the tick.
  - The point target goes from 30 to 100 for players. Tests and soaks play to 30, and the lobby's range goes up to 200.
- **The Discard step (D42, T-112, T-114, T-116).** Nobody discards at will: the `discard` plan action goes. When Cleanup leaves a hand over 8, its player chooses the cards to discard before the next round. A player who doesn't choose in time loses the most recently drawn cards, as Cleanup did before. The human's direction for discard-pile decks, cheap low-Durability units that retire there and come back with revives, is a new open question in RULES.md › Balance knobs: Durability 0 works like 1 today.
- **Prizes and Emblems keep a lone survivor's round going (D44, superseding D25, T-110).** The round used to end the moment one player was alone on the battlefield. Now it goes on while another player's prize or an Emblem stands, so the winner of the fight can score it. Skip covers long rounds.
- **One battlefield (D43, T-111, T-115, T-117, T-118).**
  - The planning grid lies on the battlefield, over the player's grid, and the separate grid goes.
  - The hand, the resource pool and the discard pile move to a horizontal tray that stays through playback.
  - A larger card view opens in front of the screen, for a card in the tray or anything clicked on the battlefield, of any owner, Chaos included.
- **Docs.** RULES.md says all of this. M4/README.md's folder tree names the new owners, and its "Plan timer" note becomes "The clocks". PLAN.md lists the fixes under M4, and M6's server enforces all three clocks.
- **Lead defaults:**
  - the Discard step keeps the phase `cleanup`, with `discardCount` per seat, so no `Phase` changes;
  - a clock with more than an hour left reads "No limit";
  - the Discard clock is 30 s online;
  - the round clock shows 0 through the settle after the timer runs out;
  - the planning layer is PlanGrid's DOM buttons laid over the canvas, rather than hit-testing on the canvas, so its keyboard support, labels and tests stay.

The human's `pnpm test:e2e` stopped with Playwright's "http://127.0.0.1:5999/api/cards is already used": an e2e API left over from an earlier run still held the port, and the message names neither what holds it nor how to free it. Playwright checks the webServer URLs before `globalSetup` and doesn't start a command whose URL answers, so the guidance can't live in the config.

- The new T-109 (wave 13, sonnet, medium effort) runs a check before `playwright test`. When 4999 or 5999 (or `CHAOSGRID_WEB_PORT`, `CHAOSGRID_API_PORT`) is taken, it lists what holds the port, says whether that's left over from an earlier e2e run or another run in progress, prints the command that stops it and free ports to use instead, and doesn't start Playwright. Nothing is stopped for you.
- T-109 is a later owner of `apps/web`'s `package.json`, `vitest.config.ts`, `playwright.config.ts` and `README.md`, and adds `tsx` from the catalog to the web app's dev dependencies. The exception paragraph in the tasks README now also lists `playwright.config.ts`'s earlier owner, T-074.

## 2026-10-29 — The round summary in live play (T-108) and the T-086, T-087, T-088 and T-100 defaults

The latest handoffs' notes.

- The round summary (T-088) never shows in a live game (T-089's handoff). Playback applies `round.ended` of round N and `round.started` of round N + 1 in one go, so the card asks `roundSummary` for a round that hasn't ended; its unit test stopped at `round.ended`. The new T-108 (wave 13, sonnet, medium effort) shows the latest round that ended until the next timeline plays, moves the card from the bottom left, where it would cover the Ready bar during Plan, to the top left, moves the overlays' fade into `theme.css`, and puts T-089's summary check back into `m4.spec.ts`. T-108 is a later owner of `match/overlays/`, `theme/theme.css` and `e2e/m4.spec.ts`.
- Lead accepted these defaults. T-086: an action whose card name isn't known shows the card's instance id, `PlanProvider` and `PlanGrid`'s `disabled` go beyond the card's interface, and the panel keeps its "Planning" heading before the first snapshot. T-087: Discard starts with nothing ticked, `describeAction` takes the view, `squadsFor` names only grid squads (spawned squads have no footprint), the planning fixture is built by hand, and Level up is tested with the stub session, since no starter Leader is affordable in round 1. T-088: the banner is a region, not a status, so it doesn't clash with "Round over"; the `emblem.broken` fixture is built by hand; "Leaders died" also lists a seat whose Leader squad retired, once per seat. T-100: `canPick` is gone, and `describeTarget` and `describeAction` take the plan as an optional parameter.

## 2026-10-29 — A guide to running ChaosGrid locally (T-107)

The human asked whether a card covered a README or tools for running the project locally. None did: `pnpm dev` and `scripts/dev.sh` already run the API and the web app, but no doc says how to set a machine up, and `pnpm dev` stops when Docker isn't running without naming the way to play without it.

- The new T-107 (wave 9, sonnet, medium effort) adds a "Run it locally" section to the root README: what to install, the first run, each part on its own, the settings, the DB and the usual problems. When Docker isn't running, `pnpm dev` will name `pnpm dev api web`, which runs the game without Redis and the DB viewer. `dev.sh` and [scripts/README.md](../scripts/README.md) stop saying the apps "arrive in M4".
- T-089's web README links to that section instead of repeating it, so T-089 now waits for T-107.

## 2026-10-29 — No manual acceptance steps, and the deck editor's guard (T-106)

The human's answers to the latest handoffs' questions.

- Workers run headless, so nobody could tick a manual browser step: T-084 and T-085 skipped theirs. They're dropped from T-087, T-088, T-100 and T-104, and planning rule 6 ([tasks/README.md](tasks/README.md)) now says each criterion is a command. Component tests (T-087 and T-100 with a real session) and the Playwright specs cover the browser instead: T-089's `m4.spec.ts` plays a whole game through the round banners, the round summary, game over and Play again.
- The new T-106 (wave 9, sonnet, medium effort) replaces T-077's default, where only `beforeunload` asked: leaving the deck editor with unsaved changes, by a link or Back, now asks first, in the page (`useBlocker`). Saving, the filters and Copy never ask. T-106 is a later owner of `decks/editor/`, and T-089 now waits for it.

## 2026-10-28 — Host test timeouts (T-105) and the T-077, T-083 and T-085 defaults

The latest handoffs' notes.

- In the full test run, `src/host/host.test.ts`'s whole-game test goes over Vitest's 5 s default (about 3.9 s alone), so `scripts/check.sh` fails for every web task (T-085's handoff). The new T-105 (wave 9, sonnet, low effort) gives the file's slow tests their own timeouts by T-103's rule, at least 5 times their time alone. T-105 is a later owner of `host/host.test.ts`, and T-089 now waits for it.
- [M4/README.md](tasks/M4/README.md) › The match now says what the planning and overlay tasks build on (T-085): `useSession()` needs a `SessionContext` provider, which `MatchScreen` provides itself; `stubSession` records every `submitPlan` and `ready`, even while `planning` is false, when the real session drops them; an error freezes the screen under its message; and a reload of `/match` shows "No match running."
- Lead accepted these defaults. T-083 plays a loaded log at once, and Play after the step buttons restarts the round from its start, since seeking within a timeline is out of scope; `locateStep` is approximate only at tick 0, where it reads as the Plan step. T-077 keeps the filter in the URL query, and adding a Leader replaces the one in the deck.

## 2026-10-28 — merged.sh cleans up after the lead

Merged lead branches piled up, each with its worktree. `merged.sh` leaves a worktree that a session is still running in, and when the human runs it, the lead session is usually still in its last lead worktree. All that run left was a warning with commands to run by hand.

- When a session is still in the worktree, `merged.sh` now records the branch and its tip in `cg:leftover` ([COMMS.md](agents/COMMS.md)). Every later run removes the worktrees and branches listed there once no session is in them. A branch with commits since its merge stays, with a warning: those commits aren't on `main`.
- `plan.sh list` shows such a branch as `merged` until then.

## 2026-10-28 — merged.sh installs the dependencies

After T-069 added `packages/http`, the main checkout failed lint, typecheck and test there: its `node_modules` came from before the new package, because `merged.sh` only pulled. CI installs from scratch, so only the local gates broke.

- `merged.sh` runs `pnpm install --frozen-lockfile` once `main` has the merge, after a pull or a `--local` merge. When nothing changed, pnpm only checks. A failed install shows pnpm's last lines and a warning, and the rest of `merged.sh` still runs.

## 2026-10-28 — The Emblem on its cell, the Chaos banner and jsdom (T-104)

The human's answers to three questions from the latest handoffs.

- An Emblem stands on one cell, but the battlefield drew it 32×32, over 2×2 cells. The new T-104 (wave 9, after T-085) draws it 16×16 on its cell, like a unit, and `artSize('ui.emblem')` becomes 16. The T-082 card still says 32×32; [M4/README.md](tasks/M4/README.md) › Art now says 16×16.
- The battlefield's "Chaos: <name>" banner showed one name, so a second reveal replaced the first. T-104 makes it list every card revealed while it shows, and adds `chaosBanner` to `<Battlefield>` and `createBattlefield` (default true). The match screen passes false, since T-088's round banner names the round's Chaos cards there; the replay keeps the banner.
- T-104 is a later owner of `art/`, `match/battlefield/` and `match/MatchScreen.tsx`, and T-089 now waits for it, so the M4 e2e runs on the finished match screen.
- jsdom stays on 29. A task asks lead to upgrade it only when a test can't pass without a newer one ([M4/README.md](tasks/M4/README.md) › Dependencies).

## 2026-10-28 — CI timeouts (T-103)

CI is red, and an agent session can't read its logs. The likely cause is time limits. GitHub's runner for a private repo has 2 CPUs, so Vitest runs one worker there (nine on the lead's laptop), and a thread there is up to twice as slow. Tests that take a few seconds on the laptop go over Vitest's 5-second default or their own 30, and the soaks, 9.5 minutes there one after another, go over the soak job's 20 minutes.

- The new T-103 (wave 1) gives the slow tests in core and sim-cli timeouts of at least 5 times their time on the laptop (3 times for the soaks), and the soak job 45 minutes instead of 20. Nothing a test checks changes.
- D31's revisit trigger ("The soak job takes more than 15 minutes, or a perf test fails when it runs alone") is likely met on CI. T-103 answers it without a new decision. Combat perf's 'nobody dies' budget goes from 5 to 10 seconds (it takes 3 on the laptop), a stated exception to D31's "with their budgets unchanged". The soak job gets more time instead of shards, path filters or a nightly soak. Merging T-103's card is the human's OK for both; if they want them written down, the lead adds a decision.
- T-068 now waits for T-103, since both change ci.yml, and its card says the soak job's limit is 45 minutes.

## 2026-10-28 — The human's answers for M4

The human answered the questions from the M4 refresh. Four answers became decisions (D37 to D40), two new cards start M4 (T-101 and T-102), and the rest confirm what the cards already say. M4 is done when a person can sign up, build a deck and play a whole game against 3 bots in the browser, offline, to test the game.

- Confirmed as the cards have it: the planning preview is the snapshot core sends back (`plan.checked`, D29); during Plan a seat sees each other seat's whole snapshot as it was when Plan began (D34); events during Plan stay public; T-094's card tests check one way; the planning grid is drawn in the DOM, not in Pixi; accounts arrive in M4; the lobby always fills the 3 bot seats.
- D37: during Plan a seat's plan only grows, with no Undo and no Clear, because `plan.checked` shows the cards a utility spell draws. RULES.md › Plan says so. T-078 adds `extendsPlan` to protocol, the host ignores a `plan.submit` that doesn't extend the seat's last one (T-080), and the planning cards only add actions.
- D38: when Simulate meets an end condition, the round settles before it ends. Nothing new starts; projectiles in flight land, and On death, On kill, Emblem and trap triggers fire with whatever they set off. RULES.md › Simulate gets a Settling paragraph. The new T-101 (wave 1, after T-097) builds it and adds `simulate.ending`.
- D39: the repo holds only placeholder art, drawn in code; real art lives in cloud storage behind a manifest, loaded and cached by the browser. M4 builds the seam with placeholders, and M5 gets the first real sprites (PLAN.md › M5).
- D40 supersedes D27: player `0` is the seeded superadmin `admin`, which holds every deck player `0` owns, the starters included, and sign-ups get ids from 1. Its password comes from `CHAOSGRID_ADMIN_PASSWORD` when the API starts, so it's never committed. Nothing sends mail; a later flow that needs it starts with a mock. T-070, T-071, T-072 and T-073 carry it, and CLAUDE.md says it.
- The new T-102 (wave 1) puts a cost's total and a card's off colors in `packages/cards`, so the card browser and the deck editor (T-075 and T-077, which now need it) sort and mark cards without a rule of their own (D29). Core and db read the same helper.
- T-090 also adds `permanent.healed`: a prize that survives a round hurt heals at Cleanup, and the match model would otherwise copy that rule. Its scope adds `round/cleanup.ts`.
- The protocol bumps go one card at a time: T-101 makes it v22, T-078 v23 and T-090 v24 (the entry below said 22 and 23). T-078 moves to wave 2, T-090 to wave 3 and T-081 to wave 4.
- Every M4 card was checked against the UI's pattern, and the cards now say it where they touch it:
  - The web reaches core only through protocol messages from `src/host/`, and only `match/session.ts` uses the host's runtime.
  - It reaches the API only through `packages/http` and `src/api/`; the art manifest is the one other `fetch`.
  - It draws art only through `CardArt` and `spriteFor`.
  - It judges no rule itself: plan legality is `plan.checked`, deck legality is `checkDeck` (the API answers with the same call), costs and colors come from `packages/cards`, and a prize's heal arrives as `permanent.healed`.
  - Its tests stub the API with `stubApi`, so a stub can't drift from `@chaosgrid/http`.
- DECISIONS.md › Import boundaries, rule 5: `apps/api` also imports `protocol` and `http`, as the table already said.
- Sessions the human starts by hand compact at 400k tokens (`.claude/settings.json`), so a planning chat can hold a milestone's cards. The lead and the workers keep 150k (D17), through the flags their scripts pass.

## 2026-10-28 — M4 cards refreshed for M3

The M4 cards were drafted on 2026-10-22, before M3 merged. M3 changed the arena, the decks, the targets and the events, so the cards were updated against `main` (protocol v21), and three questions got answers from the human.

- Every M4 card that copies code ("What exists") now matches `main` as of today: the 130×130 arena with 30×30 grids and the Chaos Grid, 100-card decks, `MAX_COPIES`, five starters, seven target kinds, `copyTarget`, and the M3 events.
- T-090 also adds `prize.placed`, once per seat after `game.started`, so the event stream alone can draw a prize (protocol v23). Its scope adds `round/game.ts`. T-078 stays at v22.
- T-082 draws through a camera that pans and zooms in whole-pixel steps, so the 130×130 arena fits any window and the pixel art stays sharp. It now needs T-075 for card data. T-082 moves to wave 5 and T-083 to wave 6.
- T-081, T-082 and T-088 cover M3 in the match model, the battlefield and the round log: fear, Shield, Extra life, sacrifice, revive, banish, tokens, Durability, piles, and the eight `ScoreReason`s.
- T-087 keeps the five board target kinds. The new T-100 (wave 11, after T-087) adds the revive and copy pickers, every seat's discard pile and void, and the round's rules bar. T-089 now needs T-100.
- PROTOCOL.md › `PrizeSnapshot`: a destroyed prize stands again at Cleanup with `permanent.respawned`.

## 2026-10-28 — M3 wrap-up

M3 is merged. These are the last loose ends from its handoffs.

- PLAN.md › M5: T-062's balance findings, the starting point for the balance pass. They existed only in the PR, because a squash merge keeps the title, not the body.
- PROTOCOL.md: a Chaos unit that dies never comes back, and `chaos.despawned` lists only what still stood (T-065's question 3). The others left with `unit.died` or `emblem.broken`.
- The cards and db READMEs show 100-card decks, 256 cards and five starter decks (T-061).
- Kept as built: a banished squad's attached cards get `permanent.retired`, and a sacrificed token gets only `squad.sacrificed` (T-065). `firesOnDeath` ignores On death conditions, so at worst it holds a round one tick (T-097). The Ward is tested in core, not in the golden (T-062). The soak takes about 4 minutes, which the 20-minute CI job allows (T-062).

## 2026-10-27 — Commits that only look like task merges

The lead commit that widened T-061's scope (93bf793) had a `Task: T-061` trailer, so status tracking counted T-061 as merged hours before its PR was. `scripts/status.sh` showed it as merged, `scripts/lead.sh` started T-062 and T-066 on top of it, and the lead, which went by the board, saw them blocked on a task the human believed was done.

- D16: a commit listed in the new `scripts/not-task-merges` never counts as a task merge. 93bf793 is the first entry. A lead commit can't look like a task merge any more (D36), so the list is only for mistakes that reach `main` anyway.
- `scripts/status.sh` warns when `main` counts a task as merged but the board still has it working, blocked, in changes, in review or paused. Either `merged.sh` hasn't run yet, or a commit only looks like the task's merge.

## 2026-10-27 — Lead changes go through branches

Scope fixes and card changes went straight to `main` as lead commits, such as the commit that widened T-061's scope to `validate.test.ts`. None of them was reviewed, though a wrong card misleads every worker that reads it. The human wants lead changes reviewed like a task's PR.

- D36: the lead never commits on `main`. Its changes go on `lead/<slug>` branches, and the human pushes, reviews and squash-merges them.
- New `scripts/plan.sh`: `new` (a branch and worktree, `--carry` brings the main checkout's edits along), `check`, `ready` (stores the PR title and body in `cg:lead:<slug>`), `sync` and `list`.
- New `scripts/lead-paths`: what a lead branch may change (docs, scripts, README, CLAUDE.md, `.claude/settings.json`, package READMEs). The `Agent scope` CI check now checks `lead/` PRs against it, read from `main`.
- New pre-commit hook (`scripts/setup.sh` installs it): Claude Code shells can't commit on `main`, and a `lead/` branch can't commit files outside the list.
- `pr.sh` and `merged.sh` take `lead/<slug>`. After a lead merge, `merged.sh` sends each running worker whose card changed a `request` to re-read it and rebase.
- LEAD.md › Lead branches has the flow, including how to widen a running task's scope. The lead prompt, CLAUDE.md hard rule 2, COMMS.md and scripts/README.md point to it.

## 2026-10-27 — Fog of War's rule in the snapshot

T-060's new cards changed what the generated decks draw. Since its merge, the M2 soak is red on `main`: "4 turtle seats, generated decks, seed 4: rejected {forbidden:2}". Fog of War's `noSpells` forbids defensive and offensive spells, but the snapshot doesn't show it and the bots cast anyway. The lead let T-060 merge with the soak red. T-064 hit the same failure and asked whether a bots task should fix the bots, or the test should tolerate the rejections. The human decided the bots must avoid those spells, so PLAN.md's bar of no rejected plan actions at one-bot tables stays as it is.

- New task T-099: `Snapshot.rules` lists the rules that are on for the viewing seat, and the bots and their referee respect `noSpells`. Other seats' rules stay hidden, because Old Library's `noHandSizeLimit` would give away a card in its owner's pool.
- No soak tolerates a `forbidden` rejection. T-099's and T-062's cards say so.
- T-099 waits for T-064 and runs beside T-061. T-065 now waits for T-099, which moves T-065, T-097, T-066, T-062 and T-098 one wave later.

## 2026-10-27 — Fewer approval prompts

- `.claude/settings.json` allows the `pnpm exec` and `pnpm --filter @chaosgrid/<pkg>` forms that agents run, and `GIT_EDITOR=true git rebase`.
- CLAUDE.md › Conventions: use `pnpm exec`, not `npx`, which isn't allowlisted.
- WORKER.md writes `<now>` from a separate `date` call instead of `$(date …)`, because a command substitution needs a human approval.

## 2026-10-26 — Open questions from the merged M3 tasks

The merged M3 tasks (T-047 to T-052, T-058) left open questions in their handoffs. The lead wrote down what the code already does where that was the obvious answer, and the human decided the rest: keep the skill bar at 55, heal every prize at Cleanup, let an On death revive save the last unit, show granted keywords in the snapshot, hide Plan-time changes to the piles until the plans are revealed, reject a Plan revive outside its filter, cap a grid's width at the Chaos Grid's, and break core's import cycles now.

- D33: GreedyBot must beat RandomBot in more than 55 of 100 games (65% before the prize). PLAN.md › M2 says so, and 4 seats.
- D34: the snapshot is public, but what a player changes during Plan (discard pile, void, grid, hand size) stays hidden until the plans are revealed.
- D35: core has no import cycles, and a test guards it.
- RULES.md: every prize is back at full HP at Cleanup; the early end conditions wait for queued On death triggers; a Plan revive outside its filter is an illegal target; a grid is never wider than the Chaos Grid; the targeting tie-breaks end at the lowest id; a permanent's area damage never hits itself, and a color or range filter leaves permanents out; Extra life saves from a kill effect, and a printed and a granted keyword take the larger value; Ward's partial rule; a When played ability rests a free-standing artifact.
- New tasks:
  - T-094 makes the cards tests accept new content (T-060 waits for it).
  - T-095 gives two slow sim-cli tests a timeout (T-061 waits for it).
  - T-096 breaks core's import cycles and adds the guard test (T-064 waits for it).
  - T-097 puts the new rulings in core (T-062 and T-098 wait for it). No payload changes: Plan-time events stay public in the log, because `playRound` applies every plan only after each seat locked its own.
  - T-098 catches up the protocol and core READMEs (M4's T-078 waits for it).
- T-064 also shows granted keywords in the snapshot. T-062's golden also covers a fear from an area.

## 2026-10-22 — T-046's open questions: speed cap, test tiers and caches

T-046 asked four questions in its handoff, and the human answered all four: cap projectile speed at 60 cells per second, run the perf tests alone with their budgets, keep core's caches outside the state with guardrails, and move the long soaks to their own CI job.

- D30: a projectile flies at most 60 cells per second (`MAX_PROJECTILE_SPEED`), so it moves at most one cell a tick. Cards keep their range of 5 to 30.
- T-091 adds the cap to the protocol (v11) and to core's launch and flight. It is M3 wave 8, before T-047: T-047 now depends on it and bumps the version to 12, and every later M3 wave moves down by one.
- D31: `pnpm test` stays quick. Core's perf tests run last, one file at a time (`pnpm test:perf`). The whole-game soaks become `*.soak.test.ts`, which only `pnpm test:soak` and a new CI job run, and `pnpm test` keeps a 5-game smoke. Workers run `scripts/check.sh soak` before handing off a change to core, bots, card data or sim-cli. T-092 does it.
- D32: core may cache derived data outside the state, in `WeakMap`s with guards, as long as a cache never changes a result. T-093 adds the rule and the list of caches to core's README, and a test that plays rounds with empty caches every tick.
- T-092 and T-093 run in wave 8 beside T-091. T-047 now depends on all three. T-062's done-when test becomes `m3-done-when.soak.test.ts`. M4's T-068 now depends on T-092, because both edit the root `package.json` and CI.

## 2026-10-22 — M4 cards: accounts, decks, the lobby and the match

M4's task cards, T-068 to T-090, are on the board (docs/tasks/README.md › M4), with shared conventions in docs/tasks/M4/README.md. The human asked for login and sign-up, a player's own decks, the deck builder, a lobby where the player picks the bots, and the battles, all in M4.

- D12 is superseded by D27: local accounts (a username and a password in SQLite, and a session cookie) arrive in M4, not M6. Player `0` keeps the starter decks. The first account takes the other decks player `0` owns.
- D28: `packages/http` is the HTTP contract between `apps/api` and `apps/web`. A new import rule 7 says it imports only `cards` and `zod`; the web and API rows now include it (DECISIONS.md, CLAUDE.md).
- D29: plan legality comes from core. `checkPlan` and a `plan.checked` event (T-078) answer every `plan.submit` with the actions core would refuse and the seat's snapshot with the plan applied. The UI disables a control only on a fact the snapshot states. The check is exact for seat 0.
- The lobby always has three bots, each with a kind and a deck, because D22 fixes four seats. The bot registry moves from sim-cli to `packages/bots` (T-079).
- The Emblem had no event of its own when it is placed: T-090 adds `emblem.placed`.
- M4 overlaps M3: T-069 and T-070 start now, T-073 waits for T-061 (100-card decks), T-078 and T-079 wait for T-062. T-070's scope sits beside T-061's, and `replay/` and `match/planning/` each pass from one task to the next: stated exceptions to planning rule 1.
- PLAN.md: the layout adds `packages/http`; Runtime shape says how the host answers `plan.submit` and names the transport's four methods; M4 adds accounts, the login pages, copying a starter, the solo lobby and `plan.checked`, and its done-when now plays a whole game in Playwright (T-089), not just round 1; M6's lobby becomes the multiplayer lobby, and its accounts line moves M4's accounts to the server.
- tools/sim-cli/README.md: the replay viewer is M4's T-082, not M3's. PROTOCOL.md cites D27 for the human in seat 0.

## 2026-10-22 — T-067: spell class test, base set only

T-054 found that one test in `packages/cards/src/spells.test.ts` pins the class of every spell id, so each content task's spells break it, and none of them may edit that file.

- New task T-067 (wave 4, beside T-043). The test checks only cards with `set === 'base'`. Each set checks its own spells in `packages/cards/test/sets/<set>.test.ts`.
- T-054 now waits for T-067. The later content tasks start after it merges anyway.
- T-067's scope overlaps T-043's `packages/cards/**`: a stated exception to planning rule 1, since T-067 changes only the file's last `describe`.

## 2026-10-22 — T-065 and T-066: M1 follow-ups

Four questions left open by the M1 reviews got the human's answers. Two became tasks, and two were doc gaps, fixed here.

- New task T-065 (wave 16, after T-064, beside T-061). A permanent that loses Durability gets `permanent.durabilityChanged`, one that stands again gets `permanent.respawned`, and one that goes to the discard pile gets `permanent.retired`. A token that leaves the game gets `squad.despawned`. Decision (human): losing Durability is an event of its own, and reaching 0 is another. T-065 also covers T-048's prize respawn and T-064's expiring tokens. T-062 now waits for it, since both edit the goldens.
- New task T-066 (wave 17, after T-061 and T-065, beside T-062). Core's zones tests build their games from the real starter decks through `loadStarterDecks()`, not a hand-made copy, and read deck sizes from the cards package. Decision (human): reuse packages and functions where it makes sense and doesn't block later work.
- packages/core/README.md › Entry point gets a short Public API section: the three round calls and what they return, `view`, `rng`, and filtering events with `isVisibleTo`.
- packages/cards/README.md › Running the validator now says that `pnpm cards:validate` also checks the starter decks.

## 2026-10-22 — T-064: positions in the snapshot

The snapshot didn't say where Chaos squads, tokens or Emblems are, or where any unit is mid-round. They showed up only in `unit.spawned` and `unit.moved`. So T-042 had to rule Chaos squads out as targets. This gap was first noted in M1 (T-022).

- New task T-064 (wave 15, after T-053, beside T-060). It adds `Snapshot.units` (every unit's world cell, HP and layer), `Snapshot.spawned` (Chaos squads and tokens, with their stats), `ChaosSnapshot.squads` and `EmblemSnapshot.cell`, plus a `PROTOCOL_VERSION` bump.
- Decision: Chaos squads and other seats' tokens can be chosen as squad targets. The prize stays immune (T-048).
- Decision: Mirror Snare and copy share one nearest-squad helper. Tokens count as the caster's squads. A squad without a footprint stands under its lowest-id living unit, and a Chaos squad on the grid of the first seat it was sent against (RULES.md › Sample cards › Traps).
- While plans are hidden, other owners' units and spawned squads come from before the plans applied, as squads do today.
- T-061 now waits for T-064 as well. T-042's card notes that T-064 lifts its restriction.

## 2026-10-22 — M3 consistency pass: played and entered, area damage, spell traps

A pass over RULES.md and the M3 cards for gaps that would leave a worker without an answer, plus the human's answers to the questions it raised.

- Played and entered: a card is played only when its owner casts it. A revived or copied card enters (On enter) but isn't played (When played) unless the effect that brings it says so. Chaos units and tokens are never played. Copy loops are allowed: what ends them is each copying card's limit, and a permanent copies by itself only When played (T-050, T-053).
- Decisions:
  - every enemy spell sets off spell traps: spell cards, Plan and Rest abilities, and copies (T-042, T-053)
  - Fog of War blocks defensive and offensive spells from abilities as well as cards (T-040's card text, T-042)
  - damage that names a place (an area, a row, a radius, adjacent cells, the Trample splash) hits every permanent of the side it names: artifacts, enchantments, revealed traps, the prize and Emblems, but not face-down traps or attached cards. Damage that names no place hits units only (RULES.md › Simulation rules › Area damage, T-040's card texts, T-048)
  - a fear moves away from a fixed cell: the area's center, the cell of the unit whose ability feared it, or the caster's prize for a spell aimed at a squad, a row or a seat (T-052)
  - unit speeds and the round timer get balanced later
- RULES.md, gaps filled: keywords with no definition (Ignores Blockers, Seeks Emblems, Reach and Flying, Push, On kill with assists, Token), the Static keyword against the "Static:" prefix, seat rotation, what may share cells, Reveal's per-tier draws and Extra Chaos, respawn cells, the automatic hand-limit discard, end conditions, the HP of traps, the prize and Emblems, attached cards, Emblem buff durations, the Chaos deck's counts and leader ties, and where Mirror Snare sends a spell. "Backline" became artifacts and enchantments.
- Cards changed: every M3 card from T-040 to T-063 (contexts, interfaces copied from the code, test names that match the acceptance filters, counts by `usageColors`), most notably T-040 (five card texts take RULES.md's wording), T-042 (ability spells under Fog of War and Mirror Snare, which now turns seat and squad targets around), T-048 (area damage on permanents) and T-052 (the fear's source cell). docs/tasks/M1/README.md gets a banner for what M3 changed, and docs/PROTOCOL.md's › Cards heading becomes › Card events, the anchor T-049 and T-050 read.

## 2026-10-22 — M3 answers: Unique, 4 copies, copies set off traps

The answers to M3's open questions settle the deck limits, how removal and copying work, and a few ties.

- D26: a main deck holds at most 4 copies of a card, and 1 of a Unique card. Every Leader is Unique, and units, artifacts, enchantments and traps can be. A Unique card can't be copied. New card T-063 (Unique cards and the 4-copy limit) runs in wave 6 after T-044, and T-047 and T-060 wait for it.
- D6's rationale follows the 30 × 30 grids and the 130 × 130 battlefield.
- RULES.md:
  - Unique and the 4-copy limit in › Components and setup
  - a card has any number of Plan abilities, or none. A cost change touches only the costs the card names, casting costs by default
  - copies set off traps, copy traps included. Each trap fires once, so a chain of copies ends
  - banish and sacrifice remove a card from the grid, and nothing prevents them: not indestructible, Shield or Extra life. A banish scores only when its card says so, and it can also take cards from a hand. A hand can be discarded by an effect as well as by the player
  - a revived card is a new instance at level 1, as if it were cast again
  - fear and rest on all units include the caster's own
  - a Chaos unit's ties go to the player it was sent against (the one in front of it), then to the lowest instance id
  - the prize keeps 20 HP, and the round timer is a balance knob: `lead` raises it to fit first contact
- Renames, so that no card name looks like the Ward keyword or the void zone: Mirror Ward becomes Mirror Snare and Void Maw becomes Abyss Maw (T-040).
- Cards changed: T-040 (the renames), T-042 (`onUse` abilities, each with its own cost and rest, picked by index), T-043 (`costChange` names the costs it changes), T-044, T-047 (Chaos ties), T-049 (banish `scores`, banish from a hand), T-050 (discard by an effect, revive as a new instance), T-051 (banish and sacrifice get past Shield and Extra life), T-052, T-053 (copies set off traps), T-054, T-056 and T-061 (4 copies), T-059, T-060 (the first Unique cards), T-062 (golden round) and the board.

## 2026-10-21 — M3 Rules v2 inserted; M3–M6 become M4–M7

Before the web UI is built, the rules change in ways that touch every layer: time, the battlefield, names, colors, zones and deck size. Doing that first means the UI is built once, on the rules it will ship with.

- New M3 — Rules v2 (PLAN.md › M3, cards T-040 to T-062 in docs/tasks/M3/). The old M3 (decks and the web UI), M4 (balance), M5 (multiplayer) and M6 (desktop) become M4 to M7. Merged cards, older changelog entries and commit messages keep the numbers they had when they were written.
- D18 supersedes D7: one tick is 0.01 s (100 per second), and positions move to subcells (10,000 per cell). Integer math stays exact, so there's no decimal library.
- D19: core plays out the whole Simulate once plans lock, and the UI plays the timeline back in real time. `tick` events become sparse, and `simulate.ended` closes a round's timeline.
- D20: the battlefield's measures are config (30 × 30 grids, a 50 × 50 Chaos Grid, a 10-cell gap), carried in the protocol's arena layout.
- D21: five colors, Ember `R`, Tide `T`, Earth `E`, Dark `D`, Light `L`. Green is called Earth, and Ember's pip moves from `E` to `R` so that Earth can have `E`.
- D22: exactly 4 players, one on each side of the Chaos Grid, with free space in the corners. Chaos units spawn on the Chaos Grid edge facing their player and target the nearest player permanent, so hiding units at the back sends Chaos to a neighbour.
- D23: a card has three color sets: usage cost, card color (unless it says Colorless) and, for Leaders, the color allowance that decides which cards a deck may hold.
- D24: sorceries are now spells (card type `spell`), and the graveyard is the discard pile.
- D25: every grid has a prize, a 2×2 permanent worth 2 points to whoever destroys it, so a player who builds nothing still gives points away.
- RULES.md: traps are free-standing only (Backdraft and Riptide go); a void zone; banish, sacrifice, dump and revive; the Shield, Extra life and Ward keywords; Plan abilities and rested units; fear and copy; the Card colors section; the battlefield and the prize; 100-card main decks; the Balance knobs table updated for 100 ticks per second and the new battlefield.
- New cards T-040 (the renames), T-042 (Plan abilities and rest), T-043 (card colors), T-048 (prize), T-052 (fear), T-053 (copy) and T-060 (cards for them). T-041 now also moves Ember to `R`, and T-047 builds the 4-seat battlefield.
- D4, D11, D12 and import rule 5 point at M6 instead of M5.

M2's done-when gated on win rates: GreedyBot beats RandomBot > 80%, and no bot wins > 60% against the other two. Those numbers measured how strong these bots are compared with each other. But they are simple placeholders that M3 uses as opponents, and better bots will replace them. Tuning them to hit a balance between them says nothing about the game.

- PLAN.md › M2: the done-when now gates on fitness. Across 2, 3 and 4 seats and both deck sources, no game throws, one-bot tables get no rejected plan actions, and at most 5% of their games hit the round cap. Greedy beats random in more than 65% of head-to-head games, as a check that deliberate play pays off. Win rates between bots, game length and points by reason are reported only.
- T-039 becomes "M2 done-when: bot soak". Its test plays one-bot tables through `runGame`, because `GameResult.rejected` counts all seats together. Tuning aims at no rejections and few capped games.
- T-037 and T-038: the soft win-rate targets are replaced by "a one-bot table gets no rejected actions".

## 2026-10-21 — Token budget (D17)

M1 used the weekly token budget in one day. Nearly all of it was cache reads: every step re-sends the whole context, sessions grew to 200k–650k tokens without compacting, and everything ran on Opus. Game work is paused while the workflow gets cheaper.

- D17: workers run on the card's new `model` and `effort` fields (default sonnet, medium), the lead on sonnet, and agent sessions compact at 150k tokens (`autoCompactWindow` in `.claude/settings.json` and in the scripts' flags).
- Cards get a `context:` list and an Interfaces section; `scripts/context.sh T-NNN` prints the card and its context. Planning rules 5, 8 and 9 in docs/tasks/README.md cover size, context and model choice.
- WORKER.md: read through `context.sh` and line ranges, run the gates with the new `scripts/check.sh`, no "claimed" message, inbox read in the commit command, a five-line final message. The new `post-commit` hook (installed by `scripts/setup.sh`) refreshes the heartbeat.
- lead.sh: one wave per lead session, ending with a 10-line summary; it no longer starts tasks that become ready later. `scripts/status.sh --brief` for agents.
- CLAUDE.md gains a Token budget section; LEAD.md one for the human lead. `scripts/tokens.sh` reports usage per task from the local transcripts.
- `.claude/settings.json` allows read-only git commands and the safe scripts.

## 2026-10-21 — Docs catch up with T-027 and T-034

- README.md: rituals are gone from the deck and card-kind tables (merged into sorceries, T-034), and Ranged and Artillery units fire projectiles.
- docs/tasks/M1/README.md: the Spells default no longer says core keeps the old timing.
- packages/core/README.md: `projectiles/` (T-027) in the module map, `arena/`'s start cells (T-028), and the `j` id prefix.
- `projectile.moved` is described as one event per tick, which is what T-027 emits; the schema is unchanged, so `PROTOCOL_VERSION` stays 4.

## 2026-10-21 — Spells; draws during Plan; more cards for the starter decks

- **Spells (human):** sorceries and permanents' abilities cast spells, and each spell's class is in the card data. Utility spells resolve at once during Plan, never deal damage and touch only the caster's own side. Defensive spells target only the caster's own grid and permanents. Offensive spells may target anything, the caster's own permanents included. At tick 0, defensive spells resolve, then offensive ones, then units act. Rituals are merged into sorceries. RULES.md (Round structure, Tick 0, Sorceries and spells, Fog of War), PLAN.md and a new M1 README default.
  - New cards: T-033 (classes and their limits in the card data and the validator) and T-034 (protocol v4's `castSorcery`, the bots and core's plan, combat, view and effects, in one PR because removing the ritual type breaks them all together). T-023 and T-031 now wait for T-034, and T-029 for T-033; T-029 adds utility sorceries instead of rituals. M1 now has 27 tasks in eight waves.
- **Draws during Plan (human):** when a player stat such as `resourceDraw` goes up during Plan (an `attach` charges Jaksho), the seat draws the difference at once and can spend it in the same Plan. T-018 adds `settlePlanDraws`, T-021 calls it through a `settle` hook after each action, and T-023 wires it. The fuller spell model (utility, defensive and offensive spells) is being planned for after the current tasks.
- **Buffs on one stat:** `pointsGained` is exempt from the floor at 0, because Toxic makes it −1 (found by T-018).
- **T-029 grows:** T-030 found that a one-color Leader can play only 14 distinct main deck cards today, and a 40-card deck needs 20. T-029 now adds about 16 cards, with at least 8 more for each color, and depends on T-030 so it can count with the deck rules.

## 2026-10-21 — M1 expanded: projectiles, movement in range, more cards, decks

- **Movement in range (human):** a unit whose target is within its attack range stops and doesn't creep closer while its attack cools down. New RULES.md sentence and M1 README default; T-020's card spells it out.
- **Projectiles (human):** Ranged and Artillery attacks launch projectiles with a kind (`arrow`, `bolt`, `fireball`, `waterball`, `shell`, `orb`), a speed faster than any unit and a position on the arena, and deal damage only when they land. A Trample projectile hits every enemy in its area where it lands, even if its target moved away. New RULES.md paragraph and M1 README default. The lead's defaults to confirm: other projectiles follow their target and miss if it dies, damage is fixed at launch, and On attack fires when the hit lands.
  - New cards: T-026 (the `projectile` field in card data) and T-027 (core's `projectiles/` module, the one task allowed to touch `state/`, to register its slice). T-020 launches and lands them.
- **Protocol v3:** T-025 now also carries the projectile events and `squad.durabilityChanged` (Kettle's Durability heal and Cleanup's −1), so there's one version bump. Its title is now "Protocol v3".
- **Follow-ups from wave 2:** T-028 (unit start cells for squads bigger than their footprint and for spawns), T-018 reads granted keywords for trample and targeting and emits Durability changes, and T-018's coverage test runs every sample card instead of 62.
- **More sample cards:** T-029 adds rituals, enchantments, an Emblem seeker, a big squad and projectile variety.
- **Decks pulled forward from M3:** T-030 (deck rules), T-031 (starter decks) and T-032 (the `decks` tables and seeding). The deck API and builder stay in M3.
- **Dependencies:** T-018, T-020, T-021 and T-023 gain dependencies on the new tasks. M1 now has 25 tasks in seven waves.

## 2026-10-21 — Rules decided during M1 wave 2; arena layout in the protocol

- **Buffs on one stat:** an active `set` of 0 is final; otherwise the newest `set` replaces the base, then amounts add, then factors multiply. It applies to unit and player stats alike, so Drought plus Good Harvest draws 0 while Vask's Speed still takes other Speed buffs. New M1 README default; T-015 and T-016 follow it.
- **Hitting flyers:** a ground unit needs Reach to hit a flying unit, Melee included. The M1 README's Flying default is split in two; T-013 and T-016 follow it.
- **Arena layout in the protocol:** the UI learns the layout from `Snapshot.arena` and `round.started`, not from core's `arena/` (D3). New card T-025, a protocol contract change merged before its users. T-022 now depends on T-011 and T-025 and fills `Snapshot.arena`.
- **Units move with their seat:** seats rotate every round, so T-023 puts each squad's units on its seat's new world cells when a round begins, and emits the layout in `round.started`.

## 2026-10-21 — M1 card fixes after T-008, T-009 and T-010

- **Flying blocks:** the M1 README defaults contradicted each other. The "Flying" default holds: one unit per cell, and flying and ground units block each other. `Unit.layer` only matters for targeting. Fixed the "Cells during the simulation" default and T-012's card.
- **Points:** a seat's fractional total lives on `Player.points` (T-008). The scoring slice keeps only this round's gains and the modifiers. Fixed T-014's card.
- **Card catalog:** `GameState.catalog` holds the card definitions, because `beginRound` and `playRound` take no cards. T-015's `createGame` fills it. Fixed T-015's card.
- **Effect names:** T-016 and T-018 now use the DSL's 14 effects. M0's `setStat`, `reduceCost` and `preventDamage` are `buff`, `restore` is `heal` of Durability, `forbidCast` and `removeHandSizeLimit` are `setRule`, and `redirect` is the `mirror_ward` script. T-016 runs `buff` on unit stats; T-018 runs it on player stats. There's no `level` effect.
- **Pointers to what merged:** T-011 reuses `state/`'s footprint helpers, T-012 moves in integer millicells, T-013 reads `Squad.spawnedFor`, T-016 reads `config.trampleRadius`, T-017 and T-022 use the protocol's `TargetSpec`, and T-021 tests every `RejectReason`.
- Also decided during T-008 and T-009, and recorded in their PRs: core's entry re-exports `time`; protocol v2 adds `permanent.damaged`, a `squadToCell` target and card instance ids on Chaos cards.

## 2026-10-21 — M1 planned; local dev tools

- **M1 broken into 17 task cards** in five waves (`docs/tasks/M1/`). Shared conventions are in `docs/tasks/M1/README.md`: core's module layout and state slices, ids, coordinates, time, events, and defaults for open rules questions. T-008 builds core's skeleton, then each module task owns one folder, so up to seven run at once.
- **PLAN.md M1:** the scoring line now follows RULES.md › Shown points (fractional totals, shown rounded).
- **Running locally:** `scripts/dev.sh` (also `pnpm dev`) starts Redis and a read-only DB viewer (Datasette on `localhost:8080`, in docker compose), then every component's `dev` script. The DB stays SQLite (D11). `pnpm sim` is wired up for T-024's sim CLI.
- **`scripts/pr.sh`:** a long PR body no longer makes the GitHub URL too long. The body goes in the URL only while the URL stays short, and otherwise only to the clipboard.

## 2026-10-20 — Short PR titles, no PR template

- **D16 (replaces D15):** PR titles are `T-NNN <card title>`, for example `T-003 Card schema and validator`. PRs are squash-merged with the title as the commit message, and status tracking looks for commit subjects that start with `T-NNN `.
- **Card titles:** shortened on every M0 card, because they're now the PR titles. `scripts/pr.sh` builds the title from the card, so workers no longer store a `pr_title`.
- **PR template:** removed. Workers write the PR body in three short sections (WORKER.md step 8).

## 2026-10-20 — Lead tools; decisions and changelog split out

- **Lead scripts:** new `scripts/`, for setup, starting workers and lead agents, the board, the lead inbox, messages, opening PRs, recording merges, and dropping tasks. See [scripts/README.md](../scripts/README.md).
- **Starting workers:** `scripts/start.sh` creates each worktree itself on the card's branch and runs Claude Code inside it. It no longer uses `claude --worktree`, which fails until the folder has been trusted and offers to delete the worktree and branch when the session ends.
- **Decisions:** moved from PLAN.md to [DECISIONS.md](DECISIONS.md), each with a status. The import rules and the "working with agents" rules moved there too.
- **D15 (new):** progress is read from git. A task is done once `main` has a commit whose subject ends in `(T-NNN)`.
- **Status:** the README's Status section shows the current milestone, the latest completed task and what's next. `scripts/merged.sh` regenerates it.
- **Changelog:** this file replaces the "What changed in v2" list that was at the top of PLAN.md.

## 2026-10-20 — Plan v2: database, decks, agent workflow

- **New requirements:** a card database seeded from JSON (D10, D11), decks that players build and then play (M3), and no auth for now: everything belongs to player `0` (D12).
- **D4:** now allows a local data API. The game itself still runs in the page.
- **New decisions:** D13 (presentation lives only in `apps/web`) and D14 (agent workflow).
- **Layout:**
  - Added `packages/db`, `apps/api`, `docs/agents/` and `docs/tasks/`, and import rules for the new packages.
  - Import rule 2 now says core can't use Node built-ins, because it runs in the browser (D1, D2).
  - New import rule 6 extends that to every browser package, and gives the card file loader its own Node-only entry point.
- **Card JSON:** one file per card instead of one per card type, so parallel edits don't conflict.
- **M0:** now includes the DB and the reseed command, and is broken into task cards (`docs/tasks/M0/`). Playwright moved to M3, where the first UI appears.
- **Later milestones:** M3 includes the deck builder, M4's card versioning follows the per-card files, and M5 adds accounts and auth.
- **Agent workflow:** CLAUDE.md, the worker and lead playbooks, Redis comms, the CI scope check, and deny rules plus a pre-push hook so agents never push.

## 2026-10-20 — Plan v1

- First drafts of [RULES.md](RULES.md) and PLAN.md: decisions D1–D9 and milestones M0–M6.
