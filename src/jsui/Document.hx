// document display GUI window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class Document extends UIWindow
{
  var text: DivElement;

  public function new (g: Game)
    {
      super(g, 'window-document');
      window.style.borderImage = "url('./img/window-temp.png') 130 fill / 1 / 0 stretch";

      text = Browser.document.createDivElement();
      text.id = 'window-document-text';
      text.className = 'scroller';
      window.appendChild(text);
    }

  public override function setParams(obj: Dynamic)
    {
      text.innerHTML = obj;
    }
}
