# Localization

The game ships in several languages. The English text is the key: a translation table maps each
English string to its translation, and anything without a translation shows in English. A mod
takes part through the same table.

## Translating a mod's text

Call `l10n.Loc` (the curated extern `externs/l10n/Loc.hx`):

```haxe
import l10n.Loc;

// a fixed string
name = Loc.tr('Hello from testmod');
// a sentence with values: one template, values in {placeholders}
game.log(Loc.fmt(Loc.tr('{ai:The} rips {n, plural, one{# wire} other{# wires}} out.'), {
  ai: ai,
  n: wires,
}));
```

- **One template per sentence.** Never glue pieces (`'You open the ' + name`): a translator cannot
  reorder them. Values go in placeholders.
- `{x}` is a value; `{x:The}` / `{x:the}` / `{x:A}` / `{x:a}` render an entity (an AI, an item, an
  object) with its article in the active language; `Loc.thing(key)` makes a noun from an English
  item/object name. `{n, plural, one{…} other{…}}` picks by number (`#` is the number);
  `{x, select, m{he} f{she} other{it}}` picks by an entity's gender.
- Item and object names you set (`name = 'chainsaw'`) stay English in memory and in saves; the game
  translates them where it shows them. Translate everything else where you create it, with `Loc.tr`.
- `ai.log(s)` / `cult.log(s)` log `s` as is. A 1.0-style bare predicate (`host.log('lights the
  cigar.')`, starting lowercase) still gets the subject put in front, in English only.
- Weapons: `WeaponInfo.textMiss` / `textMissYou` / `textHit` / `textHitYou` (and `textStun` for stun
  weapons) are whole-sentence templates with `{attacker}`, `{target}`, `{damage}` / `{rounds}` (see
  `examples/chainsaw`). The "You" variants are for when the parasite itself is the target. 1.0
  weapons that set only `verb1`/`verb2` keep working, in English.

## Shipping translations: `lang/<code>.json`

Put one file per language in the mod folder:

```
mymod/
  manifest.json
  entry.js
  lang/
    fr.json
```

```json
{
  "strings": {
    "Hello from testmod": "Bonjour de testmod",
    "{ai:The} rips {n, plural, one{# wire} other{# wires}} out.": "{ai:Def} arrache {n, plural, one{# fil} other{# fils}}.",
    "chainsaw": "tronçonneuse"
  },
  "nouns": {
    "chainsaw": { "g": "f", "s": "tronçonneuse" }
  }
}
```

- `strings`: English → translation. A translation keeps every `{placeholder}` name, html tag and
  `%token%` of the English.
- `nouns`: what the game needs to put an article on your item/object names: `g` (gender `m`/`f`),
  `s` (the noun without article), optional `fs` (a feminine form for a person), `elide: false` (an
  aspirated h). French forms are `def`/`indef`/`de`/`a` (le/un/du/au), capitalized at a sentence
  start: `{x:Def}`.
- The file is merged into the game's table before your entry runs, so `Loc.tr` in `init()` already
  sees it. Nothing is loaded in English. A missing file or string falls back to English.
- Language codes: `en`, `fr`, … (`Loc.lang()` tells the active one).
