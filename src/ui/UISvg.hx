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
      return '<svg class="mainmenu-corner ' + pos + '" viewBox="0 0 34 34" fill="none">' +
        '<path d="M2 14 V2 H14"/></svg>';
    }

// all four corner brackets
  public static function corners(): String
    {
      return corner('tl') + corner('tr') + corner('bl') + corner('br');
    }

// detailed document glyph, ghosted behind the log scrim
  public static function doc(): String
    {
      return '<svg class="hud-glyph" viewBox="0 0 96 120" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '<path d="M14 8 H66 L82 24 V112 H14 Z"/>' +              // sheet body
        '<path d="M66 8 V24 H82"/>' +                            // dog-ear fold
        '<line x1="22" y1="14" x2="22" y2="106" opacity=".45"/>' + // margin rule
        '<line x1="28" y1="22" x2="58" y2="22" stroke-width="2.6"/>' + // title
        '<line x1="28" y1="30" x2="74" y2="30"/>' +              // paragraph cluster
        '<line x1="28" y1="42" x2="74" y2="42"/>' +
        '<line x1="28" y1="49" x2="68" y2="49"/>' +
        '<line x1="28" y1="56" x2="74" y2="56"/>' +
        '<line x1="28" y1="63" x2="52" y2="63"/>' +
        '<circle cx="30" cy="75" r="1.6" fill="currentColor" stroke="none"/>' + // bullets
        '<line x1="36" y1="75" x2="70" y2="75"/>' +
        '<circle cx="30" cy="83" r="1.6" fill="currentColor" stroke="none"/>' +
        '<line x1="36" y1="83" x2="64" y2="83"/>' +
        '<circle cx="34" cy="99" r="8"/><circle cx="34" cy="99" r="4.5" opacity=".6"/>' + // double-ring seal
        '<path d="M50 102 C55 95 58 106 63 99 C66 94 70 101 74 97"/>' + // signature squiggle
        '</svg>';
    }

// parasite veins creeping in from the frame's top-right and bottom-left corners
// (full-frame SVG, stretched to fit; squigglier than the stage set)
  public static function veins(): String
    {
      return '<svg class="hud-veins" viewBox="0 0 1830 990" preserveAspectRatio="none" aria-hidden="true">' +
        '<g stroke="#a45fe0" fill="none" stroke-linecap="round" opacity=".1">' +
        // top-right growth
        '<path stroke-width="4" d="M1842 72 C1806 46 1788 100 1752 78 C1716 56 1700 112 1664 92 C1628 72 1614 126 1578 106 C1542 86 1530 138 1494 122"/>' +
        '<path stroke-width="2.5" d="M1664 92 C1672 60 1640 44 1652 12 C1658 -6 1644 -2 1648 -4"/>' +
        '<path stroke-width="2" d="M1578 106 C1564 146 1598 168 1584 208 C1572 244 1602 262 1590 300"/>' +
        '<path stroke-width="2.5" d="M1790 60 C1798 92 1772 108 1782 142 C1790 168 1766 182 1774 210"/>' +
        '<path stroke-width="1.4" d="M1494 122 C1462 136 1452 110 1420 124 C1396 134 1388 114 1364 124"/>' +
        '<circle cx="1648" cy="-4" r="3.5" fill="#a45fe0" stroke="none"/>' +
        '<circle cx="1590" cy="300" r="3" fill="#a45fe0" stroke="none"/>' +
        '<circle cx="1774" cy="210" r="2.5" fill="#a45fe0" stroke="none"/>' +
        '<circle cx="1364" cy="124" r="3" fill="#a45fe0" stroke="none"/>' +
        // bottom-left growth
        '<path stroke-width="4" d="M-12 912 C24 938 42 884 78 906 C114 928 130 872 166 894 C202 916 216 862 252 884 C288 906 300 854 336 872"/>' +
        '<path stroke-width="2.5" d="M166 894 C158 932 190 948 182 986 C178 1006 186 1002 184 1002"/>' +
        '<path stroke-width="2" d="M252 884 C262 844 230 826 242 788 C252 756 222 740 232 704"/>' +
        '<path stroke-width="2.5" d="M48 930 C56 958 34 972 44 1000"/>' +
        '<path stroke-width="1.4" d="M336 872 C368 860 378 886 410 876 C434 868 442 888 466 880"/>' +
        '<circle cx="232" cy="704" r="3.5" fill="#a45fe0" stroke="none"/>' +
        '<circle cx="184" cy="1002" r="3" fill="#a45fe0" stroke="none"/>' +
        '<circle cx="44" cy="1000" r="2.5" fill="#a45fe0" stroke="none"/>' +
        '<circle cx="466" cy="880" r="3" fill="#a45fe0" stroke="none"/>' +
        '</g></svg>';
    }

// target/reticle glyph, ghosted behind the goals scrim
  public static function reticle(): String
    {
      return '<svg class="hud-glyph" viewBox="0 0 96 96" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" aria-hidden="true">' +
        '<circle cx="48" cy="48" r="38"/>' +
        '<circle cx="48" cy="48" r="24" stroke-dasharray="5 7" opacity=".7"/>' +
        '<circle cx="48" cy="48" r="10"/>' +
        '<circle cx="48" cy="48" r="3" fill="currentColor" stroke="none"/>' +
        '<line x1="48" y1="2" x2="48" y2="16"/><line x1="48" y1="80" x2="48" y2="94"/>' +
        '<line x1="2" y1="48" x2="16" y2="48"/><line x1="80" y1="48" x2="94" y2="48"/>' +
        '<line x1="48" y1="34" x2="48" y2="38" opacity=".7"/><line x1="48" y1="58" x2="48" y2="62" opacity=".7"/>' +
        '<line x1="34" y1="48" x2="38" y2="48" opacity=".7"/><line x1="58" y1="48" x2="62" y2="48" opacity=".7"/>' +
        '</svg>';
    }

// clock glyph, ghosted behind the timeline scrim
  public static function clock(): String
    {
      return '<svg class="hud-glyph" viewBox="0 0 96 96" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '<circle cx="48" cy="48" r="40"/>' +
        '<circle cx="48" cy="48" r="3.2" fill="currentColor" stroke="none"/>' +
        '<line x1="48" y1="48" x2="48" y2="22"/>' +
        '<line x1="48" y1="48" x2="66" y2="56"/>' +
        '<line x1="48" y1="9" x2="48" y2="15"/><line x1="48" y1="81" x2="48" y2="87"/>' +
        '<line x1="9" y1="48" x2="15" y2="48"/><line x1="81" y1="48" x2="87" y2="48"/>' +
        '</svg>';
    }

// DNA double-helix glyph, ghosted behind the evolution scrim
  public static function helix(): String
    {
      return '<svg class="hud-glyph" viewBox="0 0 96 120" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '<path d="M30 8 C30 30 66 38 66 60 C66 82 30 90 30 112"/>' +
        '<path d="M66 8 C66 30 30 38 30 60 C30 82 66 90 66 112"/>' +
        '<line x1="34" y1="20" x2="62" y2="20"/>' +
        '<line x1="40" y1="32" x2="56" y2="32"/>' +
        '<line x1="40" y1="88" x2="56" y2="88"/>' +
        '<line x1="34" y1="100" x2="62" y2="100"/>' +
        '</svg>';
    }

// lightning-bolt glyph (energy stat chip)
  public static function bolt(): String
    {
      return '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M13 2 4 14h6l-1 8 9-12h-6l1-8z"/></svg>';
    }

// four-point star glyph (evolution points); cls sets the svg class
  public static function star(?cls: String = ''): String
    {
      return '<svg class="' + cls + '" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 2l2 8 8 2-8 2-2 8-2-8-8-2 8-2 2-8z"/></svg>';
    }

// small clock glyph (time / turns); cls sets the svg class
  public static function clockSmall(?cls: String = ''): String
    {
      return '<svg class="' + cls + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/></svg>';
    }

// face/person icon for participant ID tags
  public static function face(): String
    {
      return '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">' +
        '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7z"/></svg>';
    }

// rotating organism sigil (inner group .mainmenu-sigil-in counter-spins)
  public static function sigil(): String
    {
      return '<svg class="mainmenu-sigil" viewBox="0 0 200 200" fill="none" stroke="currentColor" stroke-width="1" aria-hidden="true">' +
        '<circle cx="100" cy="100" r="92" stroke-dasharray="2 6" opacity=".7"/>' +
        '<circle cx="100" cy="100" r="74"/>' +
        '<g class="mainmenu-sigil-in">' +
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
