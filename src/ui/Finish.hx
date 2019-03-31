// game over window

package ui;

import game.Game;

class Finish extends Text
{
  public function new(g: Game)
    {
      super(g,
        Std.int(g.scene.win.width / 3),
        Std.int(g.scene.win.height / 3));
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

