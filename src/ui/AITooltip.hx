// area AI tooltip overlay for HUD
package ui;

import ai.AI;
import js.Browser;
import js.html.DivElement;
import game.Game;

class AITooltip
{
  var game: Game;
  var hud: HUD;
  public var overlay: DivElement;
  public var visible: Bool;
  public var aiID: Int;

  public function new(g: Game, h: HUD)
    {
      game = g;
      hud = h;
      visible = false;
      aiID = -1;

      overlay = Browser.document.createDivElement();
      overlay.className = 'text small';
      overlay.id = 'hud-ai-info';
      overlay.style.display = 'none';
      overlay.style.position = 'fixed';
      overlay.style.pointerEvents = 'none';
      overlay.style.borderImage = "url('./img/hud-log-border.png') 15 fill / 1 / 0 stretch";
      hud.container.appendChild(overlay);
    }

// show area AI tooltip when inspect mode is active
  public function update()
    {
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

      overlay.innerHTML = getTooltipText(ai);
      overlay.style.display = 'block';
      overlay.style.visibility = 'hidden';
      visible = true;
      aiID = ai.id;
      updatePosition();
      overlay.style.visibility = 'visible';
    }

// update tooltip position near mouse and clamp to viewport
  public function updatePosition()
    {
      if (!visible)
        return;

      var ratio = Browser.window.devicePixelRatio;
      var left = game.scene.mouseX / ratio + 16;
      var top = game.scene.mouseY / ratio + 24;
      var width = overlay.offsetWidth;
      var height = overlay.offsetHeight;
      var maxX = Browser.window.innerWidth - width - 4;
      var maxY = Browser.window.innerHeight - height - 4;
      if (left > maxX)
        left = maxX;
      if (top > maxY)
        top = maxY;
      if (left < 4)
        left = 4;
      if (top < 4)
        top = 4;
      overlay.style.left = Std.string(Math.round(left)) + 'px';
      overlay.style.top = Std.string(Math.round(top)) + 'px';
    }

// hide area AI tooltip overlay
  public function hide()
    {
      if (!visible)
        return;
      visible = false;
      aiID = -1;
      overlay.style.display = 'none';
      overlay.style.visibility = 'hidden';
    }

// get tooltip HTML for hovered AI
  function getTooltipText(ai: AI): String
    {
      var buf = new StringBuf();
      buf.add('<span class=hud-name>' + ai.getNameCapped() + '</span>');
      if (ai.isCultist)
        buf.add(' ' + Icon.cultist);
      buf.add('<br/>');
      if (ai.isJobKnown)
        buf.add('job: ' + ai.job + '<br/>');
      if (ai.isAttrsKnown)
        {
          buf.add('STR ' + ai.strength);
          buf.add(' CON ' + ai.constitution);
          buf.add(' INT ' + ai.intellect);
          buf.add(' PSY ' + ai.psyche + '<br/>');
        }

#if mydebug
      if (!ai.isNameKnown)
        buf.add(Const.smalldebug('[debug] name: ' + ai.name.real) + '<br/>');
      if (!ai.isJobKnown)
        buf.add(Const.smalldebug('[debug] job: ' + ai.job) + '<br/>');
      if (!ai.isAttrsKnown)
        {
          var attrs = '[debug] STR ' + ai.strength +
            ' CON ' + ai.constitution +
            ' INT ' + ai.intellect +
            ' PSY ' + ai.psyche;
          buf.add(Const.smalldebug(attrs) + '<br/>');
        }
      buf.add(Const.smalldebug('[debug] health ' + ai.health + '/' + ai.maxHealth + '<br/>'));
      buf.add('<hr/>');
      buf.add(Const.smalldebug('[debug] id: ' + ai.id) + '<br/>');
      buf.add(Const.smalldebug('[debug] pos: (' + ai.x + ',' + ai.y + ')') + '<br/>');
      buf.add(Const.smalldebug('[debug] alertness: ' + ai.alertness) + '<br/>');
      addDebugListRow(buf, 'abilities', getAbilitiesText(ai));
      addDebugListRow(buf, 'effects', ai.effects.toString());
      addDebugListRow(buf, 'inventory', ai.inventory.toString());
      addDebugListRow(buf, 'skills', ai.skills.toString());
      addDebugListRow(buf, 'organs', ai.organs.toString());
      addDebugListRow(buf, 'traits', getTraitsText(ai));
#end
      return buf.toString();
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
