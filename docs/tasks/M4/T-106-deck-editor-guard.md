---
id: T-106
title: Ask before leaving the deck editor with unsaved changes
milestone: M4
depends_on: [T-077]
branch: agent/T-106-deck-editor-guard
model: sonnet
effort: medium
scope:
  - apps/web/src/decks/editor/**
context:
  - docs/tasks/M4/README.md#Web layout and ownership
  - docs/tasks/M4/README.md#Routes
---

# T-106 — Ask before leaving the deck editor with unsaved changes

## Goal

The deck editor asks before a reload or a closed tab loses unsaved changes (`beforeunload`), but a link, the nav bar or Back drops them without a word. That was T-077's default, and the human asked for a guard (2026-10-29). After this task, leaving the editor with unsaved changes asks first, in the page: "Leave without saving?", with Keep editing and Discard changes. Saving, the filters and Copy never ask.

## Interfaces

What exists (copied from the code on 2026-10-29):

```ts
// apps/web/src/decks/editor/DeckEditorPage.tsx (T-077)
function Editor({ deckId, cards }: { deckId?: string; cards: ReadyCards }); // :80, for /decks/new and /decks/:id
//   :92 adopt(next: Saved) sets `saved` and `draft` together
//   :121 const dirty: the draft's name, description or deck differs from `saved`
//   :126–131 a `beforeunload` listener while dirty
//   :134 const readOnly = saved.starter; a starter's inputs and tiles are read-only, so it's never dirty
//   :172 save(): once the API answers, adopt(…), then for a new deck only (:190)
//        void navigate(`/decks/${id}`, { replace: true }); // :191, in the same tick as adopt
//   :199 copy(), only on a starter: void navigate(`/decks/${copied.id}`); // :205
//   :233 the browser's filters: setParams(filterToQuery(next), { replace: true }), a query-only move
//   :334 {dirty && <span role="status">Unsaved changes</span>}
export function DeckEditorPage(); // :350
// app/routes.tsx: /decks, /decks/new and /decks/:id are sibling routes, so the editor stays mounted
// when a new deck's first save moves /decks/new to /decks/<id>.

// react-router 8.5.1: the app runs a data router (createBrowserRouter), the tests createMemoryRouter
function useBlocker(shouldBlock: boolean | BlockerFunction): Blocker;
type BlockerFunction = (args: { currentLocation: Location; nextLocation: Location; historyAction: Action }) => boolean;
type Blocker =
  | { state: 'unblocked'; reset: undefined; proceed: undefined; location: undefined }
  | { state: 'blocked'; reset(): void; proceed(): void; location: Location }
  | { state: 'proceeding'; reset: undefined; proceed: undefined; location: Location };
// useBlocker registers its function in an effect, so a navigate() in the same tick as a state change
// meets the function of the last render. A router takes one blocker: a second one warns.

// apps/web/src/theme (T-068)
function Button(props: ButtonHTMLAttributes<HTMLButtonElement> & { primary?: boolean }); // type="button" by default
function Panel(props: HTMLAttributes<HTMLDivElement>);

// apps/web/src/decks/editor/editor.test.tsx (T-077)
function renderEditor(path: string); // renders a memory router (/decks shows <p>list</p>, /decks/new, /decks/:id) and returns it
// stubApi({ [`GET ${ROUTES.deck('d1')}`]: { status: 200, body: deckBody(detail({ deck })) }, … }), cardsRoute
// detail(over): id 'd1', name 'Mine', not a starter; the cards leader, fitting, offColor, chaos, resource
// tile(card), browser(), deckPanel()
```

What this task adds: the guard and its prompt in `decks/editor/`, and their tests.

## Deliverables

1. **The guard.** One `useBlocker` in `Editor`. Its function blocks while `dirty`, when the path changes (`currentLocation.pathname !== nextLocation.pathname`): a link, the nav bar, a `navigate()` or Back. A query-only move, such as the filters, never blocks. On Back the router puts the URL back while it asks.
2. **The prompt.** While `blocker.state === 'blocked'`, the editor shows a prompt built from `Panel` and `Button`:
   - role `alertdialog`, named by its heading "Leave without saving?" and described by "Your changes to this deck will be lost."
   - **Keep editing** calls `blocker.reset()`: the editor stays as it was, edits included. It has the focus when the prompt opens, and Escape does the same as a click on it.
   - **Discard changes** calls `blocker.proceed()`, and the move goes ahead.
   - Where it shows and how it looks are your choice.
3. **The editor's own moves pass.** A new deck's first save moves to `/decks/<id>` (:191) and never asks. `adopt` and that `navigate` run in the same tick, so the blocker function the router holds still sees `dirty` as true, and a state flag would be too late. Use a ref the function reads first: set it just before that `navigate`, and clear it once the function has let the move through. Without it, the first-save test that exists (it waits for `/decks/d9`) fails. Copy needs nothing: it's only on a starter, and a starter is never dirty.
4. **Tests**, in `editor.test.tsx`:
   - dirty, then `router.navigate('/decks')`: the prompt shows and the path stays; Keep editing closes it and keeps the edits ("Unsaved changes" still shows); again, then Discard changes: the path is `/decks`
   - Escape in the prompt does what Keep editing does
   - not dirty: `router.navigate('/decks')` goes there with no prompt
   - a filter change while dirty: no prompt, and the query changes
   - Back: `renderEditor('/decks')`, `router.navigate('/decks/d1')`, an edit, then `router.navigate(-1)`: the prompt shows; Discard changes goes to `/decks`
   - a new deck's first save goes to `/decks/<id>` and no `alertdialog` shows (a new test)
   - the existing tests pass unchanged

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test -- editor` passes
- [ ] `git diff main...HEAD -- apps/web/src/decks/editor/editor.test.tsx` only adds tests: no existing test changes

## Out of scope

- A "Save and leave" choice.
- Other pages, and a dialog component in `theme/`: that folder has its own owner. If you need one there, ask `lead`.
- Logout, and RequireLogin's redirect when the session ends: both leave without asking, as today. Once `auth` is a guest, RequireLogin swaps the editor for a redirect, and the editor's unmount drops its blocker.
- A new deck when a mounted editor moves from a deck to `/decks/new`: nothing in the app makes that move today. The only link to `/decks/new` is on the deck list, which unmounts the editor.

## Notes

- Default: a prompt in the page, not `window.confirm`: jsdom doesn't implement it, and the e2e finds elements by role.
- Default: the prompt shows over the editor, and the rest of the editor is `inert` while it shows (React 19 takes `inert` as a boolean), so a click or Tab can't reach the edits.
- Default: a move that changes only the query is never blocked.
- One `useBlocker`, no more: react-router warns about a second one in the same router.
- `beforeunload` stays, for a reload or a closed tab.
- T-089's `m4.spec.ts` saves before it leaves the editor, so it meets no prompt.
- In the tests, `router.navigate` returns a promise: wrap it in `act`, or wait for what the page shows.
