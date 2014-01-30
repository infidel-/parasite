// debug GUI window

package entities;

import openfl.Assets;
import com.haxepunk.HXP;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.text.TextFieldAutoSize;

class DebugWindow
{
  var game: Game; // game state
  var _textField: TextField; // text field
  var _back: Sprite; // window background

  public function new(g: Game)
    {
      game = g;

      // actions list
      var font = Assets.getFont("font/04B_03__.ttf");
      _textField = new TextField();
      _textField.autoSize = TextFieldAutoSize.LEFT;
      var fmt = new TextFormat(font.fontName, 16, 0xFFFFFF);
      fmt.align = TextFormatAlign.LEFT;
      _textField.defaultTextFormat = fmt;
      _back = new Sprite();
      _back.addChild(_textField);
      _back.x = 20;
      _back.y = 20;
      HXP.stage.addChild(_back);
    }


// call action by id
  public function action(index: Int)
    {
      game.debug.action(index - 1);
      update(); // update display
      game.scene.hud.update(); // update HUD
    }


// update and show window
  public function show()
    {
      update();
      _back.visible = true;
    }


// hide this window
  public function hide()
    {
      _back.visible = false;
    }


// update window text
  function update()
    {
      var buf = new StringBuf();
      buf.add('Debug\n===\n\n');

      buf.add('Area alertness: ' + game.world.area.alertness + '\n');
      buf.add('Area interest: ' + game.world.area.interest + '\n');
      buf.add('\n');

      // draw a list of debug action
      var n = 1;
      for (a in game.debug.actions)
        buf.add((n++) + ': ' + a.name + '\n');

      _textField.htmlText = buf.toString();
      _back.graphics.clear();
      _back.graphics.beginFill(0x202020, .95);
      _back.graphics.drawRect(0, 0, _textField.width, _textField.height);
    }
}
