// text window (temp thing for all legacy windows)

package ui;

import h2d.HtmlText;
import game.Game;

class Text extends UIWindow
{
  var text: HtmlText;
  var textHeight: Int;
  var ymin: Int;

  public function new(g: Game, ?w: Int, ?h: Int)
    {
      super(g, w, h);

      var tile = game.scene.atlas.getInterface('button');
      text = cast addText(true, 10, 10, width - 20,
        Std.int(height - 30 - tile.height));
      ymin = Std.int(text.y);

      textHeight = Std.int(height - 10 - tile.height);
      addButton(-1, textHeight, 'CLOSE', game.scene.closeWindow);
#if (free || (!free && !js))
      addItchLink(textHeight);
#end
    }


// set parameters
  public override function setParams(o: Dynamic)
    {
      text.text = o;
    }


// action
  public override function action(index: Int)
    {
      game.scene.closeWindow();
    }


// scroll window up/down
  public override function scroll(n: Int)
    {
      if (text.textHeight < textHeight)
        return;
      var res = text.y - n * (text.font.lineHeight);
      if (res > ymin)
        res = ymin;
      if (- res > text.textHeight - textHeight)
        res = textHeight - text.textHeight;
      text.y = res;
    }


// scroll window to beginning
  public override function scrollToBegin()
    {
      text.y = ymin;
    }


// scroll window to end
  public override function scrollToEnd()
    {
      text.y = textHeight - text.textHeight;
    }
}
