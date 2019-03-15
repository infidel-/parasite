// yes/no dialog window

package ui;

/*
import com.haxepunk.HXP;
import haxe.ui.components.Label;
import haxe.ui.components.Button;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.core.MouseEvent;
import haxe.ui.macros.ComponentMacros;
*/
import game.Game;

class YesNo extends UIWindow
{
//  var text: Label;
  var text: h2d.Text;
  var func: Bool -> Void;

  public function new(g: Game)
    {
      super(g, 800, 300);
      func = null;

      text = new h2d.Text(game.scene.font, back);
      text.y = text.font.lineHeight + 10;
      text.textAlign = Center;
      text.maxWidth = width;
/*
      window = ComponentMacros.buildComponent("../assets/ui/dialog.xml");
      var w = 800;
      var h = 300;
      window.width = w;
      window.height = h;
      window.x = Std.int(HXP.halfWidth - w / 2);
      window.y = Std.int(HXP.halfHeight - h / 2);
      HXP.stage.addChild(window);

      text = window.findComponent("text", null, true);
      text.getTextInput().selectable = false;
      var button: Button = window.findComponent("yes", null, true);
      button.registerEvent(MouseEvent.CLICK, onClick);
      var button: Button = window.findComponent("no", null, true);
      button.registerEvent(MouseEvent.CLICK, onClick);
      window.hide();
*/
    }


/*
// on click
  function onClick(e: MouseEvent)
    {
      var index = -1;
      if (e.target.id == 'yes')
        index = 1;
      else if (e.target.id == 'no')
        index = 2;

      action(index);
      e.cancel();
    }
*/


// set parameters
  public override function setParams(o: Dynamic)
    {
      text.text = o.text;
      func = o.func;
    }


// action
  public override function action(index: Int)
    {
      var yes = false;
      if (index == 1)
        yes = true;

      func(yes);

      game.scene.closeWindow();
    }
}
