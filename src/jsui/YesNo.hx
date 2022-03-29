// yes/no window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class YesNo extends UIWindow
{
  var text: DivElement;
  var func: Bool -> Void;

  public function new(g: Game)
    {
      super(g, 'window-yesno');
      window.className += ' window-dialog';
      window.style.borderImage = "url('./img/window-dialog.png') 100 fill / 1 / 0 stretch";

      text = Browser.document.createDivElement();
      text.className = 'window-dialog-text';
      window.appendChild(text);

      var yes = Browser.document.createDivElement();
      yes.className = 'hud-button window-dialog-button';
      yes.id = 'window-yesno-yes';
      yes.innerHTML = 'YES';
      yes.style.borderImage = "url('./img/window-dialog-button.png') 14 fill / 1 / 0 stretch";
      yes.onclick = function (e) {
        func(true);
        game.ui.closeWindow();
      }
      window.appendChild(yes);

      var no = Browser.document.createDivElement();
      no.className = 'hud-button window-dialog-button';
      no.id = 'window-yesno-no';
      no.innerHTML = 'NO';
      no.style.borderImage = "url('./img/window-dialog-button.png') 14 fill / 1 / 0 stretch";
      no.onclick = function (e) {
        func(false);
        game.ui.closeWindow();
      }
      window.appendChild(no);
    }

// set parameters
  public override function setParams(obj: Dynamic)
    {
      var o: { text: String, func: Bool -> Void } = cast obj;
      text.innerHTML = '<center>' + o.text + '</center>';
      func = o.func;
    }

// action
  public override function action(index: Int)
    {
      var yes = false;
      if (index == 1)
        yes = true;

      func(yes);
      game.ui.closeWindow();
    }
}

