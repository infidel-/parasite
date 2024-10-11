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
      window.style.borderImage = "url('./img/window-log.png') 215 fill / 1 / 0 stretch";

      var cont = Browser.document.createDivElement();
      cont.id = 'window-log-text';
      window.appendChild(cont);
      var fieldset = Browser.document.createFieldSetElement();
      fieldset.id = 'window-log-fieldset';
      cont.appendChild(fieldset);
      var legend = Browser.document.createLegendElement();
      legend.className = 'window-title';
      legend.innerHTML = 'LOG';
      fieldset.appendChild(legend);
      text = Browser.document.createDivElement();
      text.className = 'scroller';
      fieldset.appendChild(text);

      addCloseButton();
    }

// update text
  override function update()
    {
      var buf = new StringBuf();
      for (l in game.messageList)
        {
          buf.add("<span style='color:");
          buf.add(Const.TEXT_COLORS[l.col]);
          buf.add("'>");
          buf.add(l.msg);
          buf.add("</span>");
          if (l.cnt > 1)
            {
              buf.add(" <span class=small style='color:var(--text-color-repeat)'>(x");
              buf.add(l.cnt);
              buf.add(")</span>");
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
