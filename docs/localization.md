# Localization

The English text is the key (gettext style). Every player-facing string goes through one of two
markers, an extractor turns them into a catalog with context, and a translation tool fills one
state file per language, from which the game's runtime table is built.

## The two markers

Both come from `src/l10n/Loc.hx` and are imported into every module under `src/` by `src/import.hx`.
Code that calls `Loc.tr`/`Loc.fmt`/`Loc.colored` itself adds `import l10n.Loc;`. The class can't be
imported in `import.hx`: that file applies to `Loc.hx` too, and the self-import breaks every other import
in it. **The package is `l10n`, not `loc`**, because the `T` macro expands to `l10n.Loc.tr(…)` at the call
site, and a local variable named `loc` (common here) would shadow a package of that name.

| marker | does | use it for |
|---|---|---|
| `T('…')` / `T('…', {args})` | translates now (a macro: expands to `Loc.fmt(Loc.tr('…'), args)`) | everything shown and not kept: UI labels, log lines, messages, tables read only for display |
| `N('…')` | marks for extraction only, the text stays English | text that is **saved** or **compared in code**: item/AI/object names, jobs, ordeal and mission names. Translate it where it is displayed: `Loc.tr(value)` |

- The argument is a **constant literal** (`'a' + 'b'` folds). Anything else, or a `$`-interpolated
  single-quoted string, is a compile error: the extractor reads the literal, so a computed string
  would never be translated. Values go in placeholders.
- With args, the macro checks both ways: every `{name}` in the literal has a field in the args
  object, and every field is used.
- `T()` without args may return a template that is formatted later with `Loc.fmt(tpl, args)`.
- Why `N` keeps English in memory: logic keys (`info.name == 'laptop'`, `Jobs.jobsByName`,
  `ChatConst` keys) keep working, and saves hold English, so a save loads in any language.
- A `// tr: …` comment on the line(s) above a marker reaches the translator as a note.
- Not localized: console commands, debug overlays, `changes.md`, proper-name pools (`NameConst`).

## Placeholder syntax

Parsed by `Loc.parse` (game) and `tools/loc/locfmt.py` (tools); the two must agree.

| syntax | meaning |
|---|---|
| `{x}` | the value: a string, a number, or a noun (bare form) |
| `{x:form}` | a noun in a form; a form with a capital first letter (`The`, `Def`) capitalises the result |
| `{n, plural, one{# turn} other{# turns}}` | plural by `Intl.PluralRules` of the language; `#` is the number; `=0{…}` matches exactly |
| `{x, select, m{his} f{her} other{its}}` | on a noun: its grammatical gender; on a string: the string |
| `%name%` | scenario-note tokens, kept as they are |

No apostrophe escaping (French needs plain `'`/`’`) and no literal braces in text.
`Loc.colored(col, value)` wraps the whole formatted phrase, article included, in the same span as
`Const.col`.

## Nouns

A placeholder value that is an entity (`getLocNoun(): _LocNoun`) or a `_LocNoun` is a noun:
`{key, kind, gender}`. `kind` is `LOC_NOUN` (common noun, gets articles), `LOC_NAME` (proper name,
never translated) or `LOC_PHRASE` (translated, no article: `'your host'`). `gender` is the natural
one: `m`, `f`, `n`.

| language | forms | rule |
|---|---|---|
| English | `the`, `a`, bare | rules (a/an by first letter); names and phrases take none |
| French | `def` (le/la/l’), `indef` (un/une), `de` (du/de la/de l’), `a` (au/à la/à l’), bare | from the noun table entry `{g, s, fs?, elide?, forms?}`: `fs` = feminine variant for female entities (policière), `elide` = override the vowel/mute-h rule, `forms` = explicit forms. Names and phrases: `de X`/`d’X`, `à X` |
| others | from `forms` in the noun table, else bare | add a rule function in `Loc.nounForm` when the language lands |

A missing noun entry is recorded (`loc missing` shows `noun: <key>`) and stands in as the bare
translation of the key.

## Files

| path | what |
|---|---|
| `loc/en.json` | the catalog, rewritten by every build (tracked: its diff is the string change log) |
| `loc/<code>.json` | per-language state, one record per string keyed by sha1 of the English |
| `electron/lang/<code>.json` | runtime table `{strings, nouns, fonts…}`, copied into `app/lang/` by the build |
| `tools/loc/extract.py` | the extractor (`--check`, `--strict`, `--list <code>`, `--root <dir>`, `--selftest`) |
| `tools/loc/locfmt.py` | placeholder parser + the markup check translations must pass |

## Runtime

- `Loc.tr` loads the table lazily, on its first call during static init, through the synchronous
  `host:lang` IPC call. The main process picks the language: the settings.json `lang` key, else
  the Steam game language (`apps.currentGameLanguage()`), else `en`.
- **Trap:** `Loc`'s statics have no initialisers. An initialiser would run after other classes had
  already filled the table, and wipe it.
- Changing the language (Options → Interface → Language, or console `loc <code>`) saves the setting
  and reloads through `HostBridge.reload()` → `host:reload`. The page's own `location.reload()` does
  nothing here: it is a navigation, and `will-navigate` blocks every navigation in the window.
- The `gen` build (node) and the www build stay English.
- Missing translations fall back to English. Every miss is counted.
- `<html lang>` follows the active language.

## Checks

- `cd src && make` runs `loc-test` (`src/l10n/LocTest.hx` under node: formatter, plural, select,
  English/French forms, pseudo), then `extract.py --check`. The check prints
  `loc: N strings (+a -b since last build) · fr: x new (y changed), z removed`. That line is the
  notification that a string changed and needs translating.
- Console (debug): `loc` (current + available), `loc <code>`, `loc pseudo` (accented, +30%
  length, `⟦…⟧`: any plain English left on screen is a string that skipped the markers, and
  overflow shows), `loc missing` (strings shown without a translation this session).

## Translating

`tools/loc/translate.py` (the `claude -p` route and quota handling come from `../translate-agent`):
Opus 5.5, high effort, two passes. State is per string, keyed by sha1 of the English, so batches
are only transport: a new or edited string never re-translates the rest.

| command | does |
|---|---|
| `make loc-probe [lang=fr] [n=3] [files=cult/events,PediaConst]` | translate `n` batches spread over the (filtered) catalog, both passes, then build |
| `make loc [lang=fr] [jobs=4]` | everything pending (new, failed, or missing pass 2), then build |
| `make loc-build [lang=fr]` | `electron/lang/<lang>.json` from the state (+ `loc/nouns-<lang>.json`); French typography (non-breaking spaces, ’) is applied here, not trusted to the model |
| `python3 tools/loc/translate.py status --lang fr` | counts per status |

- The system prompt is `loc/prompt.md` (pass 1) or `loc/revise.md` (pass 2) followed by
  `loc/style-<lang>.md`. The style sheet holds register, typography, noun forms, plurals and the
  glossary. **Fix translations there, not in the state**: delete the affected records from
  `loc/<lang>.json` and re-run.
- Every translation must pass `locfmt.check` (same placeholder names, html tags, entities,
  `%tokens%`) and a length guard; rejects are retried with a nudge, then marked `failed`.
- `[TERM]` suggestions from the model go to `loc/.logs/<lang>-terms.txt` for review, and are never fed
  back automatically. In the book pipeline, an auto-glossary in the state overrode the hand-written one.
- Raw replies are in `loc/.logs/<lang>.jsonl` (gitignored).
- Use `lang=`, never `LANG=`: that is the locale of every process make starts.

