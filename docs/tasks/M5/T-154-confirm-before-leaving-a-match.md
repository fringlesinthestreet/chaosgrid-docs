---
id: T-154
title: Confirm before leaving a match
milestone: M5
depends_on: []
branch: agent/T-154-confirm-before-leaving-a-match
model: sonnet
effort: low
scope:
  - apps/web/src/match/index.tsx
  - apps/web/src/match/LeaveGuard.tsx
  - apps/web/src/match/LeaveGuard.test.tsx
  - apps/web/src/i18n/en/match.json
  - apps/web/e2e/bot-worker.spec.ts
context:
  - apps/web/README.md#Text
  - apps/web/README.md#Tests
---

# T-154 — Confirm before leaving a match

## Goal

A match runs in the page (`GameHost`) and nothing saves it, so leaving the match page loses it. Closing the tab or reloading already asks, through the `beforeunload` in `match/index.tsx`, but the app's own links (the nav's Cards, Decks and Play, the account menu) leave at once. The human asked for a confirmation (2026-11-04). After this task a link that would leave a running match asks first, as the deck editor asks about unsaved changes.

## Interfaces

What exists (copied on 2026-11-04):

```tsx
// apps/web/src/match/index.tsx:124-139
function Running({ session }: { session: MatchSession }) {
  const state = useSessionState(session);
  const over = state.playback.model.winners !== null || state.error !== null;
  useEffect(() => {
    if (over) return;
    const warn = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [over]);
  return (
    <SessionContext.Provider value={session}>
      <MatchScreen session={session} />
    </SessionContext.Provider>
  );
}

// The pattern to follow: apps/web/src/decks/editor/DeckEditorPage.tsx:137-145 and 373-389
const blocker = useBlocker(({ currentLocation, nextLocation }) => {
  if (passing.current) { passing.current = false; return false; }
  return dirty && currentLocation.pathname !== nextLocation.pathname;
});
{blocker.state === 'blocked' && (
  <Panel role="alertdialog" aria-modal="true" aria-labelledby="leave-title" aria-describedby="leave-text"
         onKeyDown={(e) => { if (e.key === 'Escape') blocker.reset(); }}>
    <h2 id="leave-title">Leave without saving?</h2>
    <p id="leave-text">Your changes to this deck will be lost.</p>
    <Button primary autoFocus onClick={() => blocker.reset()}>Keep editing</Button>{' '}
    <Button onClick={() => blocker.proceed()}>Discard changes</Button>
  </Panel>
)}
```

The app's router is `createBrowserRouter` (`app/index.tsx`), so `useBlocker` works; tests render with `createMemoryRouter`. `Panel` and `Button` come from `../theme`, `t()` from `../i18n`, and the `match` namespace is `en/match.json`.

`apps/web/e2e/bot-worker.spec.ts` starts a match, plays into round 2, then clicks the nav's Play link (line 33) and checks that the bots' worker is gone.

## Deliverables

1. **`LeaveGuard`**, in `match/LeaveGuard.tsx`: `export function LeaveGuard({ active }: { active: boolean })`. While `active`, it blocks a navigation that changes the pathname (`useBlocker`) and shows the dialog. `Running` renders `<LeaveGuard active={!over} />` beside the screen and keeps its `beforeunload`.
2. **The dialog:** a `Panel` with `role="alertdialog"`, `aria-modal`, its title and text linked by `aria-labelledby` and `aria-describedby`, centred over the match screen. Title "Leave the match?", text "The match will be lost: it can't be resumed.", the buttons "Stay" (primary, focused when it opens; `blocker.reset()`) and "Leave match" (`blocker.proceed()`). Escape stays. The text is in `en/match.json` under `leave.*`.
3. **Once the game is over** (a winner, or an error), links leave at once, as the `beforeunload` already lets the tab close.
4. **Tests** in `match/LeaveGuard.test.tsx`, with a memory router whose `/match` route renders the guard and a link to `/cards`:
   - active: a click on the link shows "Leave the match?" with "Stay" focused, and the page stays on `/match`;
   - "Stay" and Escape close it and stay; "Leave match" goes to `/cards`;
   - inactive: the link goes to `/cards` with no dialog.
5. **The e2e:** `bot-worker.spec.ts` answers the dialog with "Leave match" after its click on Play, and checks the dialog showed first.

## Acceptance

- [ ] `crew check` is green.
- [ ] `pnpm --filter @chaosgrid/web test LeaveGuard match` passes. Write the filter with no `--`: after `--`, Vitest runs every file.
- [ ] `pnpm test:e2e` passes.
- [ ] `git diff --stat main...HEAD` lists only files in the scope.

## Out of scope

- Saving or resuming a match: M6's reconnect.
- The replay page: leaving it loses nothing.

## Notes

- Defaults: the dialog doesn't pause the match; playback and the clocks keep running behind it. "Stay" is the safe, focused choice.
- The PR says which keys it added to `en/match.json`.
