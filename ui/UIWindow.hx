// gui window

package ui;

import haxe.ui.core.Component;
import game.Game;

class UIWindow
{
  var game: Game;
  var window: Component;

  public function new(g: Game)
    {
      game = g;
      window = null;
    }


// action handling
  public dynamic function action(index: Int)
    {
    }


// show window
  public inline function show()
    {
      window.show();
    }


// hide window
  public inline function hide()
    {
      window.hide();
    }
}
