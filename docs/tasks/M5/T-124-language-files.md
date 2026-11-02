---
id: T-124
title: Language files and t()
milestone: M5
depends_on: []
branch: agent/T-124-language-files
model: opus
effort: medium
scope:
  - apps/web/src/i18n/**
  - apps/web/src/app/**
  - apps/web/package.json
  - apps/web/README.md
context:
  - apps/web/README.md#Folders
  - apps/web/README.md#Tests
---

# T-124 — Language files and t()

## Goal

Player-facing text moves into language files (D50). This task builds the base in `apps/web/src/i18n/`:

- ICU MessageFormat messages in `src/i18n/<locale>/<namespace>.json`, one namespace per web folder. English (`en`) is the only locale and the fallback.
- `t(id, values?)`, built on `intl-messageformat` and typed, so an id that no file has fails `pnpm typecheck`.
- One file for every namespace, empty for now. Later cards only add keys to the file of the folder they change, and the typed index never changes again.

Its first user is `src/app/`: the nav, the layout and the error page take their text from the files. The English stays exactly as it is, so the tests still find it.

## Interfaces

What exists (copied from the code on 2026-10-29). T-110 to T-118 don't touch these files:

```ts
// apps/web/package.json: every dependency comes from the pnpm catalog ("react": "catalog:").
//   pnpm-workspace.yaml is a root file (planning rule 4), so this card pins its one new dependency
//   in apps/web/package.json instead, the way packages/db pins "better-sqlite3": "13.0.3".
// tsconfig.base.json: "resolveJsonModule": true, "moduleResolution": "Bundler",
//   "verbatimModuleSyntax": true. A default import of a JSON file is typed from its contents
//   (packages/cards/src/deck/check.test.ts:3 does it).
// apps/web/tsconfig.json: "types": ["node", "vite/client"], so tests can call import.meta.glob.
//   tsconfig.src.json checks src/ again without Node types (tests excluded).

// src/app/Layout.tsx
const NAV = [
  { to: '/cards', label: 'Cards' },
  { to: '/decks', label: 'Decks' },
  { to: '/play', label: 'Play' },
  { to: '/replay', label: 'Replay' },
] as const;                                                      // :5-10
// :17 <span className="cg-pixel cg-logo">ChaosGrid</span>
// :18 <nav className="cg-nav" aria-label="Main">

// src/app/ErrorPage.tsx
function messageOf(error: unknown): string; // :4-8: `${error.status} ${error.statusText}` for a route
//   error response, error.message for an Error, else 'Something went wrong.'
// :16-18 <h1>Something broke</h1> <ErrorText>{messageOf(error)}</ErrorText>
//        <Link to="/decks">Back to your decks</Link>

// src/app/app.test.tsx: finds the pages by their h1, the nav by role 'navigation' and name 'Main',
//   and the error page by its 'Something broke' heading and an alert containing '404'. It must pass
//   unchanged.
// "Back to your decks" is also in decks/editor/DeckEditorPage.tsx:232, which keeps its own copy for
//   now (not in scope).
```

What this task adds:

```ts
// src/i18n/index.ts: the only file other folders import (README › Import rules)
export const LOCALES = ['en'] as const;
export type Locale = (typeof LOCALES)[number];
/** The locale for a player whose language has no folder. */
export const FALLBACK_LOCALE: Locale = 'en';
/** The locale t() formats in: FALLBACK_LOCALE until a card adds a language picker. Intl formatters (lists, dates) take it too. */
export function locale(): Locale;
/** `<namespace>.<key>` for every key in every en/<namespace>.json, for example 'app.nav.cards'. */
export type MessageId; // the mapped type in Notes
export type MessageValues = Record<string, string | number | Date>;
/** The message for `id` in locale(), formatted with `values`. Throws an Error naming `id` when no file has it. */
export function t(id: MessageId, values?: MessageValues): string;

// src/i18n/messages.ts: imports the 13 en files; exports `en` ({ app, auth, …, replay }) and MessageId.
// src/i18n/format.ts (inside the folder only):
export function formatMessage(message: string, values: MessageValues | undefined, locale: Locale): string;
```

## Deliverables

1. **The dependency.** `intl-messageformat` in `apps/web/package.json`'s `dependencies`, at an exact version with no range. Default `10.7.16`; if `pnpm install` can't find it, use the latest release its error names. `pnpm install` updates `pnpm-lock.yaml`. Nothing else is added.
2. **The files.** `src/i18n/en/` holds one file per namespace: `app`, `auth`, `battlefield`, `cards`, `common`, `deckEditor`, `deckList`, `lobby`, `match`, `overlays`, `planning`, `playback` and `replay`. Each is a flat JSON object from key to message. All but `app.json` and `common.json` are `{}`.
3. **The module.** `messages.ts` imports the 13 files and builds `en` and `MessageId`. `t` splits the id at its first dot into a namespace and a key, and throws `Error('No message has the id "<id>"')` when there's no such key. Otherwise it formats with `formatMessage` in `locale()`. `formatMessage` parses with `new IntlMessageFormat(message, locale, undefined, { ignoreTag: true })`, so `<` and `>` are plain text and `format` returns a string. `t` caches one formatter per id.
4. **The app folder.** Every string under `src/app/` moves to the files, with the English unchanged:
   - `en/app.json`: `{ "nav.label": "Main", "nav.cards": "Cards", "nav.decks": "Decks", "nav.play": "Play", "nav.replay": "Replay", "error.title": "Something broke" }`
   - `en/common.json`: `{ "gameName": "ChaosGrid", "backToDecks": "Back to your decks", "somethingWentWrong": "Something went wrong." }`

   `NAV` holds message ids instead of labels, and `t()` runs at render.
5. **Tests** in `src/i18n/i18n.test.ts`:
   - Every message in every file under `src/i18n/` parses: `new IntlMessageFormat(message, folder, undefined, { ignoreTag: true })` doesn't throw. Every file is a flat object of strings.
   - Every locale folder has the same files and the same ids as `en`. `en` has exactly the 13 namespaces that `messages.ts` imports, so a stray or missing file fails.
   - `formatMessage` with test messages, since the real files have none yet: an argument (`Hello {name}`), a plural (`{count, plural, one {# card} other {# cards}}` with 1 and 3) and a number (`{n, number}` with 1000 reads `1,000`).
   - `t('app.nav.cards')` returns `'Cards'`. An unknown id throws an Error whose message holds the id; that call carries a `// @ts-expect-error`, so it proves the type rejects the id as well.
6. **The README.** A row for `i18n/` in the Folders table, and a new section `## Text (D50)` after Tests. Later cards' context names that heading. It says:
   - where the files are, and the ICU a message uses: `{name}`, `{count, plural, one {# card} other {# cards}}`, `{kind, select, …}`, `{n, number}` (a bare `{n}` prints the digits as they are), and quoting (`'{'` for a literal brace; a lone apostrophe, as in "can't", is plain text)
   - the namespaces and the folder that owns each: `app` app/, `auth` auth/, `battlefield` match/battlefield/, `cards` cards/, `common` (below), `deckEditor` decks/editor/, `deckList` decks/list/, `lobby` lobby/, `match` match/'s own files (the page, MatchScreen, session, CardView), `overlays` match/overlays/, `planning` match/planning/, `playback` match/playback/, `replay` replay/. `api/`, `art/`, `host/` and `theme/` have no text of their own.
   - ids: `<namespace>.<key>`, with keys in camelCase words joined by dots and grouped by the part of the folder (`nav.cards`, `error.title`)
   - adding text: add the key to your folder's en file and call `t()` where the text renders, never at module load. Write one message per sentence, with arguments; never glue a sentence from pieces. Plurals use ICU, never `count === 1 ?`.
   - `common.json` holds words several folders share, and only a card whose scope lists it edits it. Any other card keeps a shared word in its own file.
   - what isn't in the files: card names and rules text (the card files are the English source, D50), a thrown Error's message (developer text) and data
   - API errors are worded by their `code` (D50). An area that hasn't moved over yet still shows the API's `message`.
   - tests find text by its English, never through `t()`, so an accidental change fails a test
   - a new namespace (a new folder) adds its file and its import in `messages.ts`, in a card that lists both
   - adding a locale: copy `en/` to `<code>/`, translate the values and keep the ids and arguments, then add the code to `LOCALES`. The tests check the new folder at once. Choosing the locale (a picker, or the browser's language) comes with the card that adds the second language.

## Acceptance

- [ ] `scripts/check.sh` green
- [ ] `pnpm --filter @chaosgrid/web test i18n src/app/` passes, with the tests above
- [ ] `ls apps/web/src/i18n/en` lists the 13 namespace files
- [ ] `grep -rn -E "Something|Back to your|>ChaosGrid<|\"Main\"|'(Cards|Decks|Play|Replay)'" apps/web/src/app --exclude='*.test.tsx'` prints nothing
- [ ] `pnpm test:e2e` passes: the dev server builds the new module, and the nav reads as before

## Out of scope

- Any other folder's text. The cards that change an area move its text (T-125 to T-128, T-134, T-138; T-136 only adds its two new labels), and PLAN.md › M5 lists the rest for later.
- A lint rule against hard-coded text: it's in `eslint.config.js`, a root file, and PLAN.md › M5 lists it for later.
- A second locale, a language picker, reading the browser's language, and `<html lang>`.
- Wording API errors by code.
- Translating card names and rules text (D50: per-locale files keyed by card id, when a language comes).

## Notes

- `MessageId` default, so an empty file adds no ids:

  ```ts
  type En = typeof en;
  export type MessageId = { [N in keyof En]: `${N}.${Extract<keyof En[N], string>}` }[keyof En];
  ```

- Keys are flat (`"nav.cards"`), never nested objects. The type stays one mapped type, and translation tools read the files as they are.
- Default: no fallback per id. The tests keep every locale's ids equal to `en`'s, so a locale never lacks one. `FALLBACK_LOCALE` is for a player whose language has no folder.
- A missing argument makes `IntlMessageFormat` throw, and `t` lets it. It's a bug, and the component test that renders the text catches it.
- A route error's `${error.status} ${error.statusText}` stays in code: it holds no words of ours. A thrown Error's message is shown as it is.
- Call `t()` at render, not in a module-level constant: a language picker must be able to redraw the text later. Constants hold ids, as `NAV` does.
- `formatMessage` stays out of `index.ts`, so other folders can't format text that isn't in the files.
- The test can list every locale folder with `import.meta.glob('./*/*.json', { eager: true, import: 'default' })`, including folders `messages.ts` doesn't import.
- Only this card creates files in `src/i18n/en/` or edits `messages.ts`. From T-125 on, each card edits only the namespace file its scope lists.
- `apps/web/README.md` is also in T-119's and T-123's scopes, waves later. Keep this card's changes to the Folders row and the new section, away from the Art section they rewrite.
- The model is opus because every later web card builds on these ids and conventions.
