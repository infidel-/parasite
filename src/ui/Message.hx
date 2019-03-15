// message window

package ui;

/*
import haxe.ui.components.Label;
import haxe.ui.components.Button;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.core.MouseEvent;
import haxe.ui.macros.ComponentMacros;
*/
import game.Game;

class Message extends UIWindow
{
//  var text: Label;
  var text: h2d.Text;

  public function new(g: Game)
    {
      super(g, 700, 200);
      window.x = Std.int((game.scene.win.width - width) / 2);
      window.y = Std.int((game.scene.win.height - height) / 2);
      text = new h2d.Text(game.scene.font, back);
      text.textAlign = Center;
      text.maxWidth = width;

/*
      window = ComponentMacros.buildComponent("../assets/ui/message.xml");
      window.width = w;
      window.height = h;
      window.x = Std.int(HXP.halfWidth - w / 2);
      window.y = Std.int(HXP.halfHeight - h / 2);
      HXP.stage.addChild(window);

      text = window.findComponent("text", null, true);
      text.getTextInput().selectable = false;
      var button: Button = window.findComponent("close", null, true);
      button.registerEvent(MouseEvent.CLICK, onClick);
      window.hide();
*/
    }


/*
// on click
  function onClick(e: MouseEvent)
    {
      game.scene.closeWindow();
      e.cancel();
    }
*/


// set parameters
  public override function setParams(obj: Dynamic)
    {
      var o: { text: String, col: Int } = cast obj;
/*
      // new message color
      if (text.customStyle.color != o.col)
        {
          text.customStyle.color = o.col;
          text.invalidateStyle();
        }
*/
      text.textColor = o.col;

      text.text = o.text;
    }


// action
  public override function action(index: Int)
    {
      game.scene.closeWindow();
    }
}

