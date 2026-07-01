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

// floppy-disk glyph (saves left); cls sets the svg class
  public static function floppy(?cls: String = ''): String
    {
      return '<svg class="' + cls + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 3h11l3 3v13a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z"/><path d="M7 3v5h7V3"/><rect x="7" y="13" width="10" height="6" rx="1"/></svg>';
    }

// small clock glyph (time / turns); cls sets the svg class
  public static function clockSmall(?cls: String = ''): String
    {
      return '<svg class="' + cls + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/></svg>';
    }

// turn-count pill: number + small clock glyph (evolution / organ growth eta)
  public static function turnPill(n: Int): String
    {
      return '<span class="hud-turn-pill">' + n + clockSmall() + '</span>';
    }

// small cell glyph (growing body feature / organ): membrane ring + nucleus + organelle
  public static function featOrgan(): String
    {
      return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true">' +
        '<circle cx="12" cy="12" r="9"/>' +
        '<circle cx="12" cy="12" r="3.4" fill="currentColor" stroke="none"/>' +
        '<circle cx="17" cy="8" r="1.4" fill="currentColor" stroke="none"/></svg>';
    }

// compact-toggle glyph: thick double chevron pointing left (collapse the panel)
  public static function hudCompact(): String
    {
      return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '<path d="M13 5l-6 7 6 7"/>' +
        '<path d="M19 5l-6 7 6 7"/></svg>';
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

// filled attribute-tile glyph: clenched fist (strength)
  public static function attrStr(): String
    {
      return '<svg class="body-atile-ico" viewBox="202 129 850 850" fill="currentColor">' +
        '<path d="M 379.0 405.0 L 369.0 413.0 L 353.0 431.0 L 344.0 445.0 L 334.0 466.0 L 323.0 498.0 L 316.0 527.0 L 313.0 547.0 L 313.0 574.0 L 318.0 596.0 L 326.0 614.0 L 335.0 629.0 L 386.0 695.0 L 461.0 786.0 L 473.0 801.0 L 477.0 805.5 L 479.0 820.0 L 478.0 820.5 L 477.0 841.0 L 476.0 841.5 L 475.0 859.0 L 474.0 859.5 L 472.0 885.5 L 471.0 886.0 L 469.0 912.0 L 468.0 912.5 L 468.0 922.0 L 466.0 931.5 L 466.0 943.0 L 468.0 945.0 L 475.0 947.0 L 838.0 947.0 L 842.0 946.0 L 846.0 943.0 L 846.0 930.5 L 845.0 930.0 L 845.0 921.0 L 844.0 920.5 L 838.0 856.5 L 837.0 856.0 L 837.0 846.5 L 835.0 837.5 L 834.0 809.5 L 835.0 806.5 L 840.0 800.5 L 875.0 755.0 L 895.0 723.0 L 910.0 692.0 L 922.0 658.0 L 931.0 619.0 L 936.0 583.0 L 938.0 538.0 L 939.0 537.0 L 939.0 494.0 L 924.0 506.0 L 913.0 512.0 L 893.0 518.0 L 884.0 519.0 L 864.0 518.0 L 839.0 510.0 L 823.0 499.0 L 812.0 487.0 L 807.0 479.0 L 795.0 493.0 L 779.0 505.0 L 769.0 510.0 L 747.0 516.0 L 723.0 516.0 L 709.0 513.0 L 691.0 505.0 L 679.0 497.0 L 672.0 510.0 L 663.0 522.0 L 643.0 540.0 L 620.0 553.0 L 610.0 557.0 L 590.0 562.0 L 591.0 564.0 L 609.0 573.0 L 629.0 587.0 L 648.0 607.0 L 657.0 621.0 L 664.0 639.0 L 668.0 664.0 L 668.0 674.0 L 666.0 675.0 L 651.0 647.0 L 641.0 632.0 L 623.0 612.0 L 609.0 601.0 L 595.0 592.0 L 566.0 578.0 L 470.0 544.0 L 472.0 533.0 L 475.0 530.0 L 542.0 542.0 L 569.0 543.0 L 586.0 541.0 L 602.0 537.0 L 629.0 524.0 L 649.0 506.0 L 659.0 491.0 L 664.0 478.0 L 665.0 456.0 L 659.0 442.0 L 651.0 432.0 L 643.0 426.0 L 631.0 420.0 L 621.0 417.0 L 453.0 389.0 L 422.0 389.0 L 411.0 391.0 L 396.0 396.0 Z"/>' +
        '<path d="M 727.0 194.0 L 710.0 198.0 L 693.0 207.0 L 680.0 220.0 L 670.0 240.0 L 668.0 252.0 L 670.0 422.0 L 677.0 431.0 L 682.0 441.0 L 686.0 457.0 L 686.0 476.0 L 701.0 488.0 L 715.0 494.0 L 724.0 496.0 L 747.0 496.0 L 764.0 491.0 L 781.0 480.0 L 794.0 464.0 L 800.0 449.0 L 801.0 396.0 L 802.0 395.0 L 803.0 252.0 L 800.0 236.0 L 792.0 221.0 L 782.0 210.0 L 770.0 202.0 L 758.0 197.0 L 743.0 194.0 Z"/>' +
        '<path d="M 559.0 165.0 L 548.0 170.0 L 533.0 182.0 L 525.0 193.0 L 518.0 211.0 L 517.0 243.0 L 518.0 244.0 L 519.0 378.0 L 625.0 396.0 L 643.0 402.0 L 651.0 407.0 L 652.0 406.0 L 653.0 281.0 L 654.0 280.0 L 654.0 215.0 L 651.0 202.0 L 642.0 186.0 L 631.0 175.0 L 616.0 166.0 L 596.0 161.0 L 575.0 161.0 Z"/>' +
        '<path d="M 876.0 262.0 L 857.0 265.0 L 841.0 272.0 L 826.0 285.0 L 818.0 299.0 L 816.0 306.0 L 817.0 454.0 L 820.0 464.0 L 825.0 474.0 L 837.0 487.0 L 853.0 496.0 L 863.0 499.0 L 888.0 500.0 L 905.0 496.0 L 922.0 486.0 L 935.0 471.0 L 941.0 456.0 L 942.0 450.0 L 942.0 307.0 L 936.0 291.0 L 931.0 284.0 L 921.0 275.0 L 911.0 269.0 L 900.0 265.0 Z"/>' +
        '<path d="M 477.0 232.0 L 456.0 222.0 L 439.0 219.0 L 425.0 219.0 L 409.0 222.0 L 393.0 229.0 L 382.0 237.0 L 374.0 246.0 L 366.0 261.0 L 363.0 277.0 L 364.0 363.0 L 365.0 364.0 L 365.0 388.0 L 366.0 389.0 L 384.0 378.0 L 401.0 372.0 L 421.0 368.0 L 444.0 367.0 L 464.0 369.0 L 496.0 375.0 L 500.0 374.0 L 501.0 270.0 L 499.0 261.0 L 495.0 252.0 L 488.0 242.0 Z"/></svg>';
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

// energy-bolt glyph (action cost; fill set in css)
  public static function hudEnergy(): String
    {
      return '<svg class="hud-energy" viewBox="0 0 24 24" aria-hidden="true"><path d="M14 2 5 13.5h5.5L9 22l10-13h-6.5z"/></svg>';
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

// host-status badge: interlocking rings (affinity / symbiosis bond)
  public static function badgeAffinity(): String
    {
      return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">' +
        '<circle cx="9" cy="12" r="5.4"/><circle cx="15" cy="12" r="5.4"/>' +
        '<circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none"/></svg>';
    }

// host-status badge: open mouth (consent, freely given) — based on 👄
// lip ring with the cavity cut as an evenodd void = open mouth interior
  public static function badgeConsent(): String
    {
      return '<svg viewBox="60 313 720 423" fill="currentColor" fill-rule="evenodd" aria-hidden="true">' +
        '<path d="M70 503C150 450 205 345 295 331 345 323 386 355 419 355 452 355 493 323 543 331 633 345 688 450 768 503 720 574 661 673 548 704 468 726 368 726 290 704 177 673 118 574 70 503Z' + // lips (outer)
        'M112 515C226 496 309 460 367 460 406 460 433 470 461 470 488 470 514 460 553 460 611 460 694 496 726 515 608 540 522 568 461 568 399 568 314 540 112 515Z"/></svg>'; // parted seam (void, widened)
    }

// host-status badge: hooded figure (cultist / cult allegiance)
// pointed cowl over robe shoulders; face cut as an evenodd void = shadowed face
  public static function badgeCultist(): String
    {
      return '<svg viewBox="0 0 24 24" fill="currentColor" fill-rule="evenodd" aria-hidden="true">' +
        '<path d="M12 1.5C14.8 2.3 17.5 5 17.5 8.6 17.5 10.2 16.8 11.6 15.6 12.6 18.2 13.8 20.6 16.8 20.6 20.5L20.6 21.8 3.4 21.8 3.4 20.5C3.4 16.8 5.8 13.8 8.4 12.6 7.2 11.6 6.5 10.2 6.5 8.6 6.5 5 9.2 2.3 12 1.5Z' + // hood + robe silhouette
        'M12 6.6C9.8 6.6 8.6 8.4 8.6 10.4 8.6 12.4 10 13.8 12 13.8 14 13.8 15.4 12.4 15.4 10.4 15.4 8.4 14.2 6.6 12 6.6Z"/></svg>'; // shadowed face void
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
