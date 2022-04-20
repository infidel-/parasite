// game finish window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class Finish extends UIWindow
{
  var text: DivElement;

  public function new(g: Game)
    {
      super(g, 'window-finish');
      window.className += ' window-dialog';
      window.style.borderImage = "url('./img/window-dialog.png') 100 fill / 1 / 0 stretch";

      text = Browser.document.createDivElement();
      text.className = 'window-dialog-text';
      window.appendChild(text);

      var close = Browser.document.createDivElement();
      close.className = 'hud-button window-dialog-button';
      close.innerHTML = 'CLOSE';
      close.style.borderImage = "url('./img/window-dialog-button.png') 14 fill / 1 / 0 stretch";
      close.onclick = function (e) {
        game.ui.closeWindow();
      }
      window.appendChild(close);
    }

// set parameters
  public override function setParams(obj: Dynamic)
    {
      var buf = new StringBuf();
      buf.add('<center><h3>GAME OVER</h3></center><br/>');
      buf.add(obj);
      buf.add("<br/><br/>Close the window, then you can restart the game<br/>");
      text.innerHTML = buf.toString();
    }

// action
  public override function action(index: Int)
    {
      game.ui.closeWindow();
    }
}

