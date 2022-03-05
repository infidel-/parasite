// player log GUI window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class Log extends UIWindow
{
  var text: DivElement;

  public function new (g: Game)
    {
      super(g, 'window-log');
      window.style.borderImage = "url('./img/window-temp.png') 130 fill / 1 / 0 stretch";

      text = Browser.document.createDivElement();
      text.id = 'window-log-text';
      text.className = 'scroller';
      window.appendChild(text);
    }


// update text
  override function update()
    {
      var buf = new StringBuf();
      for (l in game.messageList)
        {
          buf.add("<font style='color:");
          buf.add(Const.TEXT_COLORS[l.col]);
          buf.add("'>");
          buf.add(l.msg);
          buf.add("</font>");
          if (l.cnt > 1)
            {
              buf.add(" <font style='color:");
              buf.add(Const.TEXT_COLORS[_TextColor.COLOR_REPEAT]);
              buf.add("'>(x");
              buf.add(l.cnt);
              buf.add(")</font>");
            }
          buf.add('<br/>');
        }

      setParams(buf.toString());
    }

  public override function setParams(obj: Dynamic)
    {
      text.innerHTML = obj;
      text.scrollTop = 10000;
    }
}
