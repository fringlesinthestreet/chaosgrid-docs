---
id: T-142
title: Match screen follow-ups
milestone: M4
depends_on: [T-118]
branch: agent/T-142-match-screen-follow-ups
model: sonnet
effort: medium
scope:
  - apps/web/src/match/CardView.tsx
  - apps/web/src/match/CardView.test.tsx
  - apps/web/src/match/planning/**
  - apps/web/e2e/m4.spec.ts
context:
  - docs/RULES.md#Round structure
  - docs/APPS.md#The match
---

# T-142 — Match screen follow-ups

## Goal

Three small changes to the match screen, from the T-110 to T-118 handoffs and the human's answers on 2026-10-30:

- **Escape closes one thing at a time.** With a planning selection and the card view both open, one Escape now closes both. After this task the first closes the card view and the second cancels the selection.
- **One discard pile.** The tray lists the player's own discard pile (T-115), and the Zones panel lists it again. After this task the Zones panel keeps the player's void and every other seat's pile and void.
- **The Discard step shows what goes.** The checkboxes start empty, and a player who does nothing loses their most recently drawn cards (D42) without seeing which. After this task those cards start ticked, so the screen shows what the automatic rule discards, and the clock discards what's ticked when it runs out.

## Interfaces

What exists (copied from the code on 2026-10-30):

```ts
// apps/web/src/match/CardView.tsx:94-102, in CardView: a window listener while a subject is open
const onKey = (event: KeyboardEvent) => {
  if (event.key === 'Escape') close();
};
window.addEventListener('keydown', onKey);

// apps/web/src/match/planning/index.tsx:138-155, in the planning provider: while a selection is set
const onKey = (event: KeyboardEvent) => {
  if (event.ctrlKey || event.metaKey || event.altKey) return;
  if (event.key === 'Escape') select(null);
  else if (/* R or r, placing, not moveLeader */) select({ ...selection, rotated: !selection.rotated });
};
window.addEventListener('keydown', onKey);
// Both run on one Escape. A hand tile's click opens the card view and keeps the selection
// (HandEntry.tsx:60), so "Place Leader", a tile click, then Escape closes both.

// apps/web/src/match/planning/ZonesPanel.tsx:44-60, one <details> per seat, the viewer's first and open
<details key={player.seat} open={own} data-zones-seat={player.seat}>
  <summary>{name}</summary>                       // 'You' or `Seat ${seat}`
  {!own && <p>As of the start of Plan</p>}
  {list(`${name}: discard pile`, player.discardPile.map((entry) => entry.cardId), name)}
  {list(`${name}: void`, player.void, name)}
</details>
// The tray's own pile: Tray.tsx:82, <section aria-label="Discard pile">.

// apps/web/src/match/planning/DiscardHand.tsx
function DiscardTimer({ discardSeconds }) // :20, counts down from mount; at 0 sends session.ready() once (`sent` ref)
export function DiscardHand({ view }: { view: Snapshot }) {
  const [ticked, setTicked] = useState<readonly CardInstanceId[]>([]); // :55, starts empty
  const count = view.players.find((player) => player.seat === view.seat)?.discardCount ?? 0;
  const refusal = state.discardChecked?.reason ?? null;
  // :75-81, the button: disabled={ticked.length !== count}, onClick={() => session.chooseDiscards(ticked)}
  // :85-92, view.hand.map(entry => <HandEntry discard={{ ticked, toggle }} />)
}

// apps/web/src/match/session.ts
// ready() while discarding: sends player.ready, and the seat is done (the automatic rule).
// chooseDiscards(cards): sends discard.choose. discard.checked with reason null settles the seat;
//   with a reason, the seat still owes the step and state.discardChecked holds the refusal.

// packages/core/src/zones/hand.ts
// handOf: the hand, oldest first. The snapshot's view.hand keeps that order.
// discardNewest(state, seat, count): the automatic rule, the last `count` cards of the hand.
```

The host's Discard step (T-116): an accepted `discard.choose` is final, and `player.ready` means "the automatic rule". When the last seat is done, the next round's Plan starts at once, so a seat that sends both may also ready the next Plan. Never send both.

`apps/web/e2e/m4.spec.ts:39-49`, `discardCards(page)`: reads the count from the Discard group, checks the first N checkboxes, then clicks "Discard N".

What this task adds: no new exports, no protocol or session change, no new text.

## Deliverables

1. **Escape, the card view first.** CardView's keydown listener runs in the capture phase (`window.addEventListener('keydown', onKey, true)`, and the same flag on removal), and calls `event.preventDefault()` when Escape closes it. The planning listener returns at once when `event.defaultPrevented`. The card view still gives the focus back on close, and R still turns the footprint with the card view open.
2. **Zones without the own pile.** ZonesPanel lists the viewer's void only, and every other seat's discard pile and void, as now. Its header comment and index.tsx's header (":7 every seat's discard pile and void") say so: the viewer's own pile is the tray's.
3. **Preselected discards.** DiscardHand's ticks start as the automatic rule's cards: the ids of the last `count` entries of `view.hand`. The button is enabled at mount. Toggling works as now, and the button still asks for exactly `count`.
4. **The clock sends what's ticked.** At 0, DiscardTimer sends `session.chooseDiscards(ticked)` if exactly `count` cards are ticked, else `session.ready()`, once. If core refuses the clock's choice (a new `discard.checked` with a reason after it), the clock sends `session.ready()`, so the step still ends. It never sends both for one choice that core accepted. Pass it what it needs as props. Update its doc comment and DiscardHand.tsx's header.
5. **Tests.**
   - `PlanningPanel.test.tsx`: "Place Leader", a hand tile click, Escape: the card view is gone and the selection's status is still shown. A second Escape cancels it. Nothing is sent.
   - `CardView.test.tsx`: Escape closes the view and the event is `defaultPrevented`.
   - `Zones.test.tsx`: no "You: discard pile"; "You: void" and the other seats' lists as now. The click test at :116 opens a card from another seat's pile.
   - `Tray.test.tsx` › Tray while discarding: at mount the last `count` tiles are ticked and the button is enabled. The button sends the ticked cards. With one tick changed, the clock sends those cards at 0; with one unticked, it sends ready. A refusal after the clock's choice sends ready once. Rewrite the test at :147 that expects the button disabled at mount.
6. **The e2e helper.** `discardCards` in `m4.spec.ts` keeps the preselected ticks and clicks "Discard N"; first it checks that exactly N checkboxes are checked.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test planning CardView` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `pnpm test:e2e` passes.
- [ ] The PR lists steps for the human to try in a solo game: open the card view during a selection, then press Escape twice; in a Discard step, the newest cards start ticked; let a Discard clock run out with other cards ticked, and those go.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- The card view's list of attached cards: T-140 (M5).
- New words: this task adds none (D50, the language files arrive with T-124). If a change needs text, ask `lead`.
- The host's Discard step and the session (T-116): unchanged.
- The tray's discard pile: its order and place stay.

## Notes

- Defaults: a seat whose ticks don't number `count` when the clock runs out gets the automatic rule, whatever is ticked. The Discard clock still reads "No limit" above the limit (D41).
- The PR says what Escape closes in each case, and how the refusal fallback was tested.
