// message log GUI window

package entities;

import game.Game;

class LogWindow extends TextWindow
{
  public function new (g: Game)
    { super(g); }


  override function getText(): String
    {
      var buf = new StringBuf();

      for (l in game.messageList) 
        {
          buf.add(l);
          buf.add('\n');
        }

      return buf.toString();
    }
}

