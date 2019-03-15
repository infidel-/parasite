// gui window

package ui;

import h2d.Object;
import h2d.Graphics;

//import haxe.ui.core.Component;
import game.Game;

class UIWindow
{
  var game: Game;
//  var window: Component;
  var window: Object;
  var back: Graphics;
  var width: Int;
  var height: Int;

  public function new(g: Game, ?w: Int, ?h: Int)
    {
      game = g;
      width = (w != null ? w : game.scene.win.width);
      height = (h != null ? h : game.scene.win.height);
      window = new Object();
      window.x = 0;
      window.y = 0;
      window.visible = false;
      game.scene.add(window, Const.LAYER_UI);
      back = new Graphics(window);
      back.x = 0;
      back.y = 0;

      back.clear();
      back.beginFill(0x111111, 1);
      back.drawRect(0, 0, width, height);
      back.endFill();

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
      window.visible = true;
    }


// hide window
  public inline function hide()
    {
//      window.hide();
      window.visible = false;
    }
}
