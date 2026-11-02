---
id: T-088
title: Match overlays, the reveal, round summary, log and game over
milestone: M4
depends_on: [T-085, T-086]
branch: agent/T-088-overlays
model: sonnet
effort: medium
scope:
  - apps/web/src/match/overlays/**
context:
  - docs/APPS.md#The match
  - docs/PROTOCOL.md#Game and round
  - docs/PROTOCOL.md#Planning
  - docs/PROTOCOL.md#Card events
  - docs/PROTOCOL.md#Chaos and score
  - docs/PROTOCOL.md#`ChaosSnapshot` and `EmblemSnapshot`
---

# T-088 — Match overlays, the reveal, round summary, log and game over

## Goal

The battlefield shows where everything is, but not what happened. After this task the match screen announces each round and its Chaos cards, sums up each round when it ends, keeps a round log the player can open, and ends the game with a winner screen that leads back to the lobby. Everything here reads the `MatchModel` (T-081) through `useSession()`, never the snapshot.

## Interfaces

What exists (T-081, T-085, T-086):

```ts
// apps/web/src/match/model (T-081)
// MatchModel: seats, settings, round, phase, points, squads, units, permanents, chaos, simulateEnded, winners, log
// A retired squad stays in `squads` with `retired: true` (its units are gone), so its card and owner stay known.
export interface LogEntry { round: number; tick: number | null; event: Event } // event is one of LOGGED_EVENT_TYPES
export const LOGGED_EVENT_TYPES: readonly EventType[];
export type SimulateEndReason; // SimulateEndedEvent['reason']: timeUp, lastStanding, chaosWon
// chaos.revealed, plans.revealed, unit.died (Leaders only), squad.retired, trap.fired, emblem.broken,
// points.scored (non-zero), plan.rejected, simulate.ended, round.ended, game.ended, and from M3
// squad.sacrificed { squad }, squad.revived { squad, from, card } (its squad.placed comes right after),
// card.banished { seat, card, cardId, from: grid | discardPile | deck | hand, squad?, permanent? },
// unit.saved { unit, livesLeft } (an Extra life), cards.dumped and cards.discarded { seat, cards: CardId[] }
export const EMPTY_MODEL: MatchModel; export function applyEvents(model, events): MatchModel;
// apps/web/test/fixtures/logs/ (T-081): starter-2-rounds.json, emblem.json

// apps/web/src/match/session.ts (T-085): useSession() → { session, state }; state.playback.model, state.seat; session.cards
// apps/web/test/fixtures/session.ts (T-085): stubSession(state, cards)
// apps/web/src/match/planning/draft.ts (T-086): REJECT_TEXT
// apps/web/src/match/overlays/index.tsx (T-068 placeholder): Overlays, no props, rendered on top of the screen by T-085
// @chaosgrid/protocol: ScoreReason (kill, leaderKill, chaosKill, emblem, prize, survival, chaos, banish),
//   ChaosKind (units, rule, emblem, nothing), PlanActionType
```

What this task adds (`apps/web/src/match/overlays/`):

```ts
// log.ts (pure)
export interface Names { card(cardId: string): string; seat(seat: Seat): string } // seat: "You" for the viewer, else "Seat n"
/**
 * One sentence per log entry: "Seat 2's Leader died", "You scored 3 (kills)", "Emblem of Embers broke: Seat 1 scores 5",
 * "Seat 3 revived Grave Knight", "Your Bone Thrall was banished", "Seat 2's Shieldbearer used an Extra life (1 left)",
 * "You discarded 2 cards: Kindle, Scorch Line".
 */
export function describeLogEntry(entry: LogEntry, model: MatchModel, names: Names): string;
export const SCORE_REASON_TEXT: Record<ScoreReason, string>;
export const SIMULATE_END_TEXT: Record<SimulateEndReason, string>; // 'timeUp' → "Time ran out", …
export interface RoundSummary {
  round: number;
  gained: Record<Seat, number>;            // the points.scored of the round, per seat
  gainedBy: Record<Seat, Partial<Record<ScoreReason, number>>>; // the same, split by reason
  scores: Record<Seat, number>;            // round.ended's
  emblems: { cardId: string; breaker: Seat | null }[];
  leadersDied: Seat[];                     // seats whose Leader died this round
  retired: Record<Seat, number>;           // squads retired, per owner, when the model knows the owner
  revived: Record<Seat, number>;           // squad.revived, per owner, when the model knows it
  banished: Record<Seat, number>;          // card.banished, per owner (its `seat`)
  ended: SimulateEndReason | null;
}
export function roundSummary(model: MatchModel, round: number): RoundSummary | null; // null until round.ended

// index.tsx
export function Overlays(): JSX.Element; // still no props
```

## Deliverables

1. **Round banner.** When the model's `round` goes up, "Round N" fades in over the battlefield, with this round's Chaos cards (`model.chaos`): each with its name, its kind ("Units", "Rule", "Emblem", "Nothing"), "Extra" when it is, and "spawns in front of <seat>" for its targets (the Chaos edges, PROTOCOL.md › Arena layout). A `rule` card shows its text from `session.cards`. It hides after 4 s or on a click. A "Chaos" chip in the corner keeps this round's cards and reopens the banner. The banner never blocks the planning panel: the overlay layer lets clicks through (`pointer-events: none`) except on its own controls.
2. **Round summary.** When a `round.ended` is applied, a card in the corner shows `roundSummary`: each seat's gain and score, sorted by score, the viewer marked "You", with the gain split by `SCORE_REASON_TEXT` on hover; Emblems broken and by whom; Leaders that died; squads retired, revived and banished; why Simulate ended. Close, or it closes when the next round's timeline starts playing.
3. **Round log.** A "Log" button opens a drawer with `model.log` grouped by round, the newest round open and the others collapsed, one `describeLogEntry` line each, with the tick when it has one. It scrolls to the end as entries arrive, unless the player has scrolled up. The viewer's own `plan.rejected` lines use `REJECT_TEXT` from `../planning/draft`.
4. **Game over.** When `model.winners` is set: a modal with "You win", "Seat 2 wins", or on a tie "Tie: You and Seat 3"; the final scores; and the buttons Play again (to `/play`), Decks (to `/decks`) and View board, which closes the modal and leaves the final board on screen.
5. **`describeLogEntry`** is an exhaustive `switch` over the logged types. It names what the model still knows (a unit's card and owner from `model.units`, a squad's from `model.squads`, a retired one included) and falls back to a plain line ("A squad retired") when the stream left it out. A Chaos unit or a token has an `owner` but no entry in `model.squads`: name it from `model.units` (`cardId`), and "Chaos" for the owner `'chaos'`.
6. **Tests:**
   - `log.ts`:
     - every entry of both fixture logs gives a line without "undefined" or "[object"
     - every `LOGGED_EVENT_TYPES` entry is handled: a hand-built entry for each type the fixtures lack, the six M3 types included
     - `card.banished` gives a line for each `from`; `squad.revived` names the card once its `squad.placed` is folded, and falls back without it; `squad.retired` names the squad's card and owner after the retirement is folded
     - `SCORE_REASON_TEXT` and `SIMULATE_END_TEXT` have a text for every option of their enum (`ScoreReason` has eight)
   - `roundSummary` on `starter-2-rounds.json`: null before round 1's `round.ended`; for rounds 1 and 2, each seat's `gained` equals the change in its `round.ended` score, and the sum of its `gainedBy`
   - `roundSummary` on `emblem.json`: the round the Emblem broke lists it with its breaker
   - the overlays on `stubSession`, with models folded from the fixtures (`applyEvents`), inside a `MemoryRouter`:
     - the banner shows "Round 2" and the Chaos card names after round 2's Begin, and hides after 4 s (fake timers)
     - after round 1's `round.ended`, the summary shows every seat's gain
     - the log drawer lists round 1's lines
     - `winners: [0]` shows "You win"; `[1, 2]` shows the tie text; Play again navigates to `/play`

## Acceptance

- [ ] `crew check` green
- [ ] `pnpm --filter @chaosgrid/web test -- overlays` passes

## Out of scope

- Saving a live match as a replay file: the live stream is filtered for the viewer's seat (`isVisibleTo`), so it isn't a full log. The replay viewer takes sim-cli logs.
- Sound, and animation beyond fades.
- The points in the top bar (T-085).

## Notes

- Default: the banner and the summary don't pause playback or the Plan timer, and they never cover the planning panel's controls.
- Default: Chaos card names come from `session.cards`, which holds every card `useCards()` loaded (T-085), Chaos cards included. An unknown id shows the id.
- `unit.died` is in the log only for Leaders (T-081), so "Seat 2's Leader died" is always the right sentence for it.
- `points.scored`'s `amount` is the change in shown points, so it can be negative. Write "loses" for a negative amount.
- `squad.revived` comes before the new squad's `squad.placed`, so a line written while folding wouldn't know the card. Write lines from the model at render time, as the drawer does; the fallback is "A unit came back from a discard pile".
- `cards.dumped` and `cards.discarded` name card ids, not instances: the discard pile is public. Say "dumped 3 cards from the deck" and "discarded" (from the hand), with the names.
