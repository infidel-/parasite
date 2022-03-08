// gui window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class UIWindow
{
  var game: Game;
  var window: DivElement;
  var bg: DivElement;
  var close: DivElement;
  var state: _UIState; // state this relates to

  public function new(g: Game, id: String, ?addCloseButton: Bool = true)
    {
      game = g;
      bg = Browser.document.createDivElement();
      bg.className = 'window-bg';
      bg.id = id + '-bg';
      Browser.document.body.appendChild(bg);
      window = Browser.document.createDivElement();
      window.id = id;
      bg.style.visibility = 'hidden';
      window.className = 'window text';
      bg.appendChild(window);

      // add common close button
      if (addCloseButton)
        {
          close = Browser.document.createDivElement();
          close.className = 'hud-button window-common-close';
          close.innerHTML = 'CLOSE';
          close.style.borderImage = "url('./img/window-common-close.png') 92 fill / 1 / 0 stretch";
          close.onclick = function (e) {
            game.ui.closeWindow();
          }
          window.appendChild(close);
        }
    }

// set window parameters
  public dynamic function setParams(obj: Dynamic)
    {}

// update window contents
  dynamic function update()
    {}

// action handling
  public dynamic function action(index: Int)
    {}

// scroll window up/down
  public dynamic function scroll(n: Int)
    {}

// scroll window to beginning
  public dynamic function scrollToBegin()
    {}

// scroll window to end
  public dynamic function scrollToEnd()
    {}

// show window
  public inline function show()
    {
      update();
      bg.style.visibility = 'visible';
    }

// hide window
  public inline function hide()
    {
      bg.style.visibility = 'hidden';
    }
}
