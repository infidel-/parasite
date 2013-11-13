// evolution GUI window

package entities;

import openfl.Assets;
import com.haxepunk.HXP;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.text.TextFieldAutoSize;

class EvolutionWindow
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
//      _back.width = 400;
//      _back.height = 400;
//      _back.width = HXP.windowWidth - 40;
//      _back.height = HXP.windowHeight - 40;
      HXP.stage.addChild(_back);

//      _back.visible = false;
    }


  public function show()
    {
      update();
      _back.visible = true;
    }

  function update()
    {
      var buf = new StringBuf();
      buf.add('TESTING TESTING TESTING\n');
      buf.add('TESTING TESTING TESTING\n');
      buf.add('TESTING TESTING TESTING\n');
      buf.add('TESTING TESTING TESTING\n');
      buf.add('TESTING TESTING TESTING\n');
      buf.add('TESTING TESTING TESTING\n');
      
      _textField.text = buf.toString();
      _back.graphics.clear();
      _back.graphics.beginFill(0x202020, .75);
      _back.graphics.drawRect(0, 0, _textField.width, _textField.height);
    }
}
