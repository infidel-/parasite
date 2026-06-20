// hud objectives block: diamond marks + vein spine connectors
package ui.hud;

import js.Browser.document;
import js.html.DivElement;

import game.*;

class GoalsHud
{
  var game: Game;
  var goals: DivElement;

  public function new(g: Game, h: HUD)
    {
      game = g;
      goals = document.createDivElement();
      goals.className = 'hud-panel hud-text';
      goals.id = 'hud-goals';
      h.container.appendChild(goals);
    }

// update objectives list (diamond marks + vein spine connectors)
  public function update()
    {
      var buf = new StringBuf();
      var primaryAssigned = false;
      for (g in game.goals.iteratorCurrent())
        {
          var gi = game.goals.getInfo(g);
          if (gi.isHidden)
            continue;
          // first non-optional goal is the primary beacon, the rest are secondary
          var primary = (!primaryAssigned && !gi.isOptional);
          if (primary)
            primaryAssigned = true;
          buf.add('<div class="hud-grp"><div class="hud-obj">');
          buf.add(UISvg.hudDiamond(primary));
          buf.add('<div><div class="hud-ot">' + gi.name);
          if (gi.isOptional)
            buf.add(' <span class="hud-opt">[optional]</span>');
          buf.add('</div><div class="hud-od">' + gi.note);
          if (gi.noteFunc != null)
            buf.add('<br/>' + gi.noteFunc(game));
          buf.add('</div></div></div></div>'); // close od, name-wrap, obj, grp
        }
      goals.innerHTML = buf.toString();
    }
}
