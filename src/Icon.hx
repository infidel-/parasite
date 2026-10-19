// utf-8 symbols
class Icon
{
  public static var energy = '<span class="icon-energy icon-svg">' + ui.UISvg.hudBolt() + '</span>';
  public static var money = '<span class=icon-money>&#9791;</span>'; // ☿
  public static var checkbox = '<span class=icon>&#9745;</span>'; // ☑ 
  public static var affinity = '<span class="icon-affinity icon-svg evolution-tip" data-tip="Full affinity: leaving this host costs some maximum energy.">' + ui.UISvg.badgeAffinity() + '</span>';
  public static var consent = '<span class="icon-consent icon-svg evolution-tip" data-tip="Full consent: this host cooperates with you.">' + ui.UISvg.badgeConsent() + '</span>';
  public static var cultist = '<span class="icon-cultist icon-svg evolution-tip" data-tip="Cultist: this host serves your cult.">' + ui.UISvg.badgeCultist() + '</span>';
  public static var breaking = '<span class="icon-breaking icon-svg evolution-tip" data-tip="Breaking: further degradation will soon collapse this host.">' + ui.UISvg.badgeBreaking() + '</span>';

}
