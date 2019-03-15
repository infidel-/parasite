// text window (temp thing for all legacy windows)

package ui;

/*
import haxe.ui.components.Label;
import haxe.ui.components.Button;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.core.MouseEvent;
import haxe.ui.core.TextInput;
import haxe.ui.macros.ComponentMacros;
*/

import h2d.HtmlText;
import game.Game;

class Text extends UIWindow
{
/*
  var text: Label;
  var textInput: TextInput;
*/
  var text: HtmlText;

  public function new(g: Game, ?w: Int, ?h: Int)
    {
      super(g, w, h);

      text = new HtmlText(game.scene.font, window);
      text.maxWidth = width;

/*
      window = ComponentMacros.buildComponent("../assets/ui/document.xml");
      window.width = HXP.width - 1;
      window.height = HXP.height - 1;
      window.x = 0;
      window.y = 0;
      HXP.stage.addChild(window);

      text = window.findComponent("text", null, true);
      text.registerEvent(MouseEvent.MOUSE_WHEEL, onWheel);

      textInput = text.getTextInput();
      textInput.selectable = false;
      var font = Assets.getFont(Const.FONT);
      var textFormat = new TextFormat(font.fontName,
        game.config.fontSize, 0xFFFFFF);
      textFormat.align = TextFormatAlign.LEFT;
      textInput.defaultTextFormat = textFormat;

      var button: Button = window.findComponent("close", null, true);
      button.registerEvent(MouseEvent.CLICK, onClick);

      window.hide();
*/
    }


/*
// on wheel - scroll
  function onWheel(e: MouseEvent)
    {
      scroll(e.delta > 0 ? -1 : 1);
    }


// on click - close
  function onClick(e: MouseEvent)
    {
      game.scene.closeWindow();
      e.cancel();
    }
*/


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
//      textInput.scrollV += n;
      if (text.textHeight < height)
        return;
      var res = text.y - n * (text.font.lineHeight);
      if (res > 0)
        res = 0;
      if (- res > text.textHeight - game.scene.win.height)
        res = game.scene.win.height - text.textHeight;
      text.y = res;
    }


// scroll window to beginning
  public override function scrollToBegin()
    {
//      textInput.scrollV = 0;
      text.y = 0;
    }


// scroll window to end
  public override function scrollToEnd()
    {
//      textInput.scrollV = textInput.maxScrollV;
      text.y = game.scene.win.height - text.textHeight;
    }
}
