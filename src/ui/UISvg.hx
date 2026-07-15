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

// paralysis: lightning burst (inline SVG effect glyph)
  public static function effectParalysis(): String
    {
      // viewBox trimmed ~15% about centre so the glyph reads larger within its box (baked-in scale)
      return '<svg viewBox="81.8 81.8 1090.4 1090.4" fill="currentColor" fill-rule="evenodd" aria-hidden="true">' +
        '<path d="M 698.0 503.0 L 660.0 542.0 L 627.0 581.0 L 572.0 650.0 L 512.0 729.0 L 513.0 731.0 L 612.0 731.0 L 614.0 733.0 L 580.0 833.0 L 569.0 875.0 L 570.0 880.0 L 578.0 873.0 L 640.0 800.0 L 744.0 669.0 L 743.0 666.0 L 643.0 665.0 L 645.0 656.0 L 680.0 564.0 L 697.0 511.0 Z"/>' +
        '<path d="M 630.0 278.0 L 559.0 426.0 L 554.0 425.0 L 445.0 365.0 L 444.0 366.0 L 465.0 535.0 L 463.0 538.0 L 293.0 531.0 L 293.0 533.0 L 353.0 605.0 L 393.0 656.0 L 278.0 754.0 L 274.0 759.0 L 408.0 788.0 L 415.0 791.0 L 413.0 800.0 L 358.0 945.0 L 360.0 946.0 L 493.0 899.0 L 496.0 904.0 L 503.0 989.0 L 509.0 1039.0 L 627.0 939.0 L 632.0 941.0 L 746.0 1039.0 L 750.0 1012.0 L 760.0 905.0 L 763.0 899.0 L 895.0 946.0 L 897.0 945.0 L 842.0 796.0 L 842.0 791.0 L 849.0 788.0 L 983.0 759.0 L 977.0 752.0 L 866.0 656.0 L 868.0 651.0 L 899.0 611.0 L 964.0 531.0 L 963.0 530.0 L 795.0 538.0 L 793.0 536.0 L 814.0 366.0 L 813.0 365.0 L 708.0 423.0 L 700.0 426.0 L 693.0 414.0 Z M 630.0 377.0 L 681.0 484.0 L 759.0 442.0 L 762.0 443.0 L 755.0 512.0 L 746.0 579.0 L 747.0 582.0 L 847.0 577.0 L 872.0 578.0 L 808.0 661.0 L 887.0 730.0 L 891.0 735.0 L 880.0 739.0 L 789.0 759.0 L 786.0 761.0 L 826.0 869.0 L 827.0 875.0 L 824.0 876.0 L 739.0 846.0 L 726.0 843.0 L 715.0 953.0 L 713.0 955.0 L 629.0 884.0 L 548.0 952.0 L 542.0 955.0 L 535.0 893.0 L 532.0 850.0 L 530.0 842.0 L 433.0 876.0 L 429.0 875.0 L 471.0 761.0 L 468.0 759.0 L 373.0 738.0 L 367.0 735.0 L 375.0 726.0 L 450.0 662.0 L 385.0 578.0 L 408.0 577.0 L 510.0 582.0 L 511.0 576.0 L 506.0 541.0 L 496.0 443.0 L 500.0 442.0 L 577.0 484.0 L 627.0 379.0 Z"/></svg>';
    }

// panic: screaming face (inline SVG effect glyph)
  public static function effectPanic(): String
    {
      return '<svg viewBox="0 0 1254 1254" fill="currentColor" fill-rule="evenodd" aria-hidden="true">' +
        '<path d="M 617.0 162.0 L 570.0 166.0 L 532.0 173.0 L 483.0 187.0 L 443.0 203.0 L 402.0 224.0 L 370.0 245.0 L 333.0 275.0 L 301.0 307.0 L 270.0 345.0 L 244.0 384.0 L 224.0 421.0 L 208.0 459.0 L 196.0 496.0 L 185.0 547.0 L 180.0 592.0 L 180.0 643.0 L 185.0 689.0 L 196.0 739.0 L 208.0 776.0 L 223.0 812.0 L 239.0 843.0 L 265.0 883.0 L 293.0 918.0 L 331.0 956.0 L 368.0 986.0 L 398.0 1006.0 L 449.0 1033.0 L 481.0 1046.0 L 512.0 1056.0 L 569.0 1068.0 L 609.0 1072.0 L 648.0 1072.0 L 683.0 1069.0 L 732.0 1060.0 L 778.0 1046.0 L 810.0 1033.0 L 852.0 1011.0 L 890.0 986.0 L 930.0 953.0 L 954.0 929.0 L 981.0 897.0 L 1003.0 866.0 L 1025.0 828.0 L 1044.0 786.0 L 1060.0 738.0 L 1069.0 698.0 L 1075.0 651.0 L 1076.0 606.0 L 1073.0 563.0 L 1065.0 517.0 L 1056.0 483.0 L 1035.0 427.0 L 1012.0 383.0 L 987.0 345.0 L 965.0 317.0 L 932.0 282.0 L 901.0 255.0 L 869.0 232.0 L 825.0 207.0 L 793.0 193.0 L 748.0 178.0 L 703.0 168.0 L 661.0 163.0 Z M 620.0 206.0 L 669.0 208.0 L 704.0 213.0 L 738.0 221.0 L 769.0 231.0 L 791.0 240.0 L 823.0 256.0 L 843.0 268.0 L 874.0 290.0 L 905.0 317.0 L 934.0 348.0 L 955.0 375.0 L 971.0 399.0 L 991.0 435.0 L 1008.0 475.0 L 1020.0 513.0 L 1028.0 549.0 L 1033.0 591.0 L 1033.0 644.0 L 1030.0 674.0 L 1024.0 707.0 L 1011.0 752.0 L 996.0 789.0 L 978.0 824.0 L 956.0 858.0 L 928.0 893.0 L 893.0 928.0 L 866.0 950.0 L 826.0 976.0 L 797.0 991.0 L 763.0 1005.0 L 728.0 1016.0 L 689.0 1024.0 L 653.0 1028.0 L 604.0 1028.0 L 576.0 1025.0 L 548.0 1020.0 L 496.0 1005.0 L 456.0 988.0 L 428.0 973.0 L 393.0 950.0 L 361.0 924.0 L 328.0 891.0 L 302.0 859.0 L 280.0 826.0 L 259.0 786.0 L 245.0 751.0 L 236.0 722.0 L 226.0 673.0 L 223.0 642.0 L 223.0 595.0 L 227.0 557.0 L 235.0 518.0 L 247.0 479.0 L 262.0 443.0 L 281.0 407.0 L 315.0 358.0 L 336.0 334.0 L 367.0 304.0 L 396.0 281.0 L 428.0 260.0 L 461.0 243.0 L 496.0 229.0 L 537.0 217.0 L 574.0 210.0 Z M 485.0 796.0 L 472.0 821.0 L 463.0 847.0 L 458.0 872.0 L 457.0 901.0 L 461.0 924.0 L 472.0 948.0 L 487.0 964.0 L 501.0 972.0 L 511.0 975.0 L 528.0 976.0 L 551.0 972.0 L 591.0 968.0 L 648.0 967.0 L 696.0 971.0 L 727.0 976.0 L 738.0 976.0 L 752.0 973.0 L 766.0 966.0 L 780.0 953.0 L 790.0 937.0 L 797.0 914.0 L 799.0 888.0 L 795.0 856.0 L 789.0 834.0 L 783.0 819.0 L 772.0 798.0 L 753.0 772.0 L 737.0 756.0 L 723.0 745.0 L 691.0 727.0 L 667.0 719.0 L 641.0 715.0 L 606.0 716.0 L 573.0 724.0 L 547.0 736.0 L 525.0 751.0 L 502.0 773.0 Z M 522.0 942.0 L 525.0 931.0 L 537.0 910.0 L 548.0 898.0 L 567.0 884.0 L 587.0 875.0 L 607.0 870.0 L 643.0 869.0 L 675.0 877.0 L 691.0 885.0 L 708.0 898.0 L 720.0 911.0 L 727.0 922.0 L 734.0 940.0 L 735.0 948.0 L 733.0 950.0 L 727.0 950.0 L 678.0 943.0 L 610.0 941.0 L 568.0 944.0 L 523.0 950.0 Z M 792.0 459.0 L 767.0 463.0 L 739.0 475.0 L 720.0 489.0 L 707.0 503.0 L 695.0 521.0 L 684.0 548.0 L 680.0 569.0 L 680.0 597.0 L 684.0 617.0 L 695.0 644.0 L 707.0 662.0 L 725.0 680.0 L 743.0 692.0 L 768.0 702.0 L 783.0 705.0 L 811.0 705.0 L 838.0 698.0 L 855.0 690.0 L 875.0 675.0 L 891.0 657.0 L 904.0 634.0 L 910.0 617.0 L 914.0 597.0 L 914.0 569.0 L 911.0 552.0 L 903.0 529.0 L 891.0 508.0 L 874.0 489.0 L 855.0 475.0 L 836.0 466.0 L 812.0 460.0 Z M 791.0 485.0 L 804.0 485.0 L 820.0 488.0 L 843.0 498.0 L 853.0 505.0 L 867.0 519.0 L 875.0 530.0 L 883.0 546.0 L 889.0 572.0 L 889.0 592.0 L 885.0 612.0 L 878.0 629.0 L 869.0 643.0 L 856.0 657.0 L 841.0 668.0 L 828.0 674.0 L 809.0 679.0 L 785.0 679.0 L 775.0 677.0 L 755.0 669.0 L 738.0 657.0 L 728.0 647.0 L 718.0 633.0 L 710.0 616.0 L 705.0 595.0 L 705.0 572.0 L 708.0 556.0 L 713.0 542.0 L 724.0 523.0 L 741.0 505.0 L 751.0 498.0 L 774.0 488.0 Z M 788.0 546.0 L 775.0 552.0 L 766.0 561.0 L 761.0 571.0 L 759.0 580.0 L 760.0 593.0 L 767.0 608.0 L 777.0 617.0 L 790.0 622.0 L 804.0 622.0 L 817.0 617.0 L 827.0 608.0 L 834.0 593.0 L 834.0 574.0 L 827.0 560.0 L 814.0 549.0 L 800.0 545.0 Z M 454.0 459.0 L 433.0 462.0 L 413.0 469.0 L 392.0 481.0 L 373.0 498.0 L 361.0 514.0 L 349.0 538.0 L 342.0 565.0 L 341.0 591.0 L 344.0 611.0 L 352.0 635.0 L 365.0 657.0 L 383.0 677.0 L 401.0 690.0 L 423.0 700.0 L 446.0 705.0 L 472.0 705.0 L 488.0 702.0 L 503.0 697.0 L 517.0 690.0 L 535.0 677.0 L 553.0 657.0 L 559.0 648.0 L 571.0 621.0 L 576.0 596.0 L 576.0 569.0 L 572.0 548.0 L 560.0 519.0 L 550.0 504.0 L 535.0 488.0 L 519.0 476.0 L 501.0 467.0 L 480.0 461.0 Z M 445.0 486.0 L 465.0 485.0 L 482.0 488.0 L 500.0 495.0 L 515.0 505.0 L 529.0 519.0 L 538.0 532.0 L 544.0 544.0 L 551.0 571.0 L 551.0 594.0 L 547.0 613.0 L 538.0 633.0 L 532.0 642.0 L 516.0 659.0 L 503.0 668.0 L 488.0 675.0 L 471.0 679.0 L 447.0 679.0 L 437.0 677.0 L 417.0 669.0 L 401.0 658.0 L 390.0 647.0 L 380.0 633.0 L 373.0 619.0 L 367.0 595.0 L 367.0 572.0 L 370.0 556.0 L 375.0 542.0 L 386.0 523.0 L 403.0 505.0 L 413.0 498.0 L 427.0 491.0 Z M 450.0 546.0 L 437.0 552.0 L 427.0 563.0 L 421.0 579.0 L 422.0 593.0 L 429.0 608.0 L 441.0 618.0 L 452.0 622.0 L 466.0 622.0 L 482.0 615.0 L 491.0 605.0 L 495.0 597.0 L 497.0 588.0 L 496.0 574.0 L 490.0 561.0 L 478.0 550.0 L 462.0 545.0 Z M 715.0 334.0 L 711.0 343.0 L 711.0 354.0 L 721.0 374.0 L 744.0 399.0 L 772.0 419.0 L 804.0 434.0 L 828.0 441.0 L 847.0 444.0 L 864.0 444.0 L 874.0 442.0 L 881.0 439.0 L 888.0 431.0 L 888.0 419.0 L 881.0 411.0 L 853.0 407.0 L 829.0 400.0 L 806.0 390.0 L 786.0 378.0 L 774.0 369.0 L 753.0 348.0 L 738.0 330.0 L 727.0 327.0 L 719.0 330.0 Z M 542.0 334.0 L 534.0 328.0 L 523.0 328.0 L 519.0 330.0 L 511.0 338.0 L 502.0 350.0 L 488.0 364.0 L 473.0 376.0 L 452.0 389.0 L 415.0 404.0 L 391.0 409.0 L 382.0 409.0 L 374.0 412.0 L 369.0 417.0 L 367.0 422.0 L 367.0 429.0 L 369.0 433.0 L 375.0 439.0 L 386.0 443.0 L 418.0 443.0 L 437.0 439.0 L 455.0 433.0 L 484.0 419.0 L 511.0 400.0 L 534.0 376.0 L 540.0 367.0 L 546.0 352.0 L 546.0 344.0 Z"/></svg>';
    }

// slime / slow: snail (inline SVG effect glyph)
  public static function effectSlime(): String
    {
      return '<svg viewBox="0 0 1254 1254" fill="currentColor" fill-rule="evenodd" aria-hidden="true">' +
        '<path d="M 1091.0 353.0 L 1081.0 343.0 L 1073.0 339.0 L 1064.0 337.0 L 1048.0 340.0 L 1042.0 343.0 L 1033.0 352.0 L 1029.0 360.0 L 1027.0 369.0 L 1028.0 380.0 L 1030.0 385.0 L 1030.0 394.0 L 1007.0 436.0 L 968.0 518.0 L 959.0 525.0 L 938.0 525.0 L 933.0 521.0 L 930.0 513.0 L 922.0 466.0 L 909.0 404.0 L 909.0 399.0 L 916.0 389.0 L 921.0 377.0 L 920.0 358.0 L 916.0 350.0 L 911.0 344.0 L 902.0 338.0 L 892.0 335.0 L 883.0 335.0 L 875.0 337.0 L 867.0 341.0 L 858.0 350.0 L 853.0 362.0 L 852.0 368.0 L 853.0 378.0 L 860.0 392.0 L 865.0 397.0 L 876.0 404.0 L 880.0 413.0 L 895.0 502.0 L 899.0 533.0 L 898.0 540.0 L 894.0 548.0 L 878.0 567.0 L 865.0 588.0 L 852.0 614.0 L 829.0 666.0 L 813.0 695.0 L 794.0 721.0 L 777.0 738.0 L 761.0 750.0 L 731.0 765.0 L 700.0 774.0 L 671.0 778.0 L 638.0 779.0 L 632.0 781.0 L 625.0 785.0 L 595.0 815.0 L 566.0 836.0 L 536.0 852.0 L 503.0 864.0 L 477.0 870.0 L 451.0 873.0 L 416.0 873.0 L 398.0 871.0 L 369.0 865.0 L 344.0 857.0 L 295.0 834.0 L 257.0 846.0 L 237.0 854.0 L 205.0 871.0 L 197.0 877.0 L 189.0 886.0 L 186.0 892.0 L 187.0 904.0 L 195.0 912.0 L 204.0 916.0 L 214.0 918.0 L 822.0 919.0 L 847.0 915.0 L 864.0 910.0 L 890.0 899.0 L 902.0 892.0 L 924.0 876.0 L 939.0 862.0 L 952.0 847.0 L 967.0 825.0 L 979.0 801.0 L 987.0 778.0 L 999.0 728.0 L 1006.0 707.0 L 1021.0 680.0 L 1041.0 659.0 L 1050.0 643.0 L 1053.0 633.0 L 1054.0 618.0 L 1049.0 597.0 L 1042.0 583.0 L 1033.0 570.0 L 1023.0 559.0 L 1002.0 541.0 L 1000.0 532.0 L 1025.0 472.0 L 1055.0 412.0 L 1063.0 406.0 L 1068.0 406.0 L 1079.0 402.0 L 1092.0 389.0 L 1096.0 378.0 L 1096.0 366.0 Z M 569.0 324.0 L 537.0 316.0 L 510.0 312.0 L 497.0 312.0 L 496.0 311.0 L 460.0 312.0 L 431.0 316.0 L 413.0 320.0 L 390.0 327.0 L 359.0 340.0 L 342.0 349.0 L 317.0 365.0 L 292.0 385.0 L 271.0 406.0 L 260.0 419.0 L 241.0 446.0 L 222.0 482.0 L 211.0 511.0 L 204.0 538.0 L 200.0 562.0 L 199.0 584.0 L 198.0 585.0 L 198.0 611.0 L 199.0 612.0 L 200.0 635.0 L 206.0 667.0 L 215.0 696.0 L 221.0 711.0 L 235.0 738.0 L 245.0 753.0 L 262.0 774.0 L 278.0 790.0 L 295.0 804.0 L 321.0 821.0 L 341.0 831.0 L 372.0 842.0 L 395.0 847.0 L 412.0 849.0 L 447.0 849.0 L 469.0 846.0 L 486.0 842.0 L 509.0 834.0 L 530.0 824.0 L 565.0 800.0 L 581.0 785.0 L 598.0 765.0 L 611.0 745.0 L 623.0 721.0 L 629.0 704.0 L 635.0 680.0 L 638.0 659.0 L 638.0 623.0 L 634.0 597.0 L 623.0 562.0 L 607.0 532.0 L 595.0 516.0 L 578.0 498.0 L 566.0 488.0 L 549.0 477.0 L 531.0 468.0 L 514.0 462.0 L 492.0 457.0 L 454.0 456.0 L 430.0 460.0 L 420.0 463.0 L 389.0 477.0 L 366.0 494.0 L 354.0 506.0 L 343.0 520.0 L 335.0 533.0 L 327.0 550.0 L 320.0 575.0 L 318.0 604.0 L 320.0 622.0 L 325.0 641.0 L 332.0 657.0 L 348.0 680.0 L 364.0 695.0 L 385.0 708.0 L 410.0 716.0 L 441.0 717.0 L 456.0 714.0 L 475.0 706.0 L 488.0 697.0 L 499.0 686.0 L 506.0 676.0 L 514.0 658.0 L 517.0 641.0 L 516.0 626.0 L 512.0 611.0 L 503.0 596.0 L 494.0 587.0 L 488.0 583.0 L 470.0 576.0 L 454.0 576.0 L 444.0 579.0 L 435.0 584.0 L 425.0 596.0 L 423.0 601.0 L 423.0 612.0 L 426.0 619.0 L 431.0 624.0 L 435.0 626.0 L 446.0 628.0 L 452.0 635.0 L 452.0 640.0 L 450.0 644.0 L 445.0 648.0 L 439.0 650.0 L 428.0 650.0 L 416.0 646.0 L 411.0 643.0 L 401.0 633.0 L 394.0 620.0 L 392.0 610.0 L 392.0 600.0 L 396.0 584.0 L 403.0 571.0 L 415.0 558.0 L 428.0 549.0 L 444.0 543.0 L 454.0 541.0 L 474.0 541.0 L 488.0 544.0 L 512.0 556.0 L 531.0 574.0 L 540.0 587.0 L 548.0 605.0 L 553.0 631.0 L 552.0 652.0 L 547.0 674.0 L 537.0 695.0 L 527.0 709.0 L 509.0 727.0 L 501.0 733.0 L 476.0 746.0 L 456.0 752.0 L 443.0 754.0 L 406.0 753.0 L 375.0 744.0 L 359.0 736.0 L 344.0 726.0 L 318.0 701.0 L 305.0 683.0 L 295.0 664.0 L 288.0 645.0 L 284.0 628.0 L 282.0 613.0 L 282.0 582.0 L 286.0 558.0 L 291.0 541.0 L 305.0 511.0 L 314.0 497.0 L 324.0 484.0 L 348.0 460.0 L 364.0 448.0 L 379.0 439.0 L 398.0 430.0 L 415.0 424.0 L 436.0 419.0 L 452.0 417.0 L 487.0 417.0 L 508.0 420.0 L 533.0 427.0 L 560.0 439.0 L 585.0 455.0 L 595.0 463.0 L 619.0 487.0 L 630.0 501.0 L 646.0 526.0 L 662.0 562.0 L 669.0 587.0 L 674.0 622.0 L 674.0 660.0 L 670.0 688.0 L 664.0 712.0 L 659.0 727.0 L 651.0 745.0 L 652.0 746.0 L 667.0 746.0 L 689.0 743.0 L 706.0 739.0 L 725.0 732.0 L 742.0 723.0 L 760.0 709.0 L 767.0 701.0 L 775.0 687.0 L 779.0 669.0 L 781.0 649.0 L 781.0 615.0 L 776.0 570.0 L 772.0 550.0 L 763.0 518.0 L 753.0 492.0 L 737.0 460.0 L 728.0 445.0 L 709.0 419.0 L 696.0 404.0 L 672.0 381.0 L 650.0 364.0 L 621.0 346.0 L 596.0 334.0 Z"/></svg>';
    }

// bleeding: single drop (inline SVG effect glyph)
  public static function effectBleeding(): String
    {
      // viewBox padded ~30% about centre so the glyph reads smaller within its box (baked-in scale)
      return '<svg viewBox="-120 -183.2 800 1221.4" fill="currentColor" fill-rule="evenodd" aria-hidden="true">' +
        '<path d="M 279.0 16.0 L 275.0 24.0 L 273.0 26.0 L 271.0 31.0 L 269.0 33.0 L 267.0 38.0 L 265.0 40.0 L 264.0 43.0 L 262.0 45.0 L 261.0 48.0 L 259.0 50.0 L 258.0 53.0 L 256.0 55.0 L 255.0 58.0 L 253.0 60.0 L 252.0 63.0 L 250.0 65.0 L 249.0 68.0 L 247.0 70.0 L 246.0 73.0 L 244.0 75.0 L 240.0 83.0 L 236.0 88.0 L 235.0 91.0 L 233.0 93.0 L 229.0 101.0 L 225.0 106.0 L 224.0 109.0 L 220.0 114.0 L 216.0 122.0 L 212.0 127.0 L 211.0 130.0 L 207.0 135.0 L 206.0 138.0 L 202.0 143.0 L 201.0 146.0 L 197.0 151.0 L 196.0 154.0 L 190.0 162.0 L 189.0 165.0 L 185.0 170.0 L 184.0 173.0 L 176.0 184.0 L 175.0 187.0 L 167.0 198.0 L 166.0 201.0 L 160.0 209.0 L 159.0 212.0 L 151.0 223.0 L 150.0 226.0 L 148.0 228.0 L 148.0 229.0 L 144.0 234.0 L 143.0 237.0 L 137.0 245.0 L 136.0 248.0 L 130.0 256.0 L 129.0 259.0 L 125.0 264.0 L 124.0 267.0 L 120.0 272.0 L 119.0 275.0 L 115.0 280.0 L 114.0 283.0 L 112.0 285.0 L 111.0 288.0 L 106.0 295.0 L 104.0 300.0 L 97.0 310.0 L 95.0 315.0 L 93.0 317.0 L 88.0 327.0 L 86.0 329.0 L 83.0 336.0 L 81.0 338.0 L 77.0 347.0 L 75.0 349.0 L 53.0 393.0 L 53.0 395.0 L 49.0 402.0 L 49.0 404.0 L 43.0 416.0 L 43.0 418.0 L 41.0 421.0 L 40.0 426.0 L 38.0 429.0 L 36.0 437.0 L 34.0 440.0 L 34.0 442.0 L 33.0 443.0 L 33.0 445.0 L 31.0 449.0 L 31.0 452.0 L 29.0 456.0 L 29.0 459.0 L 27.0 463.0 L 27.0 466.0 L 26.0 467.0 L 26.0 470.0 L 25.0 471.0 L 25.0 475.0 L 24.0 476.0 L 24.0 479.0 L 23.0 480.0 L 23.0 484.0 L 22.0 485.0 L 22.0 488.0 L 21.0 489.0 L 20.0 501.0 L 19.0 502.0 L 19.0 508.0 L 18.0 509.0 L 18.0 516.0 L 17.0 517.0 L 17.0 528.0 L 16.0 529.0 L 16.0 578.0 L 17.0 579.0 L 17.0 588.0 L 18.0 589.0 L 18.0 596.0 L 19.0 597.0 L 20.0 610.0 L 21.0 611.0 L 21.0 615.0 L 22.0 616.0 L 22.0 619.0 L 23.0 620.0 L 23.0 624.0 L 24.0 625.0 L 24.0 628.0 L 25.0 629.0 L 26.0 636.0 L 27.0 637.0 L 27.0 639.0 L 29.0 643.0 L 29.0 646.0 L 30.0 647.0 L 30.0 649.0 L 31.0 650.0 L 33.0 658.0 L 35.0 661.0 L 36.0 666.0 L 41.0 676.0 L 41.0 678.0 L 51.0 698.0 L 53.0 700.0 L 55.0 705.0 L 57.0 707.0 L 58.0 710.0 L 60.0 712.0 L 60.0 713.0 L 62.0 715.0 L 62.0 716.0 L 64.0 718.0 L 68.0 725.0 L 71.0 728.0 L 73.0 732.0 L 80.0 740.0 L 80.0 741.0 L 86.0 747.0 L 86.0 748.0 L 112.0 774.0 L 113.0 774.0 L 119.0 780.0 L 120.0 780.0 L 124.0 784.0 L 125.0 784.0 L 132.0 790.0 L 133.0 790.0 L 150.0 802.0 L 155.0 804.0 L 157.0 806.0 L 179.0 817.0 L 181.0 817.0 L 191.0 822.0 L 193.0 822.0 L 194.0 823.0 L 196.0 823.0 L 197.0 824.0 L 199.0 824.0 L 200.0 825.0 L 202.0 825.0 L 203.0 826.0 L 205.0 826.0 L 209.0 828.0 L 212.0 828.0 L 216.0 830.0 L 219.0 830.0 L 220.0 831.0 L 223.0 831.0 L 224.0 832.0 L 227.0 832.0 L 228.0 833.0 L 232.0 833.0 L 233.0 834.0 L 237.0 834.0 L 238.0 835.0 L 252.0 836.0 L 253.0 837.0 L 265.0 837.0 L 266.0 838.0 L 293.0 838.0 L 294.0 837.0 L 305.0 837.0 L 306.0 836.0 L 314.0 836.0 L 315.0 835.0 L 320.0 835.0 L 321.0 834.0 L 325.0 834.0 L 326.0 833.0 L 335.0 832.0 L 336.0 831.0 L 343.0 830.0 L 347.0 828.0 L 350.0 828.0 L 351.0 827.0 L 353.0 827.0 L 354.0 826.0 L 356.0 826.0 L 357.0 825.0 L 359.0 825.0 L 360.0 824.0 L 368.0 822.0 L 371.0 820.0 L 373.0 820.0 L 378.0 817.0 L 380.0 817.0 L 402.0 806.0 L 404.0 804.0 L 412.0 800.0 L 414.0 798.0 L 415.0 798.0 L 417.0 796.0 L 418.0 796.0 L 420.0 794.0 L 427.0 790.0 L 430.0 787.0 L 431.0 787.0 L 434.0 784.0 L 435.0 784.0 L 439.0 780.0 L 440.0 780.0 L 445.0 775.0 L 446.0 775.0 L 465.0 757.0 L 465.0 756.0 L 480.0 740.0 L 480.0 739.0 L 492.0 724.0 L 492.0 723.0 L 496.0 718.0 L 497.0 715.0 L 501.0 710.0 L 502.0 707.0 L 504.0 705.0 L 506.0 700.0 L 508.0 698.0 L 519.0 676.0 L 519.0 674.0 L 521.0 671.0 L 521.0 669.0 L 525.0 661.0 L 525.0 659.0 L 526.0 658.0 L 526.0 656.0 L 527.0 655.0 L 527.0 653.0 L 528.0 652.0 L 528.0 650.0 L 529.0 649.0 L 529.0 647.0 L 530.0 646.0 L 530.0 644.0 L 532.0 640.0 L 532.0 637.0 L 533.0 636.0 L 533.0 633.0 L 535.0 629.0 L 535.0 625.0 L 536.0 624.0 L 536.0 621.0 L 537.0 620.0 L 537.0 616.0 L 538.0 615.0 L 538.0 610.0 L 539.0 609.0 L 539.0 604.0 L 540.0 603.0 L 540.0 596.0 L 541.0 595.0 L 541.0 588.0 L 542.0 587.0 L 542.0 576.0 L 543.0 575.0 L 543.0 532.0 L 542.0 531.0 L 542.0 520.0 L 541.0 519.0 L 541.0 511.0 L 540.0 510.0 L 540.0 504.0 L 539.0 503.0 L 538.0 491.0 L 537.0 490.0 L 536.0 480.0 L 535.0 479.0 L 535.0 476.0 L 534.0 475.0 L 534.0 472.0 L 533.0 471.0 L 532.0 464.0 L 530.0 460.0 L 529.0 453.0 L 528.0 452.0 L 528.0 450.0 L 527.0 449.0 L 527.0 447.0 L 526.0 446.0 L 524.0 438.0 L 522.0 435.0 L 522.0 433.0 L 521.0 432.0 L 519.0 424.0 L 517.0 421.0 L 517.0 419.0 L 515.0 416.0 L 515.0 414.0 L 513.0 411.0 L 513.0 409.0 L 510.0 404.0 L 510.0 402.0 L 505.0 393.0 L 505.0 391.0 L 485.0 351.0 L 483.0 349.0 L 473.0 329.0 L 468.0 322.0 L 466.0 317.0 L 461.0 310.0 L 459.0 305.0 L 457.0 303.0 L 456.0 300.0 L 454.0 298.0 L 453.0 295.0 L 451.0 293.0 L 447.0 285.0 L 443.0 280.0 L 442.0 277.0 L 440.0 275.0 L 439.0 272.0 L 437.0 270.0 L 434.0 264.0 L 430.0 259.0 L 426.0 251.0 L 418.0 240.0 L 417.0 237.0 L 411.0 229.0 L 410.0 226.0 L 402.0 215.0 L 401.0 212.0 L 395.0 204.0 L 394.0 201.0 L 386.0 190.0 L 385.0 187.0 L 379.0 179.0 L 378.0 176.0 L 374.0 171.0 L 373.0 168.0 L 365.0 157.0 L 364.0 154.0 L 362.0 152.0 L 359.0 146.0 L 355.0 141.0 L 354.0 138.0 L 350.0 133.0 L 346.0 125.0 L 342.0 120.0 L 341.0 117.0 L 339.0 115.0 L 335.0 107.0 L 333.0 105.0 L 330.0 99.0 L 326.0 94.0 L 325.0 91.0 L 323.0 89.0 L 319.0 81.0 L 315.0 76.0 L 314.0 73.0 L 312.0 71.0 L 311.0 68.0 L 309.0 66.0 L 308.0 63.0 L 306.0 61.0 L 305.0 58.0 L 303.0 56.0 L 302.0 53.0 L 297.0 46.0 L 295.0 41.0 L 290.0 34.0 L 288.0 29.0 L 286.0 27.0 L 281.0 17.0 Z"/></svg>';
    }

// black noise: glitched vortex (inline SVG effect glyph)
  public static function effectBlackNoise(): String
    {
      // viewBox trimmed ~15% about centre so the glyph reads larger within its box (baked-in scale)
      return '<svg viewBox="81.8 81.8 1090.4 1090.4" fill="currentColor" fill-rule="evenodd" aria-hidden="true">' +
        '<path d="M 550.0 1039.0 L 548.0 1041.0 L 548.0 1050.0 L 549.0 1051.0 L 548.0 1066.0 L 549.0 1067.0 L 575.0 1067.0 L 576.0 1066.0 L 576.0 1040.0 L 575.0 1039.0 Z M 356.0 865.0 L 356.0 869.0 L 358.0 872.0 L 366.0 878.0 L 371.0 880.0 L 381.0 881.0 L 387.0 879.0 L 391.0 875.0 L 391.0 872.0 L 388.0 868.0 L 381.0 866.0 L 372.0 861.0 L 363.0 860.0 L 358.0 862.0 Z M 982.0 827.0 L 981.0 828.0 L 981.0 854.0 L 982.0 855.0 L 1007.0 855.0 L 1008.0 854.0 L 1008.0 828.0 L 1007.0 827.0 Z M 218.0 702.0 L 218.0 709.0 L 219.0 710.0 L 218.0 731.0 L 219.0 732.0 L 255.0 732.0 L 256.0 731.0 L 256.0 702.0 L 255.0 701.0 L 219.0 701.0 Z M 311.0 382.0 L 310.0 383.0 L 310.0 409.0 L 311.0 410.0 L 336.0 410.0 L 337.0 409.0 L 337.0 383.0 L 336.0 382.0 Z M 967.0 347.0 L 966.0 348.0 L 966.0 377.0 L 967.0 378.0 L 997.0 378.0 L 998.0 377.0 L 998.0 348.0 L 997.0 347.0 Z M 789.0 282.0 L 790.0 285.0 L 795.0 289.0 L 802.0 290.0 L 816.0 295.0 L 825.0 294.0 L 830.0 290.0 L 830.0 286.0 L 827.0 282.0 L 812.0 275.0 L 799.0 275.0 L 793.0 277.0 Z M 529.0 276.0 L 520.0 281.0 L 514.0 287.0 L 511.0 294.0 L 508.0 297.0 L 500.0 298.0 L 486.0 306.0 L 472.0 319.0 L 462.0 325.0 L 453.0 334.0 L 440.0 359.0 L 416.0 391.0 L 406.0 412.0 L 403.0 421.0 L 402.0 434.0 L 405.0 437.0 L 409.0 437.0 L 418.0 431.0 L 423.0 431.0 L 427.0 436.0 L 427.0 451.0 L 423.0 465.0 L 414.0 481.0 L 410.0 493.0 L 409.0 510.0 L 402.0 540.0 L 402.0 561.0 L 403.0 562.0 L 404.0 573.0 L 409.0 586.0 L 416.0 593.0 L 423.0 606.0 L 426.0 617.0 L 427.0 629.0 L 432.0 640.0 L 435.0 643.0 L 435.0 645.0 L 434.0 646.0 L 419.0 646.0 L 411.0 641.0 L 399.0 636.0 L 391.0 637.0 L 384.0 642.0 L 378.0 644.0 L 371.0 644.0 L 360.0 640.0 L 348.0 628.0 L 346.0 616.0 L 343.0 610.0 L 335.0 604.0 L 326.0 594.0 L 323.0 586.0 L 323.0 572.0 L 320.0 564.0 L 314.0 557.0 L 309.0 557.0 L 306.0 562.0 L 305.0 573.0 L 308.0 584.0 L 313.0 591.0 L 315.0 619.0 L 325.0 636.0 L 325.0 647.0 L 333.0 658.0 L 580.0 658.0 L 582.0 660.0 L 582.0 688.0 L 580.0 690.0 L 502.0 690.0 L 501.0 691.0 L 501.0 719.0 L 499.0 721.0 L 465.0 721.0 L 464.0 722.0 L 464.0 748.0 L 462.0 750.0 L 383.0 750.0 L 382.0 751.0 L 382.0 758.0 L 380.0 760.0 L 341.0 760.0 L 340.0 761.0 L 333.0 761.0 L 332.0 762.0 L 332.0 785.0 L 333.0 786.0 L 447.0 786.0 L 449.0 788.0 L 449.0 820.0 L 450.0 821.0 L 623.0 821.0 L 651.0 814.0 L 678.0 805.0 L 679.0 808.0 L 670.0 820.0 L 656.0 834.0 L 642.0 844.0 L 631.0 848.0 L 621.0 850.0 L 598.0 850.0 L 584.0 854.0 L 581.0 856.0 L 575.0 863.0 L 575.0 869.0 L 578.0 873.0 L 577.0 879.0 L 570.0 886.0 L 558.0 892.0 L 533.0 894.0 L 519.0 897.0 L 506.0 897.0 L 505.0 896.0 L 498.0 896.0 L 482.0 891.0 L 474.0 886.0 L 463.0 876.0 L 449.0 871.0 L 437.0 871.0 L 436.0 872.0 L 419.0 871.0 L 415.0 872.0 L 412.0 875.0 L 413.0 881.0 L 420.0 887.0 L 428.0 890.0 L 439.0 891.0 L 450.0 896.0 L 460.0 903.0 L 481.0 921.0 L 500.0 930.0 L 513.0 933.0 L 532.0 934.0 L 554.0 939.0 L 577.0 938.0 L 585.0 935.0 L 592.0 930.0 L 602.0 927.0 L 613.0 927.0 L 632.0 932.0 L 636.0 937.0 L 636.0 941.0 L 634.0 945.0 L 621.0 958.0 L 612.0 962.0 L 597.0 963.0 L 589.0 967.0 L 585.0 972.0 L 585.0 975.0 L 588.0 978.0 L 597.0 981.0 L 617.0 981.0 L 627.0 979.0 L 644.0 972.0 L 653.0 964.0 L 664.0 960.0 L 680.0 944.0 L 691.0 938.0 L 698.0 936.0 L 717.0 937.0 L 727.0 935.0 L 740.0 928.0 L 751.0 918.0 L 755.0 912.0 L 756.0 908.0 L 755.0 903.0 L 752.0 901.0 L 748.0 901.0 L 741.0 904.0 L 733.0 904.0 L 729.0 900.0 L 730.0 890.0 L 736.0 881.0 L 743.0 874.0 L 752.0 868.0 L 768.0 862.0 L 778.0 855.0 L 786.0 846.0 L 790.0 836.0 L 790.0 831.0 L 789.0 830.0 L 790.0 819.0 L 797.0 807.0 L 802.0 802.0 L 809.0 798.0 L 819.0 786.0 L 820.0 781.0 L 832.0 759.0 L 838.0 741.0 L 840.0 730.0 L 843.0 727.0 L 848.0 735.0 L 852.0 747.0 L 853.0 757.0 L 854.0 758.0 L 854.0 767.0 L 855.0 768.0 L 855.0 781.0 L 850.0 806.0 L 843.0 821.0 L 836.0 831.0 L 830.0 846.0 L 830.0 858.0 L 833.0 863.0 L 839.0 864.0 L 843.0 868.0 L 844.0 875.0 L 840.0 887.0 L 828.0 904.0 L 824.0 912.0 L 823.0 919.0 L 816.0 931.0 L 807.0 943.0 L 792.0 959.0 L 787.0 962.0 L 778.0 971.0 L 776.0 975.0 L 779.0 979.0 L 786.0 978.0 L 810.0 966.0 L 843.0 941.0 L 866.0 926.0 L 880.0 912.0 L 890.0 893.0 L 907.0 876.0 L 921.0 857.0 L 927.0 845.0 L 929.0 838.0 L 928.0 828.0 L 924.0 826.0 L 919.0 828.0 L 911.0 834.0 L 906.0 833.0 L 902.0 826.0 L 902.0 816.0 L 904.0 807.0 L 910.0 791.0 L 917.0 779.0 L 926.0 770.0 L 934.0 753.0 L 935.0 748.0 L 934.0 716.0 L 937.0 701.0 L 937.0 687.0 L 936.0 686.0 L 936.0 678.0 L 934.0 669.0 L 930.0 662.0 L 919.0 660.0 L 915.0 656.0 L 911.0 649.0 L 904.0 628.0 L 903.0 600.0 L 900.0 590.0 L 896.0 583.0 L 891.0 578.0 L 879.0 573.0 L 872.0 566.0 L 863.0 551.0 L 847.0 540.0 L 844.0 536.0 L 845.0 535.0 L 880.0 535.0 L 898.0 542.0 L 911.0 554.0 L 918.0 557.0 L 927.0 558.0 L 939.0 570.0 L 945.0 585.0 L 949.0 601.0 L 955.0 611.0 L 962.0 617.0 L 966.0 618.0 L 975.0 617.0 L 986.0 628.0 L 994.0 648.0 L 994.0 652.0 L 997.0 662.0 L 998.0 677.0 L 999.0 678.0 L 999.0 699.0 L 997.0 707.0 L 990.0 722.0 L 990.0 733.0 L 994.0 738.0 L 997.0 738.0 L 1000.0 736.0 L 1004.0 731.0 L 1014.0 711.0 L 1019.0 695.0 L 1020.0 671.0 L 1019.0 670.0 L 1018.0 651.0 L 1020.0 641.0 L 1020.0 621.0 L 1016.0 616.0 L 1011.0 616.0 L 1007.0 614.0 L 1000.0 607.0 L 992.0 587.0 L 979.0 572.0 L 975.0 560.0 L 975.0 553.0 L 978.0 546.0 L 981.0 543.0 L 981.0 538.0 L 966.0 523.0 L 735.0 523.0 L 733.0 521.0 L 733.0 489.0 L 737.0 486.0 L 801.0 486.0 L 802.0 485.0 L 802.0 445.0 L 805.0 442.0 L 888.0 442.0 L 892.0 445.0 L 892.0 473.0 L 893.0 474.0 L 980.0 474.0 L 981.0 473.0 L 981.0 439.0 L 980.0 438.0 L 921.0 438.0 L 919.0 436.0 L 919.0 419.0 L 918.0 418.0 L 827.0 418.0 L 825.0 416.0 L 825.0 385.0 L 824.0 384.0 L 723.0 384.0 L 687.0 399.0 L 646.0 420.0 L 630.0 431.0 L 607.0 452.0 L 603.0 454.0 L 602.0 449.0 L 604.0 443.0 L 613.0 425.0 L 624.0 410.0 L 638.0 398.0 L 659.0 388.0 L 670.0 377.0 L 671.0 368.0 L 662.0 361.0 L 661.0 357.0 L 665.0 350.0 L 679.0 335.0 L 689.0 329.0 L 703.0 326.0 L 714.0 315.0 L 720.0 312.0 L 731.0 311.0 L 735.0 313.0 L 747.0 313.0 L 758.0 308.0 L 761.0 305.0 L 761.0 303.0 L 758.0 300.0 L 751.0 297.0 L 743.0 295.0 L 734.0 295.0 L 727.0 297.0 L 703.0 297.0 L 683.0 303.0 L 678.0 303.0 L 659.0 307.0 L 650.0 311.0 L 638.0 320.0 L 629.0 324.0 L 624.0 325.0 L 604.0 324.0 L 590.0 329.0 L 578.0 336.0 L 563.0 348.0 L 546.0 356.0 L 532.0 369.0 L 525.0 379.0 L 523.0 385.0 L 523.0 392.0 L 525.0 394.0 L 531.0 394.0 L 540.0 389.0 L 546.0 389.0 L 550.0 393.0 L 551.0 401.0 L 547.0 415.0 L 539.0 431.0 L 522.0 451.0 L 514.0 466.0 L 513.0 483.0 L 506.0 502.0 L 502.0 520.0 L 503.0 543.0 L 510.0 569.0 L 509.0 571.0 L 506.0 571.0 L 489.0 555.0 L 472.0 529.0 L 469.0 517.0 L 469.0 507.0 L 474.0 487.0 L 473.0 472.0 L 469.0 468.0 L 460.0 468.0 L 457.0 465.0 L 455.0 460.0 L 455.0 447.0 L 462.0 423.0 L 465.0 417.0 L 471.0 410.0 L 478.0 396.0 L 480.0 389.0 L 479.0 381.0 L 476.0 378.0 L 472.0 377.0 L 468.0 372.0 L 469.0 362.0 L 474.0 352.0 L 482.0 342.0 L 487.0 330.0 L 505.0 311.0 L 509.0 304.0 L 512.0 301.0 L 522.0 301.0 L 530.0 298.0 L 540.0 288.0 L 543.0 282.0 L 542.0 278.0 L 538.0 275.0 Z M 621.0 188.0 L 620.0 189.0 L 620.0 215.0 L 621.0 216.0 L 646.0 216.0 L 647.0 215.0 L 647.0 189.0 L 646.0 188.0 Z"/></svg>';
    }

// multiple effects: upright triangle holding the live active-effect count
  public static function effectMultiple(count: Int): String
    {
      return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true">' +
        '<path d="M12 2.5 22.4 20.5 1.6 20.5Z"/>' +
        '<text x="12" y="18.4" font-family="sans-serif" font-size="10" font-weight="bold" text-anchor="middle" fill="currentColor" stroke="none">' + count + '</text></svg>';
    }

// resolve an AI entity badge glyph key (see ai.AI.getBadges) to its inline SVG, matching the 2D
// entities atlas art. rising alertness is a "?" (tinted white->yellow->orange by the 3D badge
// pass), full alert a "!"
  public static function badge(key: String): String
    {
      switch (key)
        {
          case 'alert1', 'alert2', 'alert3':
            return badgeQuestion();
          case 'alerted':
            return badgeWarn();
          case 'calling':
            return badgeCalling();
          case 'search':
            return badgeSearch();
          case 'paralysis':
            return effectParalysis();
          case 'panic':
            return effectPanic();
          case 'slime':
            return effectSlime();
          case 'bleeding':
            return effectBleeding();
          case 'blacknoise':
            return effectBlackNoise();
          case 'npc':
            return badgeNpc();
        }
      return badgeWarn();
    }

// question mark (rising alertness — suspicious)
  public static function badgeQuestion(): String
    {
      return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '<path d="M7.7 8.4 A4.3 4.3 0 1 1 12.2 12.6 C11 13.4 11 14 11 15.4"/>' +   // hook + stem
        '<circle cx="11" cy="19.4" r="1.7" fill="currentColor" stroke="none"/></svg>'; // dot
    }

// exclamation mark (fully alerted)
  public static function badgeWarn(): String
    {
      return '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">' +
        '<path d="M9.6 3 H14.4 L13.3 15 H10.7 Z"/>' +   // tapering bar
        '<circle cx="12" cy="19.2" r="2.1"/></svg>';    // dot
    }

// broadcast waves ((•)) (calling law / backup)
  public static function badgeCalling(): String
    {
      return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">' +
        '<circle cx="12" cy="12" r="2.4" fill="currentColor" stroke="none"/>' +
        '<path d="M7.5 7.5 A6.4 6.4 0 0 0 7.5 16.5"/>' +     // inner arcs
        '<path d="M16.5 7.5 A6.4 6.4 0 0 1 16.5 16.5"/>' +
        '<path d="M4.6 4.6 A10.4 10.4 0 0 0 4.6 19.4"/>' +   // outer arcs
        '<path d="M19.4 4.6 A10.4 10.4 0 0 1 19.4 19.4"/></svg>';
    }

// magnifier (searching last-seen / area)
  public static function badgeSearch(): String
    {
      return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.9" stroke-linecap="round" aria-hidden="true">' +
        '<circle cx="10.5" cy="10.5" r="6"/>' +
        '<line x1="15" y1="15" x2="20.5" y2="20.5"/></svg>';
    }

// pale disc with a neutral face (npc / mission target). self-colored (not currentColor) — the
// two-tone face can't be a single tint
  public static function badgeNpc(): String
    {
      return '<svg viewBox="0 0 24 24" aria-hidden="true">' +
        '<circle cx="12" cy="12" r="10.5" fill="#f2f2f2"/>' +          // face disc
        '<circle cx="8.3" cy="10" r="1.8" fill="#2a2a2a"/>' +          // eyes
        '<circle cx="15.7" cy="10" r="1.8" fill="#2a2a2a"/>' +
        '<rect x="7.8" y="15" width="8.4" height="2.3" rx="1.15" fill="#2a2a2a"/></svg>'; // mouth
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
