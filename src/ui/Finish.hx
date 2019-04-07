// game over window

package ui;

import game.Game;

class Finish extends Text
{
  public function new(g: Game)
    {
      var w = Std.int(g.scene.win.width / 3);
      var h = Std.int(g.scene.win.height / 3);
      if (w < 600)
        w = 600;
      if (h < 400)
        h = 400;
      super(g, w, h);
      center();
      text.textAlign = Center;
    }


// set parameters
  public override function setParams(o: Dynamic)
    {
      var buf = new StringBuf();
      buf.add('<br/>Game Over<br/>===<br/><br/>');
      buf.add(o);
      buf.add("<br/><br/>Close the window" +
        "<br/>Then you can restart the game by pressing ENTER<br/>");

      text.text = buf.toString();
    }
}

