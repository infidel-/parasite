// text window (temp thing for all legacy windows)

package ui;

import com.haxepunk.HXP;
import haxe.ui.components.Label;
import haxe.ui.components.Button;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.core.MouseEvent;
import haxe.ui.core.TextInput;
import haxe.ui.macros.ComponentMacros;
import openfl.Assets;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.text.TextFieldAutoSize;

import game.Game;

class Text extends UIWindow
{
  var text: Label;
  var textInput: TextInput;

  public function new(g: Game)
    {
      super(g);
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
    }


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


// set parameters
  public override function setParams(o: Dynamic)
    {
      textInput.htmlText = o;
    }


// action
  public override function action(index: Int)
    {
      game.scene.closeWindow();
    }


// scroll window up/down
  public override function scroll(n: Int)
    {
      textInput.scrollV += n;
    }


// scroll window to beginning
  public override function scrollToBegin()
    {
      textInput.scrollV = 0;
    }


// scroll window to end
  public override function scrollToEnd()
    {
      textInput.scrollV = textInput.maxScrollV;
    }
}
