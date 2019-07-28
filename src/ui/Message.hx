// message window

package ui;

import h2d.Text;
import game.Game;

class Message extends UIWindow
{
  var text: Text;

  public function new(g: Game)
    {
      super(g, 700, g.config.fontSize > 24 ? 250 : 200);
      center();

      var tile = game.scene.atlas.getInterface('button');
      text = addText(false, 10, 10, width - 20,
        Std.int(height - 30 - tile.height));
      text.textAlign = Center;

      addButton(-1, Std.int(height - 10 - tile.height), 'CLOSE',
        game.scene.closeWindow);
    }


// set parameters
  public override function setParams(obj: Dynamic)
    {
      var o: { text: String, col: Int } = cast obj;
/*
      // new message color
      if (text.customStyle.color != o.col)
        {
          text.customStyle.color = o.col;
          text.invalidateStyle();
        }
*/
      text.textColor = o.col;

      text.text = o.text;
    }


// action
  public override function action(index: Int)
    {
      game.scene.closeWindow();
    }
}

