// new js ui hud
package jsui;

import js.Browser;
import js.html.TextAreaElement;
import js.html.DivElement;
import js.html.KeyboardEvent;

import game.*;

class HUD
{
  var game: Game;
  var ui: UI;
  var consoleDiv: DivElement;
  var console: TextAreaElement;

  public function new(u: UI, g: Game)
    {
      game = g;
      ui = u;

      consoleDiv = Browser.document.createDivElement();
      consoleDiv.className = 'console-div';
      consoleDiv.style.visibility = 'hidden';
      Browser.document.body.appendChild(consoleDiv);

      console = Browser.document.createTextAreaElement();
      console.className = 'console';
      console.onkeydown = function(e: KeyboardEvent) {
        if (e.code == 'Escape')
          hideConsole();
        else if (e.code == 'Enter')
          {
            game.console.run(console.value);
            hideConsole();
          }
      }
      consoleDiv.appendChild(console);
    }

  public function consoleVisible(): Bool
    {
      return (consoleDiv.style.visibility == 'visible');
    }

  public function showConsole()
    {
      consoleDiv.style.visibility = 'visible';
      console.value = '';
      Browser.window.setTimeout(function () {
        console.value = '';
      });
      console.focus();
    }

  public function hideConsole()
    {
      consoleDiv.style.visibility = 'hidden';
      ui.focus();
    }
}

