// localization: the language table, the T()/N() string markers and the placeholder formatter.
// the rules (which marker where, placeholder syntax, nouns) live in docs/localization.md
package l10n;

import haxe.macro.Expr;
import _LocBoot;

class Loc
{
#if !macro
  // NOTE: none of these statics has an initialiser, on purpose. the const tables call tr() during
  // static init, which can run before this class's own static init — an initialiser would then
  // wipe the table that first tr() call just loaded
  static var code: String; // active language: 'en', 'fr', ..., or 'pseudo'
  static var available: Array<String>; // codes with a lang file, 'en' first
  static var table: Map<String, String>; // English source -> translation
  static var nouns: Map<String, _LocNounEntry>; // English noun key -> grammar entry
  static var file: _LocFile; // the parsed lang file (font lists etc.), null for en/pseudo
  static var missing: Map<String, Int>; // tr() keys with no translation, with hit counts
  static var pluralRules: js.lib.intl.PluralRules; // plural categories of the active language

  // native names for the language select
  public static var NAMES = [
    'en' => 'English',
    'fr' => 'Français',
    'de' => 'Deutsch',
    'es' => 'Español',
    'it' => 'Italiano',
    'pl' => 'Polski',
    'pt-BR' => 'Português (Brasil)',
    'ru' => 'Русский',
    'uk' => 'Українська',
    'tr' => 'Türkçe',
    'zh-CN' => '简体中文',
    'zh-TW' => '繁體中文',
    'ja' => '日本語',
    'ko' => '한국어',
    'pseudo' => 'Pseudo',
  ];

// active language code
  public static function lang(): String
    {
      if (table == null)
        load();
      return code;
    }

// language codes that have a lang file, 'en' first
  public static function languages(): Array<String>
    {
      if (table == null)
        load();
      return available;
    }

// translate one English source string; the identity in English
  public static function tr(s: String): String
    {
      if (table == null)
        load();
      if (s == null ||
          s == '' ||
          code == 'en')
        return s;
      if (code == 'pseudo')
        return pseudo(s);
      var t = table.get(s);
      if (t != null)
        return t;
      missing.set(s, (missing.exists(s) ? missing.get(s) : 0) + 1);
      return s;
    }

// fill the placeholders of an already translated template from args
  public static function fmt(s: String, args: Dynamic): String
    {
      // args is the anonymous object a T() call site builds, so its values are heterogeneous by
      // design (strings, numbers, entities); the T macro already checked its field names
      if (s == null ||
          s.indexOf('{') < 0)
        return s;
      // a lang file is external data: a broken template shows as is instead of throwing
      try {
        return render(parse(s), args, null);
      }
      catch (e: Dynamic)
        {
          return s;
        }
    }

// a common noun from its English key (an N() item, object or creature name) for a {x:form} placeholder,
// where no entity with getLocNoun() is at hand
  public static function thing(key: String): _LocNoun
    {
      return {
        key: key,
        kind: LOC_NOUN,
        gender: 'n',
      };
    }

// wrap an fmt argument in a text color span (the whole noun phrase, article included)
  public static function colored(col: String, value: Dynamic): LocColored
    {
      // value is any fmt argument: string, number or entity
      return new LocColored(col, value);
    }

// the fonts the active language can render, for the Options lists (null: every font, as in English)
  public static function fonts(title: Bool): Array<String>
    {
      if (table == null)
        load();
      if (file == null)
        return null;
      return (title ? file.fontsTitle : file.fonts);
    }

// the font shown for a chosen one: the choice when the language can render it, else the language's
// default (the lang file's font/fontTitle, else the game's)
  public static function shownFont(chosen: String, title: Bool): String
    {
      var list = fonts(title);
      if (list == null ||
          list.indexOf(chosen) >= 0)
        return chosen;
      var def = (file == null ? null : (title ? file.fontTitle : file.font));
      return (def != null ? def : (title ? 'Cruiser2015' : 'Virtucorp'));
    }

// merge a mod's lang file into the active table (mods/<id>/lang/<code>.json)
  public static function merge(json: String)
    {
      if (table == null)
        load();
      addFile(parseFile(json));
    }

// strings that reached tr() without a translation, most frequent first ('noun: ' = noun table)
  public static function missingList(): Array<String>
    {
      if (table == null)
        load();
      var keys = [for (k in missing.keys()) k];
      keys.sort(function(a, b) return missing.get(b) - missing.get(a));
      return [for (k in keys) missing.get(k) + '× ' + k];
    }

// set the active language from a lang file; load() calls it, and LocTest
  public static function init(langCode: String, json: String)
    {
      code = langCode;
      table = new Map();
      nouns = new Map();
      missing = new Map();
      pluralRules = null;
      file = null;
      if (json != null)
        {
          file = parseFile(json);
          addFile(file);
        }
    }

// reload the game into the language just saved in the config
  public static function reload()
    {
#if electron
      HostBridge.reload();
#else
      js.Browser.window.location.reload();
#end
    }

// ask the main process which language is active and fetch its table
  static function load()
    {
      var boot: _LocBoot = null;
#if electron
      // gen runs headless under node with no window and no host bridge: it stays English
      if (js.Syntax.code("typeof window != 'undefined' && window.host != null"))
        boot = HostBridge.langRead();
#end
      init((boot != null ? boot.code : 'en'), (boot != null ? boot.json : null));
      available = (boot != null ? boot.available : [ 'en' ]);
      // quotes, hyphenation and fallback glyph choice follow the document language
      if (js.Syntax.code("typeof document != 'undefined'"))
        js.Browser.document.documentElement.lang = (code == 'pseudo' ? 'en' : code);
    }

// parse a lang file
  static function parseFile(json: String): _LocFile
    {
      // lang files are external data (generated, or shipped by a mod): JSON.parse is the boundary
      return haxe.Json.parse(json);
    }

// add a parsed lang file's strings and nouns to the table
  static function addFile(f: _LocFile)
    {
      if (f.strings != null)
        for (k in f.strings.keys())
          table.set(k, f.strings.get(k));
      if (f.nouns != null)
        for (k in f.nouns.keys())
          nouns.set(k, f.nouns.get(k));
    }

// render parsed segments with args; num replaces # inside a plural case body
  static function render(segs: Array<LocSeg>, args: Dynamic, num: Null<Float>): String
    {
      var buf = new StringBuf();
      for (seg in segs)
        switch (seg)
          {
            case SEG_TEXT(s):
              buf.add(num != null ? StringTools.replace(s, '#', '' + num) : s);
            case SEG_VAR(name, form):
              buf.add(value(Reflect.field(args, name), form));
            case SEG_CHOICE(name, type, cases):
              var v: Dynamic = Reflect.field(args, name);
              var isPlural = (type == 'plural');
              var body = pick(cases, (isPlural ? pluralKey(v) : selectKey(v)), (isPlural ? '=' + v : null));
              buf.add(render(body, args, (isPlural ? v : num)));
          }
      return buf.toString();
    }

// pick a choice case: exact '=N' first, then the key, then 'other'
  static function pick(cases: Array<LocCase>, key: String, exact: String): Array<LocSeg>
    {
      var other: Array<LocSeg> = [];
      var keyed: Array<LocSeg> = null;
      for (c in cases)
        {
          if (exact != null &&
              c.key == exact)
            return c.segs;
          if (c.key == key)
            keyed = c.segs;
          else if (c.key == 'other')
            other = c.segs;
        }
      return (keyed != null ? keyed : other);
    }

// plural category of a number in the active language
  static function pluralKey(v: Float): String
    {
      if (pluralRules == null)
        pluralRules = new js.lib.intl.PluralRules(code == 'pseudo' ? 'en' : code);
      // the extern types the argument Int; Intl takes any number (1.5 is 'other' in English)
      return '' + pluralRules.select(cast v);
    }

// select key: a noun's grammatical gender, else the value itself
  static function selectKey(v: Dynamic): String
    {
      var n = noun(v);
      if (n != null)
        return genderOf(n);
      return (v != null ? '' + v : 'other');
    }

// render one argument
  static function value(v: Dynamic, form: String): String
    {
      if (Std.isOfType(v, LocColored))
        {
          var c: LocColored = v;
          return "<span style='color:var(--text-color-" + c.col + ")'>" + value(c.value, form) + '</span>';
        }
      var n = noun(v);
      if (n != null)
        return nounForm(n, form);
      return '' + v;
    }

// the noun behind an argument: an entity with getLocNoun(), a _LocNoun, or null
  static function noun(v: Dynamic): _LocNoun
    {
      if (v == null ||
          Std.isOfType(v, String) ||
          Std.isOfType(v, Float))
        return null;
      if (Reflect.isFunction(Reflect.field(v, 'getLocNoun')))
        return v.getLocNoun();
      if (Reflect.hasField(v, 'kind') &&
          Reflect.hasField(v, 'key'))
        return v;
      return null;
    }

// a noun in the requested form; a capitalised form name capitalises the result
  static function nounForm(n: _LocNoun, form: String): String
    {
      var f = form.toLowerCase();
      var s = switch (code)
        {
          case 'en', 'pseudo': english(n, f);
          case 'fr': french(n, f);
          default: generic(n, f);
        };
      // capitalise the first letter (in pseudo, the one after the ⟦ mark)
      var i = (StringTools.startsWith(s, '⟦') ? 1 : 0);
      if (form != f &&
          s.length > i)
        s = s.substr(0, i) + s.charAt(i).toUpperCase() + s.substr(i + 1);
      return s;
    }

// English forms: the, a (a/an), bare
  static function english(n: _LocNoun, f: String): String
    {
      var w = (n.kind == LOC_NAME ? n.key : tr(n.key));
      if (n.kind != LOC_NOUN)
        return w;
      return switch (f)
        {
          case 'the': 'the ' + w;
          case 'a': ('aeiou'.indexOf(n.key.charAt(0)) >= 0 ? 'an ' : 'a ') + w;
          default: w;
        };
    }

// French forms: def (le/la/l’), indef (un/une), de (du/de la/de l’), a (au/à la/à l’), bare
  static function french(n: _LocNoun, f: String): String
    {
      // names and phrases take no article, only the de/à prepositions
      if (n.kind != LOC_NOUN)
        {
          var w = (n.kind == LOC_NAME ? n.key : tr(n.key));
          return switch (f)
            {
              case 'de': (elides(w) ? 'd’' : 'de ') + w;
              case 'a': 'à ' + w;
              default: w;
            };
        }
      var e = entry(n);
      if (e.forms != null &&
          e.forms.exists(f))
        return e.forms.get(f);
      var fem = (n.gender == 'f' &&
        e.fs != null);
      var w = (fem ? e.fs : e.s);
      var g = (fem ? 'f' : e.g);
      var el = (e.elide != null ? e.elide : elides(w));
      return switch (f)
        {
          case 'def': (el ? 'l’' : (g == 'f' ? 'la ' : 'le ')) + w;
          case 'indef': (g == 'f' ? 'une ' : 'un ') + w;
          case 'de': (el ? 'de l’' : (g == 'f' ? 'de la ' : 'du ')) + w;
          case 'a': (el ? 'à l’' : (g == 'f' ? 'à la ' : 'au ')) + w;
          default: w;
        };
    }

// languages without a rule yet: explicit forms from the noun table, else the bare noun
  static function generic(n: _LocNoun, f: String): String
    {
      if (n.kind == LOC_NAME)
        return n.key;
      if (n.kind == LOC_PHRASE)
        return tr(n.key);
      var e = entry(n);
      if (e.forms != null &&
          e.forms.exists(f))
        return e.forms.get(f);
      return ((n.gender == 'f' && e.fs != null) ? e.fs : e.s);
    }

// grammatical gender for select: the noun table's in a gendered language, else the natural one
  static function genderOf(n: _LocNoun): String
    {
      if (n.kind != LOC_NOUN ||
          code == 'en' ||
          code == 'pseudo')
        return n.gender;
      var e = entry(n);
      return ((n.gender == 'f' && e.fs != null) ? 'f' : e.g);
    }

// noun table entry; a missing one is recorded and stands in as a bare masculine translation
  static function entry(n: _LocNoun): _LocNounEntry
    {
      var e = nouns.get(n.key);
      if (e != null)
        return e;
      var k = 'noun: ' + n.key;
      missing.set(k, (missing.exists(k) ? missing.get(k) : 0) + 1);
      return {
        g: 'm',
        s: tr(n.key),
      };
    }

// French elision before a vowel or a mute h (a leading tag, as in a styled cult name, is skipped)
  static function elides(w: String): Bool
    {
      if (StringTools.startsWith(w, '<') &&
          w.indexOf('>') > 0)
        w = w.substr(w.indexOf('>') + 1);
      return ('aàâäeéèêëiîïoôöuùûüœæhAÀÂÄEÉÈÊËIÎÏOÔÖUÙÛÜŒÆH'.indexOf(w.charAt(0)) >= 0);
    }

// pseudo-localize a template: accented letters, 30% longer, ⟦⟧ marks; syntax, tags kept intact
  static function pseudo(s: String): String
    {
      var segs = try parse(s) catch (e: Dynamic) [ SEG_TEXT(s) ];
      var body = unparse(pseudoSegs(segs));
      var pad = new StringBuf();
      for (i in 0...Math.ceil(s.length * 0.3))
        pad.add('~');
      return '⟦' + body + pad.toString() + '⟧';
    }

// pseudo-localize the text segments of a parsed template
  static function pseudoSegs(segs: Array<LocSeg>): Array<LocSeg>
    {
      return [for (seg in segs)
        switch (seg)
          {
            case SEG_TEXT(s): SEG_TEXT(pseudoText(s));
            case SEG_VAR(_, _): seg;
            case SEG_CHOICE(name, type, cases): SEG_CHOICE(name, type,
              [for (c in cases) { key: c.key, segs: pseudoSegs(c.segs) }]);
          }];
    }

// accent the letters of plain text, skipping html tags, entities and %tokens%
  static function pseudoText(s: String): String
    {
      var from = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
      var to = 'àƀçðéƒĝĥîĵķļɱñöþǫŕšţûṽŵẋýžÀƁÇÐÉƑĜĤÎĴĶĻṀÑÖÞǪŔŠŢÛṼŴẊÝŽ';
      var buf = new StringBuf();
      var i = 0;
      while (i < s.length)
        {
          var c = s.charAt(i);
          var close = (c == '<' ? '>' : (c == '&' ? ';' : (c == '%' ? '%' : null)));
          var end = (close != null ? s.indexOf(close, i + 1) : -1);
          // keep a tag, an entity (&rarr;) or a %token% whole
          if (end > i &&
              (c == '<' || end - i < 12))
            {
              buf.add(s.substring(i, end + 1));
              i = end + 1;
              continue;
            }
          var k = from.indexOf(c);
          buf.add(k >= 0 ? to.charAt(k) : c);
          i++;
        }
      return buf.toString();
    }

// segments back to template text
  static function unparse(segs: Array<LocSeg>): String
    {
      var buf = new StringBuf();
      for (seg in segs)
        switch (seg)
          {
            case SEG_TEXT(s):
              buf.add(s);
            case SEG_VAR(name, form):
              buf.add('{' + name + (form != '' ? ':' + form : '') + '}');
            case SEG_CHOICE(name, type, cases):
              buf.add('{' + name + ', ' + type + ',');
              for (c in cases)
                buf.add(' ' + c.key + '{' + unparse(c.segs) + '}');
              buf.add('}');
          }
      return buf.toString();
    }
#end

// parse a template into segments (shared by fmt, pseudo and the T macro's compile-time check)
  public static function parse(s: String): Array<LocSeg>
    {
      return new LocParser(s).segs(false);
    }

// every placeholder name a template uses, choice bodies included
  public static function names(s: String): Array<String>
    {
      var out = [];
      collect(parse(s), out);
      return out;
    }

// gather placeholder names from segments
  static function collect(segs: Array<LocSeg>, out: Array<String>)
    {
      for (seg in segs)
        switch (seg)
          {
            case SEG_TEXT(_):
            case SEG_VAR(name, _):
              if (out.indexOf(name) < 0)
                out.push(name);
            case SEG_CHOICE(name, _, cases):
              if (out.indexOf(name) < 0)
                out.push(name);
              for (c in cases)
                collect(c.segs, out);
          }
    }

// T('literal' [, args]): translate a string literal now; with args also fill its placeholders.
// tools/loc/extract.py collects the literal, so anything but a constant string is a compile error
  public static macro function T(s: ExprOf<String>, ?args: Expr): ExprOf<String>
    {
      var str = literal(s);
      var used = syntax(str, s.pos);
      if (isNull(args))
        return macro l10n.Loc.tr($v{str});
      switch (args.expr)
        {
          case EObjectDecl(fields):
            var have = [for (f in fields) f.field];
            for (n in used)
              if (have.indexOf(n) < 0)
                haxe.macro.Context.error('T(): {' + n + '} has no field in the args object', args.pos);
            for (h in have)
              if (used.indexOf(h) < 0)
                haxe.macro.Context.error('T(): args field ' + h + ' is not used by the template', args.pos);
          default:
        }
      return macro l10n.Loc.fmt(l10n.Loc.tr($v{str}), $args);
    }

// N('literal'): mark a string for extraction only. it stays English in memory and in saves and is
// translated where it is displayed, with Loc.tr(value) — the marker for saved or compared text
  public static macro function N(s: ExprOf<String>): ExprOf<String>
    {
      var str = literal(s);
      syntax(str, s.pos);
      return macro $v{str};
    }

#if macro
// the constant string behind a T()/N() argument ('a' + 'b' folds); compile error otherwise
  static function literal(e: Expr): String
    {
      switch (e.expr)
        {
          case EConst(CString(s, kind)):
            if (kind == SingleQuotes)
              {
                // a single-quoted '$x' would interpolate; placeholders are written {x}
                var i = 0;
                while (i < s.length)
                  {
                    if (s.charAt(i) == '$')
                      {
                        var next = s.charAt(i + 1);
                        if (next == '{' ||
                            next == '_' ||
                            next.toLowerCase() != next.toUpperCase())
                          haxe.macro.Context.error('T()/N(): no $ interpolation, use a {placeholder}', e.pos);
                        if (next == '$')
                          i++;
                      }
                    i++;
                  }
                s = StringTools.replace(s, '$$', '$');
              }
            return s;
          case EBinop(OpAdd, a, b):
            return literal(a) + literal(b);
          case EParenthesis(inner):
            return literal(inner);
          default:
            haxe.macro.Context.error('T()/N() take a string literal (tools/loc/extract.py reads it), not an expression', e.pos);
            return null;
        }
    }

// placeholder names of a literal; bad placeholder syntax is a compile error
  static function syntax(s: String, pos: Position): Array<String>
    {
      try {
        return names(s);
      }
      catch (err: Dynamic)
        {
          haxe.macro.Context.error('T()/N(): bad placeholder syntax: ' + err, pos);
          return null;
        }
    }

// an omitted optional macro argument arrives as the constant null
  static function isNull(e: Expr): Bool
    {
      return switch (e)
        {
          case null: true;
          case { expr: EConst(CIdent('null')) }: true;
          default: false;
        };
    }
#end
}

// one parsed piece of a template
enum LocSeg
{
  SEG_TEXT(s: String);                                           // literal text
  SEG_VAR(name: String, form: String);                           // {name} or {name:form}
  SEG_CHOICE(name: String, type: String, cases: Array<LocCase>); // {name, plural|select, key{…} …}
}

// one case of a plural/select placeholder
typedef LocCase = {
  var key: String;          // plural category, '=N' exact number or select key
  var segs: Array<LocSeg>;  // the case body
}

// an fmt argument wrapped in a text color span
class LocColored
{
  public var col: String;    // css variable suffix: --text-color-<col>
  public var value: Dynamic; // any fmt argument (string, number or entity), heterogeneous by design

  public function new(col: String, value: Dynamic)
    {
      this.col = col;
      this.value = value;
    }
}

// recursive-descent reader for the placeholder syntax; throws on a malformed template
class LocParser
{
  var s: String;
  var pos: Int;

  public function new(s: String)
    {
      this.s = s;
      pos = 0;
    }

// read segments up to the end, or up to the closing brace of a choice body when nested
  public function segs(nested: Bool): Array<LocSeg>
    {
      var out = [];
      var buf = new StringBuf();
      while (pos < s.length)
        {
          var c = s.charAt(pos);
          if (c == '}' &&
              nested)
            break;
          if (c != '{')
            {
              buf.add(c);
              pos++;
              continue;
            }
          if (buf.length > 0)
            {
              out.push(SEG_TEXT(buf.toString()));
              buf = new StringBuf();
            }
          pos++;
          out.push(placeholder());
        }
      if (nested &&
          pos >= s.length)
        throw 'unclosed choice body';
      if (buf.length > 0)
        out.push(SEG_TEXT(buf.toString()));
      return out;
    }

// read one placeholder, just past its opening brace
  function placeholder(): LocSeg
    {
      var name = until(':,}');
      var c = s.charAt(pos++);
      if (c == '}')
        return SEG_VAR(name, '');
      if (c == ':')
        {
          var form = until('}');
          pos++;
          return SEG_VAR(name, form);
        }
      var type = until(',');
      pos++;
      if (type != 'plural' &&
          type != 'select')
        throw 'unknown choice type "' + type + '"';
      var cases = [];
      while (true)
        {
          while (s.charAt(pos) == ' ')
            pos++;
          if (pos >= s.length)
            throw 'unclosed choice';
          if (s.charAt(pos) == '}')
            {
              pos++;
              break;
            }
          var key = until('{');
          pos++;
          var body = segs(true);
          pos++;
          cases.push({
            key: key,
            segs: body,
          });
        }
      return SEG_CHOICE(name, type, cases);
    }

// read up to one of the stop chars (not consumed), trimmed; the end of the string is an error
  function until(stops: String): String
    {
      var start = pos;
      while (pos < s.length &&
          stops.indexOf(s.charAt(pos)) < 0)
        {
          if (s.charAt(pos) == '{')
            throw 'stray { in a placeholder';
          pos++;
        }
      if (pos >= s.length)
        throw 'unclosed placeholder';
      var t = StringTools.trim(s.substring(start, pos));
      if (t == '')
        throw 'empty placeholder part';
      return t;
    }
}
