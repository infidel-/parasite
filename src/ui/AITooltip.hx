// area AI tooltip overlay for HUD (content + visibility; beam/placement in BeamTooltip)
package ui;

import ai.AI;
import game.Game;

class AITooltip extends BeamTooltip
{
  public function new(g: Game, h: HUD)
    {
      super(g, h, 'hud-ai-info', 'ai-tip');
    }

// show area AI tooltip when inspect mode is active
  public function update()
    {
      // the 3D view drives its own hover tooltip (projected anchor via render.View.loop);
      // the 2D tile mapping is wrong under the perspective camera, so stand down there
      if (game.scene.view3d != null &&
          game.scene.view3d.running)
        return;
      if (!hud.isAIInspectMode())
        {
          hide();
          return;
        }

      var pos = game.scene.mouse.getXY();
      if (pos.x < 0 ||
          pos.y < 0 ||
          pos.x >= game.area.width ||
          pos.y >= game.area.height)
        {
          hide();
          return;
        }

      if (!game.scene.area.isVisible(pos.x, pos.y))
        {
          hide();
          return;
        }

      var ai = game.area.getAI(pos.x, pos.y);
      if (ai == null)
        {
          hide();
          return;
        }

      showBeam(ai.x, ai.y, ai.id, getTooltipText(ai));
    }

// get tooltip HTML for hovered AI (public: the 3D view's hover driver reuses it verbatim)
  public function getTooltipText(ai: AI): String
    {
      var buf = new StringBuf();
      // header: name + optional cultist mark
      buf.add('<div class="ai-tip-head"><span class="ai-tip-name">' + ai.getNameCapped() + '</span>');
      if (ai.isCultist)
        buf.add('<span class="ai-tip-cultmark">' + Icon.cultist + '</span>');
      buf.add('</div>');

      // sub rows: cult affiliation, job
      if (ai.isCultist)
        buf.add('<div class="ai-tip-sub">' + game.getCultByID(ai.cultID).Name() + '</div>');
      if (!ai.isIt() && ai.isJobKnown)
        buf.add('<div class="ai-tip-row"><span class="ai-tip-rk">job</span>' + ai.job + '</div>');

      // attribute pills
      if (ai.isAttrsKnown)
        buf.add(attrPills(ai.strength, ai.constitution, ai.intellect, ai.psyche));

      // active effects (body window style, always shown)
      var effects = [];
      for (effect in ai.effects)
        if (!effect.isHidden)
          effects.push(effect);
      if (effects.length > 0)
        {
          effects.sort(function(a, b) {
            return (a.name < b.name ? -1 : (a.name > b.name ? 1 : 0));
          });
          buf.add('<div class="ai-tip-effects">');
          for (effect in effects)
            buf.add('<div class="body-eff-row">' + UISvg.bodyEffect() + ' ' + effect.name +
              (effect.isTimer ? '<span class="body-eff-t">' +
                UISvg.clockSmall('body-ico body-ico-time') + effect.points + '</span>' : '') +
              '</div>');
          buf.add('</div>');
        }

      if (Const.isDebug)
        addDebugBlock(buf, ai);
      return buf.toString();
    }

// build the STR/CON/INT/PSY pill row
  function attrPills(str: Int, con: Int, int: Int, psy: Int): String
    {
      return '<div class="ai-tip-attrs">' +
        '<span class="ai-tip-attr">STR<b>' + str + '</b></span>' +
        '<span class="ai-tip-attr">CON<b>' + con + '</b></span>' +
        '<span class="ai-tip-attr">INT<b>' + int + '</b></span>' +
        '<span class="ai-tip-attr">PSY<b>' + psy + '</b></span></div>';
    }

// append the debug detail block
  function addDebugBlock(buf: StringBuf, ai: AI)
    {
      buf.add('<div class="ai-tip-debug">');
      if (!ai.isNameKnown)
        buf.add(Const.smalldebug('[debug] name: ' + ai.name.real) + '<br/>');
      if (!ai.isJobKnown)
        buf.add(Const.smalldebug('[debug] job: ' + ai.job) + '<br/>');
      buf.add(Const.smalldebug('[debug] state: ' + ai.state) + '<br/>');
      if (!ai.isAttrsKnown)
        {
          var attrs = '[debug] STR ' + ai.strength +
            ' CON ' + ai.constitution +
            ' INT ' + ai.intellect +
            ' PSY ' + ai.psyche;
          buf.add(Const.smalldebug(attrs) + '<br/>');
        }
      buf.add(Const.smalldebug('[debug] health ' + ai.health + '/' + ai.maxHealth) + '<br/>');
      buf.add(Const.smalldebug('[debug] id: ' + ai.id) + '<br/>');
      buf.add(Const.smalldebug('[debug] pos: (' + ai.x + ',' + ai.y + ')') + '<br/>');
      buf.add(Const.smalldebug('[debug] alertness: ' + ai.alertness) + '<br/>');
      addDebugListRow(buf, 'abilities', getAbilitiesText(ai));
      addDebugListRow(buf, 'hidden effects', getHiddenEffectsText(ai));
      addDebugListRow(buf, 'inventory', ai.inventory.toString());
      addDebugListRow(buf, 'skills', ai.skills.toString());
      addDebugListRow(buf, 'organs', ai.organs.toString());
      addDebugListRow(buf, 'traits', getTraitsText(ai));
      buf.add('</div>');
    }

// get abilities text for debug tooltip
  function getAbilitiesText(ai: AI): String
    {
      var list = [];
      for (ability in ai.abilities.iterator())
        {
          var s = '' + ability.id;
          if (ability.timeout > 0)
            s += ' [' + ability.timeout + ']';
          list.push(s);
        }
      return list.join(', ');
    }

// get hidden effects text for debug tooltip (visible ones show in the normal block)
  function getHiddenEffectsText(ai: AI): String
    {
      var list = [];
      for (effect in ai.effects)
        if (effect.isHidden)
          list.push(effect.type + ' pts:' + effect.points);
      return list.join(', ');
    }

// get traits text for debug tooltip
  function getTraitsText(ai: AI): String
    {
      var list = [];
      for (trait in ai.traits)
        list.push('' + trait);
      return list.join(', ');
    }

// add debug list row only when value is not empty
  inline function addDebugListRow(buf: StringBuf, name: String, value: String)
    {
      if (value == null || value == '')
        return;
      buf.add(Const.smalldebug('[debug] ' + name + ': ' + value) + '<br/>');
    }
}
