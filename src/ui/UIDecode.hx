// text "decode" effect: text resolves out of random glyph noise
// (shared by the main menu and future windows)

package ui;

import js.Browser;
import js.html.Element;

class UIDecode
{
  static var GLYPHS = '▒░#@%&╪◊$';

// animate an element's text resolving out of glyph noise over ~0.56s.
// finalText is the plain text; if html is given it is set as innerHTML on finish.
  public static function decodeTo(el: Element, finalText: String, ?html: String)
    {
      // restart cleanly if this element is already decoding
      if (untyped el._iv != null)
        Browser.window.clearInterval(untyped el._iv);
      var frame = 0;
      var total = 14;
      var iv = Browser.window.setInterval(function() {
        frame++;
        var out = '';
        for (i in 0...finalText.length)
          out += (i < (frame / total) * finalText.length ?
            finalText.charAt(i) :
            GLYPHS.charAt(Std.random(GLYPHS.length)));
        el.textContent = out;
        if (frame >= total)
          {
            Browser.window.clearInterval(untyped el._iv);
            untyped el._iv = null;
            if (html != null)
              el.innerHTML = html;
            else el.textContent = finalText;
          }
      }, 40);
      untyped el._iv = iv;
    }

// one random glyph (used by the title per-letter corruption)
  public static function randomGlyph(): String
    {
      return GLYPHS.charAt(Std.random(GLYPHS.length));
    }
}
