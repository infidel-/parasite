// new js ui group
package jsui;

import js.Browser;
import js.html.KeyboardEvent;
import js.html.CanvasElement;

import game.*;

class UI
{
  var game: Game;
  var canvas: CanvasElement;
  public var hud: HUD;

  public function new(g: Game)
    {
      game = g;
      hud = new HUD(this, game);
      canvas = cast Browser.document.getElementById('webgl');
      canvas.onkeydown = onKey;
    }

// refocus canvas
  public function focus()
    {
      canvas.focus();
    }

// grab key presses
  function onKey(e: KeyboardEvent)
    {
//      trace(e.keyCode + ' ' + e.altKey + ' ' + e.ctrlKey + ' ' + e.code);
      // TODO check windows first
      if (false)
        {

        }
      // hud/movement/actions
      else
        {
          // toggle hud
          if (e.code == 'Space')
            {
              hud.toggle();
              return;
            }

          // open console
          if (e.code == 'Semicolon' && !hud.consoleVisible())
            hud.showConsole();
          // close console
          if (e.code == 'Escape' && hud.consoleVisible())
            {
              hud.hideConsole();
            }
        }

    }
}
