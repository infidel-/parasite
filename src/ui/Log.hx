// message log GUI window

package ui;

import game.Game;

class Log extends Text
{
  public function new (g: Game)
    { super(g); }


// update text
  override function update()
    {
      var buf = new StringBuf();

      for (l in game.messageList)
        {
          buf.add(l);
          buf.add('\n');
        }

      setParams(buf.toString());
    }
}

