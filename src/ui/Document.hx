// text document window

package ui;

import com.haxepunk.HXP;
import haxe.ui.components.Label;
import haxe.ui.components.Button;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.core.MouseEvent;
import haxe.ui.core.TextInput;
import haxe.ui.macros.ComponentMacros;
import game.Game;

class Document extends UIWindow
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
      textInput = text.getTextInput();
      textInput.selectable = false;
      var button: Button = window.findComponent("close", null, true);
      button.registerEvent(MouseEvent.CLICK, onClick);
      window.hide();
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
