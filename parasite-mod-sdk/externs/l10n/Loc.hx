// the engine's localization: translate a mod's player-facing text through the active language
// table, and fill placeholders. hand-curated: the engine's T()/N() markers are compile-time macros
// of the game build and do not exist at runtime, so a mod calls tr()/fmt() directly. a mod ships its
// translations as lang/<code>.json (see docs/12-localization.md), merged before its entry runs
package l10n;

@:native('window.parasiteHx["l10n.Loc"]')
extern class Loc
{
  // the active language code: 'en', 'fr', ..., or 'pseudo' (the debug pseudo-language)
  public static function lang(): String;
  // translate one English string; returns it unchanged in English or when no translation exists
  public static function tr(s: String): String;
  // fill the {placeholders} of an already translated template from an anonymous object:
  // Loc.fmt(Loc.tr('{ai:The} rips {n} wires.'), { ai: ai, n: 3 })
  public static function fmt(s: String, args: Dynamic): String;
  // wrap one fmt argument in a text color span (css var --text-color-<col>), article included
  public static function colored(col: String, value: Dynamic): Dynamic;
  // a common noun from its English key (an item or object name) for a {x:form} placeholder
  public static function thing(key: String): Dynamic;
}
