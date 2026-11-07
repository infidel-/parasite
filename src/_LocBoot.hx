// language data handed to the renderer by the main process (host:lang), and the lang file it carries

// host:lang reply
typedef _LocBoot = {
  var code: String;              // active language code ('en', 'fr', 'pseudo')
  var available: Array<String>;  // codes with a lang file, 'en' first
  var json: String;              // raw electron/lang/<code>.json text, null for en/pseudo
}

// one electron/lang/<code>.json (written by tools/loc/translate.py build)
typedef _LocFile = {
  var strings: haxe.DynamicAccess<String>;          // English source -> translation
  @:optional var nouns: haxe.DynamicAccess<_LocNounEntry>; // English noun key -> grammar entry
  @:optional var fonts: Array<String>;              // text fonts that cover this language
  @:optional var fontsTitle: Array<String>;         // title fonts that cover this language
  @:optional var font: String;                      // default text font override
  @:optional var fontTitle: String;                 // default title font override
}

// grammar entry of one common noun in a language noun table
typedef _LocNounEntry = {
  var g: String;                                    // grammatical gender: 'm', 'f' (or German 'n')
  var s: String;                                    // the translated noun, bare
  @:optional var fs: String;                        // feminine variant for female entities (policière)
  @:optional var elide: Bool;                       // article elision override (French aspirated h)
  @:optional var acc: String;                       // German accusative when it differs (Polizisten)
  @:optional var dat: String;                       // German dative when it differs (Polizisten)
  @:optional var gen: String;                       // German genitive when not s + -s/-es (Polizisten)
  @:optional var forms: haxe.DynamicAccess<String>; // explicit forms that beat the language rule
}
