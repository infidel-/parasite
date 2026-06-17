// inline SVG markup for UI chrome
// kept inline (not <img>/background) so currentColor recolor and CSS
// animations can reach the individual nodes (e.g. counter-spinning groups,
// stroke-dashoffset draw-in). Centralized here so window classes stay clean.

package ui;

class UISvg
{
// one HUD corner bracket; pos is the placement class (tl/tr/bl/br)
  public static function corner(pos: String): String
    {
      return '<svg class="mm-corner ' + pos + '" viewBox="0 0 34 34" fill="none">' +
        '<path d="M2 14 V2 H14"/></svg>';
    }

// all four corner brackets
  public static function corners(): String
    {
      return corner('tl') + corner('tr') + corner('bl') + corner('br');
    }

// rotating organism sigil (inner group .mm-sigil-in counter-spins)
  public static function sigil(): String
    {
      return '<svg class="mm-sigil" viewBox="0 0 200 200" fill="none" stroke="currentColor" stroke-width="1" aria-hidden="true">' +
        '<circle cx="100" cy="100" r="92" stroke-dasharray="2 6" opacity=".7"/>' +
        '<circle cx="100" cy="100" r="74"/>' +
        '<g class="mm-sigil-in">' +
        '<circle cx="100" cy="100" r="54" stroke-dasharray="10 8"/>' +
        '<circle cx="100" cy="100" r="30"/>' +
        '<circle cx="100" cy="100" r="4" fill="currentColor" stroke="none"/>' +
        '<line x1="100" y1="46" x2="100" y2="8"/><line x1="100" y1="154" x2="100" y2="192"/>' +
        '<line x1="46" y1="100" x2="8" y2="100"/><line x1="154" y1="100" x2="192" y2="100"/>' +
        '<circle cx="100" cy="30" r="3" fill="currentColor" stroke="none"/>' +
        '<circle cx="170" cy="100" r="3" fill="currentColor" stroke="none"/>' +
        '<circle cx="100" cy="170" r="3" fill="currentColor" stroke="none"/>' +
        '<circle cx="30" cy="100" r="3" fill="currentColor" stroke="none"/>' +
        '</g></svg>';
    }
}
