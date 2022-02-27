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
  var container: DivElement;
  var consoleDiv: DivElement;
  var console: TextAreaElement;
  var log: DivElement;

  public function new(u: UI, g: Game)
    {
      game = g;
      ui = u;
      container = Browser.document.createDivElement();
      container.className = 'hud';
      container.style.visibility = 'visible';
      Browser.document.body.appendChild(container);


      consoleDiv = Browser.document.createDivElement();
      consoleDiv.className = 'console-div';
      consoleDiv.style.visibility = 'hidden';
      container.appendChild(consoleDiv);

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

      log = Browser.document.createDivElement();
      log.className = 'text';
      log.id = 'log';
      log.style.borderImage = "url('./img/log-border.png') 15 fill / 1 / 0 stretch";
      container.appendChild(log);
    }

// show hide HUD
  public inline function toggle()
    {
      container.style.visibility =
        (container.style.visibility == 'visible' ? 'hidden' : 'visible');
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

// update HUD state from game state
  public function update()
    {
/*
      updateActionList();
      updateActions(); // before info because info uses its height
      updateInfo();*/
      updateLog();
/*
      updateMenu();
      updateConsole();
      updateGoals();*/
    }

// update log display
  public function updateLog()
    {
      var buf = new StringBuf();
      for (l in game.hudMessageList)
        {
          buf.add("<font color='");
          buf.add(Const.TEXT_COLORS[l.col]);
          buf.add("'>");
          buf.add(l.msg);
          buf.add("</font>");
          if (l.cnt > 1)
            {
              buf.add(" <font color='");
              buf.add(Const.TEXT_COLORS[_TextColor.COLOR_REPEAT]);
              buf.add("'>(x");
              buf.add(l.cnt);
              buf.add(")</font>");
            }
          buf.add('<br/>');
        }

      log.innerHTML = buf.toString();
    }
}

