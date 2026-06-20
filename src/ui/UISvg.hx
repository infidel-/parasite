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

// faint parasite veins for the live HUD; creep in from top-left and
// bottom-right corners (opacity .07, with nodule circles)
  public static function hudVeins(): String
    {
      return '<svg id="hud-veins" viewBox="0 0 1920 1080" preserveAspectRatio="none" aria-hidden="true">' +
        '<g stroke="#a45fe0" fill="none" stroke-linecap="round" opacity=".07">' +
        // top-left growth
        '<path stroke-width="4" d="M-12 64 C90 84 150 70 218 132 S330 232 398 246"/>' +
        '<path stroke-width="2.5" d="M150 86 C190 40 260 52 312 30"/>' +
        '<path stroke-width="2" d="M218 132 C246 196 222 260 258 318"/>' +
        '<path stroke-width="1.4" d="M398 246 C448 258 480 296 492 332"/>' +
        '<path stroke-width="2.5" d="M86 -10 C96 60 70 110 96 168"/>' +
        '<circle cx="312" cy="30" r="3.5" fill="#a45fe0" stroke="none"/>' +
        '<circle cx="258" cy="318" r="3" fill="#a45fe0" stroke="none"/>' +
        '<circle cx="492" cy="332" r="2.5" fill="#a45fe0" stroke="none"/>' +
        '<circle cx="96" cy="168" r="3" fill="#a45fe0" stroke="none"/>' +
        // bottom-right growth
        '<path stroke-width="4" d="M1932 1006 C1800 988 1740 1014 1668 950 S1556 854 1488 838"/>' +
        '<path stroke-width="2.5" d="M1770 1000 C1730 1046 1660 1036 1608 1058"/>' +
        '<path stroke-width="2" d="M1668 950 C1640 886 1664 822 1628 764"/>' +
        '<path stroke-width="2.5" d="M1834 1092 C1824 1010 1850 962 1824 904"/>' +
        '<circle cx="1628" cy="764" r="3.5" fill="#a45fe0" stroke="none"/>' +
        '<circle cx="1488" cy="838" r="3" fill="#a45fe0" stroke="none"/>' +
        '<circle cx="1824" cy="904" r="2.5" fill="#a45fe0" stroke="none"/>' +
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

// giant cell glyph, ghosted behind the body scrim (membrane + nucleus + organelles)
  public static function cell(): String
    {
      return '<svg class="hud-glyph" viewBox="0 0 96 96" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '<path d="M48 6 C70 6 90 26 90 48 C90 70 70 90 48 90 C26 90 6 70 6 48 C6 26 26 6 48 6Z" stroke-dasharray="3 6" opacity=".6"/>' + // outer membrane
        '<path d="M48 13 C66 13 83 30 83 48 C83 66 66 83 48 83 C30 83 13 66 13 48 C13 30 30 13 48 13Z"/>' + // inner membrane
        '<circle cx="44" cy="46" r="15"/>' +                                  // nucleus ring
        '<circle cx="44" cy="46" r="5" fill="currentColor" stroke="none" opacity=".8"/>' + // nucleus dot
        '<circle cx="70" cy="34" r="6"/>' +                                   // organelles
        '<circle cx="68" cy="64" r="4.5"/>' +
        '<ellipse cx="30" cy="70" rx="7" ry="4" transform="rotate(-28 30 70)"/>' +
        '<circle cx="26" cy="30" r="3.5"/>' +
        '</svg>';
    }

// duotone inventory-item glyph (generic 3D box; real per-item art slot later)
  public static function bodyItem(): String
    {
      return '<svg class="body-bdi" viewBox="0 0 24 24">' +
        '<path class="ln" d="M3 7l9-4 9 4v10l-9 4-9-4z"/>' +
        '<path class="ln" d="M3 7l9 4 9-4M12 11v10"/>' +
        '<circle class="ac" cx="12" cy="11" r="1.6"/></svg>';
    }

// duotone skill glyph (generic pulse waveform; skills/knowledges are data-driven)
  public static function bodySkill(): String
    {
      return '<svg class="body-bdi" viewBox="0 0 24 24">' +
        '<path class="ln" d="M3 12h4l2-5 3 10 2-5h7"/>' +
        '<circle class="ac" cx="9" cy="7" r="1.6"/></svg>';
    }

// duotone person glyph (host job line)
  public static function bodyJob(): String
    {
      return '<svg class="body-bdi" viewBox="0 0 24 24">' +
        '<circle class="ln" cx="12" cy="8" r="4"/>' +
        '<path class="ln" d="M5 20a7 7 0 0 1 14 0"/>' +
        '<circle class="ac" cx="12" cy="8" r="1.7"/></svg>';
    }

// duotone house glyph (habitats-left line, smaller)
  public static function bodyHabitat(): String
    {
      return '<svg class="body-bdi body-sm" viewBox="0 0 24 24">' +
        '<path class="ln" d="M4 11l8-6 8 6"/>' +
        '<path class="ln" d="M6 10v9h12v-9"/>' +
        '<rect class="ac" x="10" y="13" width="4" height="6"/></svg>';
    }

// duotone merge-rings glyph (host traits; data-driven, one generic shape)
  public static function bodyTrait(): String
    {
      return '<svg class="body-bdi body-tr-ico" viewBox="0 0 24 24">' +
        '<circle class="ln" cx="9" cy="12" r="4.5"/>' +
        '<circle class="ln" cx="15" cy="12" r="4.5"/>' +
        '<circle class="ac" cx="12" cy="12" r="1.8"/></svg>';
    }

// duotone spark glyph (host effects; data-driven, one generic shape)
  public static function bodyEffect(): String
    {
      return '<svg class="body-bdi" viewBox="0 0 24 24">' +
        '<path class="ln" d="M13 2 4 14h6l-1 8 9-12h-6z"/>' +
        '<circle class="ac" cx="11" cy="12" r="1.6"/></svg>';
    }

// filled attribute-tile glyph: fist (strength)
  public static function attrStr(): String
    {
      return '<svg class="body-atile-ico" viewBox="0 0 24 24" fill="currentColor">' +
        '<circle cx="8.4" cy="9.3" r="1.5"/><circle cx="11.2" cy="8.5" r="1.6"/>' +
        '<circle cx="14" cy="8.5" r="1.6"/><circle cx="16.6" cy="9.3" r="1.5"/>' +
        '<path d="M6.5 11h11v3.3a4 4 0 0 1-4 4h-3a4 4 0 0 1-4-4z"/>' +
        '<path d="M6.5 12.2c-1.4 0-2.3.8-2.3 1.9s.9 1.9 2.3 1.9z"/></svg>';
    }

// filled attribute-tile glyph: shield (constitution)
  public static function attrCon(): String
    {
      return '<svg class="body-atile-ico" viewBox="0 0 24 24" fill="currentColor">' +
        '<path d="M12 2l8 3v6c0 5-3.4 8.2-8 9.5C7.4 19.2 4 16 4 11V5z"/></svg>';
    }

// filled attribute-tile glyph: lightbulb (intellect)
  public static function attrInt(): String
    {
      return '<svg class="body-atile-ico" viewBox="0 0 24 24" fill="currentColor">' +
        '<path d="M12 2a7 7 0 0 0-4 12.8V16h8v-1.2A7 7 0 0 0 12 2zM8.5 17.5h7V19h-7zM9.5 20.5h5V21a1 1 0 0 1-1 1h-3a1 1 0 0 1-1-1z"/></svg>';
    }

// filled attribute-tile glyph: eye (psyche)
  public static function attrPsy(): String
    {
      return '<svg class="body-atile-ico" viewBox="0 0 24 24" fill="currentColor">' +
        '<path fill-rule="evenodd" d="M12 5C6 5 2 12 2 12s4 7 10 7 10-7 10-7-4-7-10-7zm0 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8z" clip-rule="evenodd"/>' +
        '<circle cx="12" cy="12" r="2"/></svg>';
    }

// pentagram glyph, ghosted behind the cult scrim (circle + inscribed star)
  public static function pentagram(): String
    {
      return '<svg class="hud-glyph" viewBox="0 0 96 96" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '<circle cx="48" cy="48" r="40"/>' +
        '<polygon points="48,12 67.02,70.54 17.21,34.36 78.79,34.36 28.98,70.54"/>' +
        '</svg>';
    }

// two-person glyph (cult members stat chip)
  public static function cultMembers(): String
    {
      return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '<circle cx="9" cy="8" r="3.2"/><path d="M3.5 19c0-3 2.5-5 5.5-5s5.5 2 5.5 5"/>' +
        '<path d="M16 5.2a3.2 3.2 0 0 1 0 5.6"/><path d="M17.5 14.2c2.2.5 3.9 2.4 3.9 4.8"/></svg>';
    }

// map-pin glyph (topbar location)
  public static function hudPin(): String
    {
      return '<svg viewBox="0 0 24 24" fill="currentColor" fill-rule="evenodd" aria-hidden="true">' +
        '<path d="M12 22c5-6 7-9.5 7-13a7 7 0 1 0-14 0c0 3.5 2 7 7 13zM14.6 9a2.6 2.6 0 1 1-5.2 0 2.6 2.6 0 0 1 5.2 0z"/></svg>';
    }

// settings-cog glyph (topbar gear)
  public static function hudGear(): String
    {
      return '<svg viewBox="0 0 24 24" fill="currentColor" fill-rule="evenodd" aria-hidden="true">' +
        '<path d="M19.4 13a7.6 7.6 0 0 0 0-2l2-1.6-2-3.4-2.4 1a7.6 7.6 0 0 0-1.7-1l-.4-2.6h-3.8l-.4 2.6a7.6 7.6 0 0 0-1.7 1l-2.4-1-2 3.4 2 1.6a7.6 7.6 0 0 0 0 2l-2 1.6 2 3.4 2.4-1a7.6 7.6 0 0 0 1.7 1l.4 2.6h3.8l.4-2.6a7.6 7.6 0 0 0 1.7-1l2.4 1 2-3.4-2-1.6zM12 15.5a3.5 3.5 0 1 1 0-7 3.5 3.5 0 0 1 0 7z"/></svg>';
    }

// eye glyph (parasite health bar)
  public static function hudEye(): String
    {
      return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z"/>' +
        '<circle cx="12" cy="12" r="4.2" fill="currentColor" stroke="none"/></svg>';
    }

// lightning glyph (energy bars)
  public static function hudBolt(): String
    {
      return '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M13 2 4 14h6l-1 8 9-12h-6z"/></svg>';
    }

// heart glyph (host health bar)
  public static function hudHeart(): String
    {
      return '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 20.3 3.6 11.9a4.9 4.9 0 0 1 6.9-6.9l1.5 1.5 1.5-1.5a4.9 4.9 0 0 1 6.9 6.9z"/></svg>';
    }

// bust glyph (host control / grip bar)
  public static function hudControl(): String
    {
      return '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><circle cx="12" cy="7" r="3.4"/><path d="M5 21c0-3.9 3.1-7 7-7s7 3.1 7 7z"/></svg>';
    }

// energy-coin glyph (action cost; fill set in css)
  public static function hudCoin(): String
    {
      return '<svg class="hud-coin" viewBox="0 0 24 24" aria-hidden="true"><path d="M14 2 5 13.5h5.5L9 22l10-13h-6.5z"/></svg>';
    }

// objective diamond mark; primary carries the sweeping glint sliver
  public static function hudDiamond(?primary: Bool = false): String
    {
      var cls = (primary ? 'hud-mark primary' : 'hud-mark other');
      var glint = (primary ?
        '<clipPath id="hud-dclip"><path d="M12 2 22 12 12 22 2 12z"/></clipPath>' +
        '<g clip-path="url(#hud-dclip)"><rect class="hud-glint" x="0" y="-4" width="5" height="32" fill="#fff" opacity=".9"/></g>' : '');
      return '<svg class="' + cls + '" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">' +
        '<path d="M12 2 22 12 12 22 2 12z"/>' + glint + '</svg>';
    }

// confirm-dialog glyphs (ask + warn); css shows one per danger state
  public static function confirmGlyphs(): String
    {
      return '<svg class="yesno-ico-ask" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '<path d="M9.2 9a2.8 2.8 0 1 1 4 2.5c-.9.5-1.7 1.1-1.7 2.3"/><line x1="11.5" y1="17.5" x2="11.5" y2="17.5"/></svg>' +
        '<svg class="yesno-ico-warn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '<path d="M12 3 22 20H2z"/><line x1="12" y1="10" x2="12" y2="14.5"/><line x1="12" y1="17.5" x2="12" y2="17.5"/></svg>';
    }

// navbar icon: goals reticle
  public static function hudNavGoals(): String
    {
      return '<svg class="hud-nav-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" aria-hidden="true">' +
        '<circle cx="12" cy="12" r="7"/>' +
        '<line x1="12" y1="1.5" x2="12" y2="5"/><line x1="12" y1="19" x2="12" y2="22.5"/>' +
        '<line x1="1.5" y1="12" x2="5" y2="12"/><line x1="19" y1="12" x2="22.5" y2="12"/>' +
        '<circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none"/></svg>';
    }

// navbar icon: body figure
  public static function hudNavBody(): String
    {
      return '<svg class="hud-nav-ico body" viewBox="0 0 24 48" fill="currentColor" aria-hidden="true">' +
        '<circle cx="12" cy="8" r="5.5"/>' +
        '<rect x="8" y="14" width="8" height="16" rx="3.2"/>' +
        '<rect x="4.4" y="15" width="3.2" height="14" rx="1.6"/>' +
        '<rect x="16.4" y="15" width="3.2" height="14" rx="1.6"/>' +
        '<rect x="8" y="29" width="3.6" height="16.5" rx="1.7"/>' +
        '<rect x="12.4" y="29" width="3.6" height="16.5" rx="1.7"/></svg>';
    }

// navbar icon: log document with lines
  public static function hudNavLog(): String
    {
      return '<svg class="hud-nav-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '<rect x="5" y="3" width="14" height="18" rx="1.5"/>' +
        '<line x1="8" y1="8" x2="16" y2="8"/><line x1="8" y1="12" x2="16" y2="12"/><line x1="8" y1="16" x2="13" y2="16"/></svg>';
    }

// navbar icon: timeline clock
  public static function hudNavTimeline(): String
    {
      return '<svg class="hud-nav-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '<circle cx="12" cy="12" r="8.5"/>' +
        '<line x1="12" y1="12" x2="12" y2="7"/><line x1="12" y1="12" x2="15.5" y2="13.5"/></svg>';
    }

// navbar icon: evolution helix
  public static function hudNavEvo(): String
    {
      return '<svg class="hud-nav-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" aria-hidden="true">' +
        '<path d="M7 3c0 5 10 7 10 12 0 4 0 4 0 6"/><path d="M17 3c0 5-10 7-10 12 0 4 0 4 0 6"/>' +
        '<line x1="8.5" y1="6" x2="15.5" y2="6"/><line x1="9.5" y1="9.5" x2="14.5" y2="9.5"/>' +
        '<line x1="9.5" y1="15" x2="14.5" y2="15"/><line x1="8.5" y1="18" x2="15.5" y2="18"/></svg>';
    }

// navbar icon: cult pentagram
  public static function hudNavCult(): String
    {
      return '<svg class="hud-nav-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" aria-hidden="true">' +
        '<circle cx="12" cy="12" r="9.5"/>' +
        '<polygon points="12,2.5 17.59,19.69 2.97,9.06 21.03,9.06 6.41,19.69"/></svg>';
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
