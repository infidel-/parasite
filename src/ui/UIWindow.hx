// gui window

package ui;

//import haxe.ui.core.Component;
import game.Game;

class UIWindow
{
  var game: Game;
//  var window: Component;

  public function new(g: Game)
    {
      game = g;
      trace('UIWindow');
//      window = null;
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
//      window.show();
    }


// hide window
  public inline function hide()
    {
//      window.hide();
    }
}
