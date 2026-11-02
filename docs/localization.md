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

## Sentences about someone: whole templates, never pieces

`ai.log`, `ai.logsg`, `attacker.log`, `cult.log`, `cult.logsg` log their string as is: no subject
glued in front, no full stop added, no pronoun rewriting. The subject is a placeholder in the one
template, and pronouns are selects on it:

```haxe
ai.log(T('{ai:The} claws at {ai, select, m{his} f{her} other{its}} own eyes.', { ai: ai }));
cult.log(T('{cult} gains a new member: {ai}.', {
  cult: this,
  ai: aidata,
}));
attacker.log(Loc.fmt(weapon.textHit, { attacker: attacker, target: target, damage: damage }));
```

- **A sentence whose object can be the parasite itself** (an `AttackTarget` of type
  `TARGET_PLAYER`) gets a separate template with a literal "you": French puts the object pronoun
  before the verb, so `{target}` = "you" cannot work. Weapons carry `textMiss`/`textMissYou`/
  `textHit`/`textHitYou` (+ `textStun`) for this reason.
- A value that is a key the game shows as is in English (a cult power: `combat`, `media`…) goes in
  raw with a `// tr:` note listing the keys, so the translator can write a select on it.
- A stored template (a weapon text, a `ChatConst` table) is `T('…')` where defined and
  `Loc.fmt(tpl, { … })` where used.
- An object's name shown on its own: `o.getDisplayName()` (translated; habitat objects add their level).
- **1.0 mod API:** mods call `host.log('lights the cigar.')` with a bare English predicate. A string
  that starts lowercase or with a space is taken for one and still gets the subject (and, for
  `cult.log`, the full stop) as before; `prepLog`, `theName()`/`TheName()`/`AName()` stay for them
  (English only, game code doesn't use them). So a translated log line must never start
  lowercase; `translate.py` rejects one whose English starts with a capital.

## Saved text

A save holds English keys, never composed or translated text, so it loads in any language:

- Names and notes that are static: `N('…')`, translated where shown (`Loc.tr`).
- Text with values in it is built AT DISPLAY from a template: `Ordeal.getNote()` (the base is
  `Loc.tr(note)`; `BaseDefense`, `TeamBaseDefense`, `RecruitFollower` override it), and timeline notes
  through `Timeline.noteText(event, i)`, which takes the note template from the scenario flow, fills
  `%names%` and then `{variables}` from the timeline variables (a select on one replaces the old
  on-the-fly text). The saved `EventNote.text` is only a fallback for a note the scenario lacks; it
  keeps 1.0.x saves loading unchanged.
- Known limits, by design: the log history (`Game.messageList`) stays in the language it was logged
  in; a save slot's preview line (`_SaveMeta.area`) in the language it was saved in; generated place
  names (NameConst patterns) and person names are proper names, never translated; the alien ship
  part names stay English inside their alien-script font.

## Nouns

A placeholder value that is an entity (`getLocNoun(): _LocNoun`) or a `_LocNoun` is a noun:
`{key, kind, gender}`. Entities with `getLocNoun()`: `AIData` ("your host" for the player's host,
the real name when known, else the unknown noun; `n` for animals), `Attacker`, `AttackTarget`
(`TARGET_PLAYER` = "you"), `_Item`, `AreaObject` (base organs: Latin names, no article), `Cult` (the
styled name). `ai.getJobLocNoun()` is the job with the AI's gender. With only an English key at hand
(an `ItemInfo.name`): `Loc.thing(key)`. Any form can be capitalised, the bare one too (`{x:Bare}`). `kind` is `LOC_NOUN` (common noun, gets articles), `LOC_NAME` (proper name,
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
| `loc/nouns-<code>.json` | the noun table (gender, feminine form, aspirated h), generated by `translate.py nouns`, reviewed by hand |

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

## Mods

- A mod calls `l10n.Loc` (curated extern `parasite-mod-sdk/externs/l10n/Loc.hx`: `lang`, `tr`, `fmt`,
  `colored`, `thing`) — the `T`/`N` macros don't exist at runtime. Its `lang/<code>.json` (same
  format as ours, `strings` + `nouns`) is merged by `ModLoader.loadLang` before the entry runs.
  SDK page: `parasite-mod-sdk/docs/12-localization.md`; example: `examples/testmod/lang/fr.json`.
- `extract.py --root <moddir>` lists a mod's `Loc.tr('…')` literals (printed, nothing written).
- An untranslated template in another language (a mod with no lang file, a string newer than the
  table) renders as plain English, nouns included: `{x:the}` is a form no translation uses, so it
  marks the template as English. `translate.py` rejects a translation that keeps `{x:the}`/`{x:The}`.
- 1.0 mod API kept working: bare-predicate logs (see above) and weapons with only `verb1`/`verb2`
  (`CommonLogic.legacyWeaponText` builds English templates from them once).

## Fonts

- `tools/loc/fonts.py` (run by every `translate.py build`) checks each font offered in Options
  (`Config.fonts`/`fontsTitle`) against the characters the translation actually uses (markup stripped;
  a character used fewer than 3 times doesn't disqualify a font) with `fc-query`, and writes the
  allowed lists into the lang file as `fonts`/`fontsTitle`. `--report` lists what each rejected font
  lacks. Measured: Dusty, DemunLotion, FlipsideBrk have no accents at all; Eurocorp and Xball no `œ`.
- Options offers only the allowed fonts. `Loc.shownFont` replaces a saved font the language can't
  render with the language default for the session; the saved choice is kept and returns in English.
  The default is the lang file's `font`/`fontTitle`, else Virtucorp/Cruiser2015.
- `--text-font`/`--text-font-title` always end in `, Orkney-Regular` (every European Latin letter), so
  a missing glyph falls back to a font in the game's style instead of a system font.
- Alien speech (`Lang.renderText`) scrambles every letter of a cased script, accents included.
- For later languages: full Europe incl. Greek/Cyrillic is only Xolonium; all European Latin is
  Orkney. CJK needs bundled fonts (`@font-face` + `unicode-range` in `electron/fonts.css`, the lang
  file's `font`/`fontTitle` pointing at them), a per-language minimum size, `letter-spacing: 0` (app.css
  has ~160 letter-spacing rules), `font-synthesis: none`, and `word-break: keep-all` for Korean.

## Checks

- `cd src && make` runs `loc-test` (`src/l10n/LocTest.hx` under node: formatter, plural, select,
  English/French forms, pseudo), then `extract.py --check`. The check prints
  `loc: N strings (+a -b since last build) · fr: x new (y changed), z removed`. That line is the
  notification that a string changed and needs translating.
- `make steam-upload` runs `extract.py --strict`: it fails, naming up to 30 untranslated strings per
  language, unless `allow-stale=1`.
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
| `make loc [lang=fr] [jobs=4]` | everything pending (new, failed, or missing pass 2), then the noun table, then build |
| `python3 tools/loc/translate.py nouns --lang fr` | adds every missing noun key to `loc/nouns-<lang>.json` (gender, feminine form, aspirated h; prompt `loc/nouns.md`), passing the interface translation of the key so both agree. The file is the runtime noun table: review it by hand |
| `make loc-build [lang=fr]` | `electron/lang/<lang>.json` from the state (+ `loc/nouns-<lang>.json`); French typography (non-breaking spaces, ’) is applied here, not trusted to the model |
| `python3 tools/loc/translate.py status --lang fr` | counts per status |
| `python3 tools/loc/translate.py store --lang fr` | the Steam store page: `loc/store/en.txt` (short + long description in Steamworks BBCode, taken from the public store page) → `loc/store/<lang>.txt`, marketing register, BBCode tags and the 300-character short limit checked; paste it into Steamworks by hand |
| `python3 tools/loc/translate.py review --lang fr` | `loc/review/<lang>.tsv` for a human reader: id, context, English, translation, the model's doubt, an empty `fix` column; doubts first. UTF-8 with BOM (Excel) |
| `python3 tools/loc/translate.py apply-review --lang fr [--sheet path]` | imports every non-empty `fix` that passes the same checks as a model translation, marks it `reviewed` (no re-run touches it until the English changes), then builds; rejects are listed with the reason |

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

