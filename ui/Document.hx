// text document window

package ui;

import com.haxepunk.HXP;
import haxe.ui.components.Label;
import haxe.ui.components.Button;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.core.MouseEvent;
import haxe.ui.macros.ComponentMacros;
import game.Game;

class Document extends UIWindow
{
  var text: Label;

  public function new(g: Game)
    {
      super(g);
      window = ComponentMacros.buildComponent("assets/ui/document.xml");
      window.width = HXP.width - 1;
      window.height = HXP.height - 1;
      window.x = 0;
      window.y = 0;
      HXP.stage.addChild(window);

      text = window.findComponent("text", null, true);
      text.getTextInput().selectable = false;
      var button: Button = window.findComponent("close", null, true);
      button.registerEvent(MouseEvent.CLICK, onClick);
      window.hide();
    }


// on click - close
  function onClick(e: MouseEvent)
    {
      game.scene.closeWindow();
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
}
