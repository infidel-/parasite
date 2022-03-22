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
          buf.add("<font color='");
          buf.add(Const.TEXT_COLORS[l.col]);
          buf.add("'>");
          buf.add(l.msg);
          buf.add("</font>");
          if (l.cnt > 1)
            {
              buf.add(" <font color='");
              //buf.add(Const.TEXT_COLORS[_TextColor.COLOR_REPEAT]);
              buf.add("'>(x");
              buf.add(l.cnt);
              buf.add(")</font>");
            }
          buf.add('<br/>');
        }

      setParams(buf.toString());
    }
}

