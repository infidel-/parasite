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
      if (game.location == Game.LOCATION_AREA)
        game.area.debug.action(index - 1);
      else if (game.location == Game.LOCATION_REGION)
        game.region.debug.action(index - 1);
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

      if (game.location == Game.LOCATION_AREA)
        {
          buf.add('Area alertness: ' + game.area.getArea().alertness + '\n');
          buf.add('Area interest: ' + game.area.getArea().interest + '\n');
        }
      else
        {
          var area = game.region.currentArea;
          buf.add('Area alertness: ' + area.alertness + '\n');
          buf.add('Area interest: ' + area.interest + '\n');
        }
      buf.add('\n');

      // draw a list of debug action
      var n = 1;
      var actions = null;
      if (game.location == Game.LOCATION_AREA)
        actions = game.area.debug.actions;
      else if (game.location == Game.LOCATION_REGION)
        actions = game.region.debug.actions;
      for (a in actions)
        buf.add((n++) + ': ' + a.name + '\n');

      _textField.htmlText = buf.toString();
      _back.graphics.clear();
      _back.graphics.beginFill(0x202020, .95);
      _back.graphics.drawRect(0, 0, _textField.width, _textField.height);
    }
}
