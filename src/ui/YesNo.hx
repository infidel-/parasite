// yes/no dialog window

package ui;

import h2d.Text;
import game.Game;

class YesNo extends UIWindow
{
  var text: h2d.Text;
  var func: Bool -> Void;

  public function new(g: Game)
    {
      super(g, 800, g.config.fontSize > 24 ? 200 : 150);
      center();
      func = null;

      var tile = game.scene.atlas.getInterface('button');
      text = addText(false, 10, 10, width - 20,
        Std.int(height - 30 - tile.height));
      text.textAlign = Center;

      addButton(
        Std.int(width / 2 - 20 - tile.width),
        Std.int(height - 10 - tile.height), 'YES', action.bind(1));
      addButton(
        Std.int(width / 2 + 20),
        Std.int(height - 10 - tile.height), 'NO', action.bind(2));
    }


// set parameters
  public override function setParams(o: Dynamic)
    {
      text.text = o.text;
      func = o.func;
    }


// action
  public override function action(index: Int)
    {
      var yes = false;
      if (index == 1)
        yes = true;

      func(yes);
      game.scene.closeWindow();
    }
}
