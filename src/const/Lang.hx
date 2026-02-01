// language data and utilities
package const;

import game.Game;

typedef _LangRange = {
  var start: Int;
  var end: Int;
};

typedef _LangInfo = {
  var key: String;
  var name: String;
  var ranges: Array<_LangRange>;
  var font: String;
};

class Lang
{
  var game: Game;
  var langsByID: Map<String, _LangInfo>;
  var langIDs: Array<String>;
  var fontsReady: Map<String, Bool>;
  var fontsLoading: Map<String, Bool>;

// sets up language helper with game reference
  public function new(g: Game)
    {
      game = g;
      langsByID = new Map<String, _LangInfo>();
      langIDs = [];
      fontsReady = new Map<String, Bool>();
      fontsLoading = new Map<String, Bool>();
      initLangTable();
    }

// builds lookup table for language infos
  function initLangTable()
    {
// language definitions
      var infos: Array<_LangInfo> = [
        {
          key: 'phoenician',
          name: 'Phoenician',
          ranges: [ { start: 0x10900, end: 0x1091B } ],
          font: 'Noto Sans Phoenician',
        },
        {
          key: 'egyptianHieroglyphs',
          name: 'Egyptian Hieroglyphs',
          ranges: [ { start: 0x13000, end: 0x1342E } ],
          font: 'Noto Sans Egyptian Hieroglyphs',
        },
        {
          key: 'cuneiform',
          name: 'Cuneiform',
          ranges: [ { start: 0x12000, end: 0x12399 } ],
          font: 'Noto Sans Cuneiform',
        },
        {
          key: 'ugaritic',
          name: 'Ugaritic',
          ranges: [ { start: 0x10380, end: 0x1039D } ],
          font: 'Noto Sans Ugaritic',
        },
        {
          key: 'linearB',
          name: 'Linear B',
          ranges: [ { start: 0x10000, end: 0x1005D } ],
          font: 'Noto Sans Linear B',
        },
        {
          key: 'phaistosDisc',
          name: 'Phaistos Disc',
          ranges: [ { start: 0x101D0, end: 0x101FC } ],
          font: 'Noto Sans Symbols 2',
        },
        {
          key: 'chorasmian',
          name: 'Chorasmian',
          ranges: [ { start: 0x10FB0, end: 0x10FCB } ],
          font: 'Noto Sans Chorasmian',
        },
        {
          key: 'oldPersian',
          name: 'Old Persian',
          ranges: [ { start: 0x103A0, end: 0x103CF } ],
          font: 'Noto Sans Old Persian',
        },
        {
          key: 'anatolianHieroglyphs',
          name: 'Anatolian Hieroglyphs',
          ranges: [ { start: 0x14400, end: 0x14646 } ],
          font: 'Noto Sans Anatolian Hieroglyphs',
        },
        {
          key: 'glagolitic',
          name: 'Glagolitic',
          ranges: [ { start: 0x2C00, end: 0x2C5F } ],
          font: 'Noto Sans Glagolitic',
        },
        {
          key: 'cyproMinoan',
          name: 'Cypro-Minoan',
          ranges: [ { start: 0x12F90, end: 0x12FF0 } ],
          font: 'Noto Sans Cypro Minoan',
        },
        {
          key: 'linearA',
          name: 'Linear A',
          ranges: [ { start: 0x10600, end: 0x10767 } ],
          font: 'Noto Sans Linear A',
        },
      ];

// register language infos
      for (info in infos)
        {
          langsByID.set(info.key, info);
          langIDs.push(info.key);
        }
    }

// gets language info by key
  public function getInfo(lang: String): _LangInfo
    {
      if (lang == null ||
          lang == '')
        return null;
      return langsByID.get(lang);
    }

// picks a random language id
  public function getRandomID(): String
    {
      if (langIDs.length == 0)
        return '';
      return langIDs[Std.random(langIDs.length)];
    }

// gets font family for a language
  public function getFont(lang: String): String
    {
      var info = getInfo(lang);
      if (info == null)
        return null;
      return info.font;
    }

// ensures a language font is loaded before use
  public function ensureFontLoaded(lang: String, ?size: Int = 14): Bool
    {
#if js
      var font = getFont(lang);
      if (font == null ||
          font == '')
        return true;
      if (fontsReady.get(font) == true)
        return true;

// check for a loaded font face first
      var fontSpec = size + 'px "' + font + '"';
      try
        {
          if (js.Browser.document.fonts.check(fontSpec))
            {
              fontsReady.set(font, true);
              return true;
            }
        }
      catch (e: Dynamic)
        {
          return false;
        }

// start async load if not already in progress
      if (fontsLoading.get(font) == true)
        return false;
      fontsLoading.set(font, true);
      js.Browser.document.fonts.load(fontSpec).then(function(_)
        {
          fontsReady.set(font, true);
          fontsLoading.remove(font);
        }, function(_)
        {
          fontsLoading.remove(font);
        });
      return false;
#else
      return true;
#end
    }

// renders text with random glyphs from a language
  public function renderText(s: String, lang: String): String
    {
      if (s == null ||
          s == '')
        return s;
      var info = getInfo(lang);
      if (info == null ||
          info.ranges == null ||
          info.ranges.length == 0)
        return s;

// replace only basic latin letters
      var buf = new StringBuf();
      for (i in 0...s.length)
        {
          var code = s.charCodeAt(i);
          if ((code >= 65 &&
               code <= 90) ||
              (code >= 97 &&
               code <= 122))
            buf.add(getRandomGlyph(info));
          else
            buf.add(s.charAt(i));
        }
      return buf.toString();
    }

// picks a random glyph from a language range
  function getRandomGlyph(info: _LangInfo): String
    {
      var range = info.ranges[Std.random(info.ranges.length)];
      var code = range.start + Std.random(range.end - range.start + 1);
      return fromCodePoint(code);
    }

// converts a unicode code point to a string
  function fromCodePoint(code: Int): String
    {
      if (code <= 0xFFFF)
        return String.fromCharCode(code);
      var v = code - 0x10000;
      var hi = 0xD800 + (v >> 10);
      var lo = 0xDC00 + (v & 0x3FF);
      return String.fromCharCode(hi) + String.fromCharCode(lo);
    }
}
