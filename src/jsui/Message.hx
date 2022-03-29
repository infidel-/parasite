// message window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class Message extends UIWindow
{
  var text: DivElement;

  public function new(g: Game)
    {
      super(g, 'window-message');
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
      var o: { text: String, col: String } = cast obj;
      if (o.col != null)
        text.innerHTML = "<font style='color:" + o.col + "'>"  + o.text + "</font>";
      else text.innerHTML = o.text;
    }
}

