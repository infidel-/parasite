// game finish window

package ui;

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
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.ui.closeWindow();
      }
      window.appendChild(close);
    }

// set parameters
  public override function setParams(obj: Dynamic)
    {
      var buf = new StringBuf();
      buf.add('<center><h3 class=window-title>GAME OVER</h3></center><br/>');
      if (obj.img != null)
        buf.add('<img class=message-img src="img/' + obj.img + '.jpg"><p>');
      buf.add('<center>' + obj.text + '</center>');
      buf.add("<br/><br/><center>Close the window, then you can restart the game.<br/></center>");
      text.innerHTML = buf.toString();
    }

// action
  public override function action(index: Int)
    {
      game.ui.closeWindow();
    }
}

